class_name ArenaRules
extends RefCounted
## Reglas de la Arena: ofertas de la semana, bolsas, ranking, cómo se arma la pelea y qué pasa después.
## Todos los números de balance de la Arena están acá.
##
## Recibe el GameState como parámetro (`gs`), igual que WeekActions, para poder probarlo.
## El combate no se toca (R2): build_fight_setup arma la entrada y apply_result lee la salida.

## Energía mínima para pelear.
const MIN_ENERGY: int = 50
## Con MIN_ENERGY se pelea con este porcentaje de la stamina máxima; con energía llena, con el 100 %.
const TIRED_STAMINA_MULT: float = 0.85

## Probabilidad de poder elegir entre 3 ofertas (si no, "te toca" una sola).
const CHOICE_CHANCE: float = 0.55
## Cada puesto que subís por encima del inicial suma esto a la probabilidad de elegir.
const CHOICE_CHANCE_PER_RANK: float = 0.01
## "Te toca": probabilidad de que sea un rival difícil (si no, parejo).
const ASSIGNED_HARD_CHANCE: float = 0.4

## Bolsa base (una semana de pelea tiene que convenir más que una de trabajo: 3 × $150).
const BASE_PURSE: int = 400
const PURSE_PER_RANK: int = 25
const PURSE_MULT: Dictionary = {
	FightOffer.Level.EASY: 0.8,
	FightOffer.Level.EVEN: 1.0,
	FightOffer.Level.HARD: 1.6,
}
const KO_BONUS: float = 0.25
const LOSS_PAY: float = 0.3
const DRAW_PAY: float = 0.6

## Puestos que subís al ganar, según la dificultad del rival (+1 si es por KO).
const RANK_GAIN: Dictionary = {
	FightOffer.Level.EASY: 1,
	FightOffer.Level.EVEN: 2,
	FightOffer.Level.HARD: 4,
}
const RANK_LOSS: int = 2
## Con este puesto o mejor, los rivales parejos usan la IA NORMAL (antes, la FÁCIL).
const NORMAL_AI_RANK: int = 10

## Energía después de pelear: salud final (en %) menos esto por cada knockdown recibido.
const ENERGY_PER_KNOCKDOWN: int = 15
const KO_LOSS_MAX_ENERGY: int = 25
const MIN_ENERGY_AFTER: int = 10

## Moral después de pelear.
const MORALE_WIN: int = 8
const MORALE_WIN_KO: int = 12
const MORALE_LOSS: int = -10
const MORALE_LOSS_STOPPED: int = -15

const ROUNDS: int = 3
const ROUND_SECONDS: float = 60.0

## Azar de las ofertas (las pruebas le fijan la semilla).
static var rng := RandomNumberGenerator.new()


static func can_fight(gs: Object) -> bool:
	return gs.energy >= MIN_ENERGY


## Ofertas de esta semana. Se generan la primera vez y quedan guardadas en GameState
## (recargar la partida no cambia los rivales). Lista vacía = esta semana ya no hay peleas.
static func weekly_offers(gs: Object) -> Array[FightOffer]:
	if gs.offers_week != gs.week:
		gs.offers = _generate(gs).map(func(o: FightOffer) -> Dictionary: return o.to_dict())
		gs.offers_week = gs.week
	var result: Array[FightOffer] = []
	for d in gs.offers:
		result.append(FightOffer.from_dict(d))
	return result


## Rechazar la pelea que "te toca": esta semana no hay más ofertas.
static func decline(gs: Object) -> void:
	gs.offers = []
	gs.offers_week = gs.week
	gs.changed.emit()


static func choice_chance(gs: Object) -> float:
	return clampf(CHOICE_CHANCE + (gs.START_RANK - gs.rank) * CHOICE_CHANCE_PER_RANK, 0.0, 0.95)


static func _generate(gs: Object) -> Array[FightOffer]:
	var offers: Array[FightOffer] = []
	var levels: Array = []
	var kind: FightOffer.Kind
	if rng.randf() < choice_chance(gs):
		kind = FightOffer.Kind.CHOICE
		levels = [FightOffer.Level.EASY, FightOffer.Level.EVEN, FightOffer.Level.HARD]
	else:
		kind = FightOffer.Kind.ASSIGNED
		levels = [FightOffer.Level.HARD if rng.randf() < ASSIGNED_HARD_CHANCE else FightOffer.Level.EVEN]
	var used: PackedStringArray = []
	for level in levels:
		var o: FightOffer = RivalGenerator.generate(gs.fighter, level, _rival_rank(gs.rank, level), rng, used)
		used.append(o.rival.full_name)
		o.kind = kind
		o.purse = purse(gs.rank, level)
		o.rounds = ROUNDS
		o.ai_difficulty = _ai_difficulty(gs.rank, level)
		offers.append(o)
	return offers


## Puesto del rival: los fáciles están por debajo tuyo, los difíciles por encima.
static func _rival_rank(my_rank: int, level: FightOffer.Level) -> int:
	var r: int = my_rank
	match level:
		FightOffer.Level.EASY:
			r = my_rank + rng.randi_range(3, 6)
		FightOffer.Level.EVEN:
			r = my_rank + rng.randi_range(-2, 2)
		FightOffer.Level.HARD:
			r = my_rank - rng.randi_range(3, 6)
	if r == my_rank:
		r += 1
	return clampi(r, 1, 40)


static func _ai_difficulty(my_rank: int, level: FightOffer.Level) -> AIInput.Difficulty:
	match level:
		FightOffer.Level.HARD:
			return AIInput.Difficulty.NORMAL
		FightOffer.Level.EVEN:
			return AIInput.Difficulty.NORMAL if my_rank <= NORMAL_AI_RANK else AIInput.Difficulty.EASY
	return AIInput.Difficulty.EASY


static func purse(my_rank: int, level: FightOffer.Level) -> int:
	var base: int = BASE_PURSE + PURSE_PER_RANK * maxi(0, 30 - my_rank)
	return roundi(base * PURSE_MULT[level] / 10.0) * 10


## Arma la pelea: vos (izquierda, con la stamina según tu energía) contra el rival de la oferta (IA).
static func build_fight_setup(gs: Object, offer: FightOffer) -> FightSetup:
	var me: FighterSetup = StatFormulas.build_setup(gs.fighter)
	me.display_name = gs.display_name()
	me.controller_type = FighterSetup.ControllerType.PLAYER
	me.max_stamina *= stamina_mult(gs.energy) * EventRunner.fight_stamina_mult(gs)
	var rival: FighterSetup = StatFormulas.build_setup(offer.rival)
	rival.display_name = offer.display_name()
	rival.controller_type = FighterSetup.ControllerType.AI
	rival.ai_profile = offer.profile()
	rival.ai_difficulty = offer.ai_difficulty
	var fs := FightSetup.new()
	fs.fighter_a = me
	fs.fighter_b = rival
	fs.rounds = offer.rounds
	fs.round_seconds = ROUND_SECONDS
	return fs


static func stamina_mult(energy: int) -> float:
	return lerpf(TIRED_STAMINA_MULT, 1.0, clampf((energy - MIN_ENERGY) / float(100 - MIN_ENERGY), 0.0, 1.0))


## Aplica el resultado (vos sos el índice 0): plata, récord, ranking, energía y pasa la semana.
## Devuelve un resumen para la pantalla de resultado.
static func apply_result(gs: Object, offer: FightOffer, r: FightResult) -> Dictionary:
	var won: bool = r.winner_index == 0
	var draw: bool = r.is_draw()
	var ko: bool = won and r.is_stoppage()
	var pay: int
	if won:
		pay = roundi(offer.purse * (1.0 + KO_BONUS)) if ko else offer.purse
		gs.wins += 1
		if ko:
			gs.kos += 1
	elif draw:
		pay = roundi(offer.purse * DRAW_PAY)
		gs.draws += 1
	else:
		pay = roundi(offer.purse * LOSS_PAY)
		gs.losses += 1
	gs.money += pay

	var rank_before: int = gs.rank
	if won:
		gs.rank = maxi(1, gs.rank - RANK_GAIN[offer.level] - (1 if ko else 0))
	elif not draw:
		gs.rank = mini(gs.WORST_RANK, gs.rank + RANK_LOSS)

	var stopped_me: bool = not won and not draw and r.is_stoppage()
	var morale: int = EventRunner.add_morale(gs, _morale_change(won, draw, ko, stopped_me))
	var week: Dictionary = WeekActions.end_week(gs)
	gs.energy = energy_after(r, stopped_me)
	gs.offers = []
	gs.changed.emit()
	return {
		"won": won,
		"draw": draw,
		"ko": ko,
		"pay": pay,
		"rank_before": rank_before,
		"rank_after": gs.rank,
		"energy": gs.energy,
		"morale": morale,
		"outcome": outcome(won, draw, ko, stopped_me),
		"week": week,
	}


static func _morale_change(won: bool, draw: bool, ko: bool, stopped_me: bool) -> int:
	if won:
		return MORALE_WIN_KO if ko else MORALE_WIN
	if draw:
		return 0
	return MORALE_LOSS_STOPPED if stopped_me else MORALE_LOSS


## Resultado para los eventos de después de la pelea (condición "outcome" de EventRunner).
static func outcome(won: bool, draw: bool, ko: bool, stopped_me: bool) -> String:
	if won:
		return "win_ko" if ko else "win"
	if draw:
		return "draw"
	return "loss_ko" if stopped_me else "loss"


## Energía con la que arrancás la semana siguiente, según cómo terminaste la pelea.
static func energy_after(r: FightResult, stopped: bool) -> int:
	var health_pct: float = 100.0 * r.final_health.x / maxf(1.0, r.base_health.x)
	var e: int = roundi(health_pct) - ENERGY_PER_KNOCKDOWN * r.knockdowns.x
	if stopped:
		e = mini(e, KO_LOSS_MAX_ENERGY)
	return clampi(e, MIN_ENERGY_AFTER, 100)
