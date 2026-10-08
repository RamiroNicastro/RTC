class_name RivalGenerator
extends RefCounted
## Arma rivales amateur a medida: nombre, apodo, estilo, estadísticas cerca de las tuyas y un récord creíble.
## NO decide la bolsa ni cuándo hay ofertas (eso es ArenaRules).

const NAMES_PATH: String = "res://data/rivals/names.json"

## Cuánto más (o menos) que tu promedio tiene el rival, según la dificultad.
const LEVEL_OFFSET: Dictionary = {
	FightOffer.Level.EASY: -6,
	FightOffer.Level.EVEN: 0,
	FightOffer.Level.HARD: 6,
}
## Cómo reparte los puntos cada estilo (suma 0: ninguno es más fuerte, solo distinto).
const STYLE_SPREAD: Dictionary = {
	"pressure": {&"power": 6, &"chin": 5, &"cardio": 0, &"speed": -4, &"technique": -4, &"defense": -3},
	"outboxer": {&"speed": 6, &"technique": 5, &"defense": 0, &"power": -5, &"chin": -3, &"cardio": -3},
	"counter": {&"defense": 6, &"technique": 5, &"speed": 0, &"power": -3, &"chin": -4, &"cardio": -4},
}
## Variación al azar de cada estadística (±).
const STAT_NOISE: int = 3
## Colores posibles del rival (el azul es del jugador).
const COLORS: Array[Color] = [
	Color(0.8, 0.25, 0.2), Color(0.85, 0.6, 0.2), Color(0.35, 0.65, 0.35), Color(0.6, 0.3, 0.65),
	Color(0.9, 0.9, 0.9), Color(0.5, 0.55, 0.65), Color(0.75, 0.45, 0.3), Color(0.9, 0.4, 0.6),
]

static var _names: Dictionary = {}


static func names() -> Dictionary:
	if _names.is_empty():
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(NAMES_PATH)) == OK and json.data is Dictionary:
			_names = json.data
		else:
			push_warning("No se pudo leer %s" % NAMES_PATH)
			_names = {"first_names": ["Juan"], "last_names": ["Pérez"], "nicknames": ["El Pibe"]}
	return _names


## Promedio de las 6 estadísticas de un peleador.
static func average(f: FighterData) -> float:
	var total: int = 0
	for stat in FighterData.STAT_NAMES:
		total += int(f.get(stat))
	return total / float(FighterData.STAT_NAMES.size())


## Arma una oferta con su rival (sin bolsa ni tipo: eso lo completa ArenaRules).
## `avoid` = nombres completos que no hay que repetir (por ejemplo, las otras cartas de la semana).
static func generate(player: FighterData, level: FightOffer.Level, rival_rank: int,
		rng: RandomNumberGenerator, avoid: PackedStringArray = []) -> FightOffer:
	var o := FightOffer.new()
	o.level = level
	o.rank = rival_rank
	o.profile_id = FightOffer.PROFILES.keys()[rng.randi() % FightOffer.PROFILES.size()]
	var n: Dictionary = names()
	var full: String = ""
	for i in 10:
		full = "%s %s" % [_pick(n["first_names"], rng), _pick(n["last_names"], rng)]
		if not avoid.has(full):
			break
	o.rival.full_name = full
	o.rival.nickname = _pick(n["nicknames"], rng)
	o.rival.color = COLORS[rng.randi() % COLORS.size()]
	o.rival.wingspan = snappedf(rng.randf_range(-0.6, 0.6), 0.1)
	var base: float = average(player) + LEVEL_OFFSET[level]
	var spread: Dictionary = STYLE_SPREAD[o.profile_id]
	for stat in FighterData.STAT_NAMES:
		var v: int = roundi(base + spread.get(stat, 0) + rng.randi_range(-STAT_NOISE, STAT_NOISE))
		o.rival.set(stat, clampi(v, 1, 100))
	_make_record(o, rng)
	return o


## Récord creíble: más peleas y más victorias cuanto mejor rankeado está.
static func _make_record(o: FightOffer, rng: RandomNumberGenerator) -> void:
	var climb: int = maxi(0, 30 - o.rank)
	var fights: int = clampi(climb / 2 + rng.randi_range(1, 4), 1, 25)
	var win_ratio: float = clampf(0.45 + climb / 60.0 + rng.randf_range(-0.1, 0.1), 0.3, 0.95)
	o.wins = roundi(fights * win_ratio)
	o.draws = 1 if fights > 4 and rng.randf() < 0.3 else 0
	o.losses = maxi(0, fights - o.wins - o.draws)
	o.kos = roundi(o.wins * rng.randf_range(0.2, 0.6))


static func _pick(list: Array, rng: RandomNumberGenerator) -> String:
	return str(list[rng.randi() % list.size()])
