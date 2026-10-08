class_name AIInput
extends FighterController
## IA del rival. El ESTILO sale de un AIProfile (.tres); este script es el mismo para todos.
##
## Reglas para que sea justa:
##   - R1: produce el MISMO FighterCommand que el jugador. No toca al Fighter.
##   - Ve al rival CON RETRASO (reaction_ticks), como un humano: guarda "fotos" de lo que se ve
##     (posición, estado, fase del golpe) y decide con la foto de hace reaction_ticks.
##   - Solo usa lo que se ve en pantalla. De sí misma sí conoce todo (su stamina, su counter).
##   - El azar sale de un RandomNumberGenerator con semilla: no repite patrones, pero cada pelea es reproducible.

enum Difficulty { EASY, NORMAL, HARD }

## Ajustes de dificultad encima del perfil (Normal es un poco más accesible que el perfil "puro").
const EASY_EXTRA_REACTION_TICKS: int = 10
const EASY_DEFENSE_MULT: float = 0.5
const NORMAL_EXTRA_REACTION_TICKS: int = 2
const NORMAL_DEFENSE_MULT: float = 0.7
const NORMAL_DODGE_MULT: float = 0.9
const HARD_REACTION_REDUCTION_TICKS: int = 4
const HARD_DEFENSE_MULT: float = 1.2
const MIN_REACTION_TICKS: int = 6

## Perfil efectivo (copia del .tres con la dificultad aplicada).
var profile: AIProfile = AIProfile.new()
var difficulty: Difficulty = Difficulty.NORMAL
var reaction_ticks: int = 12

## Cuántos golpes del rival recuerda para leer sus patrones.
const READ_MEMORY: int = 6
## Con lectura completa (rival 100 % predecible y read_skill 1), reacciona estos ticks antes.
const READ_MAX_ANTICIPATION_TICKS: int = 16
## Retraso mínimo al anticipar un golpe leído (sin esto, en Difícil el retraso daba negativo).
const MIN_READ_DELAY_TICKS: int = 3
## Con lectura completa, cuánto suma a la probabilidad de defenderse.
const READ_MAX_DEFENSE_BONUS: float = 0.45

## Lo que se ve del rival en un tick.
class Snapshot:
	var x: float
	var state: Fighter.State
	var phase: Fighter.AttackPhase
	var attack_tick: int
	var ticks_until_active: int
	var reach: float
	var zone: MoveData.Zone
	var guarding: bool
	var move_id: StringName
	var charging: bool
	var can_charge: bool
	## Número de serie del golpe: identifica cada golpe (aunque se esté cargando).
	var start_t: int

var _rng := RandomNumberGenerator.new()
var _history: Array[Snapshot] = []
var _t: int = 0
var _move_dir: int = 0
var _guard_left: int = 0
var _dodge_in: int = -1
## Guardia "de base" mientras mide (no es reacción: la decide en cada _decide()).
var _idle_guard: bool = false
## Ticks que le quedan saliendo hacia atrás después de atacar ("pegar y salir").
var _step_back_left: int = 0
## Ticks que le quedan manteniendo el botón del fuerte (carga).
var _charge_hold_left: int = 0
## Cuándo empezó (en ticks de la IA) el último golpe del rival que anotó y al que reaccionó.
var _registered_start: int = -1
var _reacted_start: int = -1
## Últimos golpes que le vio tirar al rival (para leer patrones).
var _opponent_moves: Array[StringName] = []
## Para el debug: cuánto "leyó" el último golpe (0–1).
var last_read: float = 0.0
## Para el debug: qué está pensando.
var intent: String = "-"


## base_profile = null usa los valores por defecto (estilo equilibrado). rng_seed = 0: azar distinto cada pelea.
func configure(base_profile: AIProfile, rng_seed: int, ai_difficulty: Difficulty = Difficulty.NORMAL) -> void:
	profile = base_profile.duplicate() if base_profile != null else AIProfile.new()
	difficulty = ai_difficulty
	reaction_ticks = profile.reaction_ticks
	match difficulty:
		Difficulty.EASY:
			reaction_ticks += EASY_EXTRA_REACTION_TICKS
			profile.block_chance *= EASY_DEFENSE_MULT
			profile.dodge_chance *= EASY_DEFENSE_MULT
			profile.punish_chance *= EASY_DEFENSE_MULT
			profile.read_skill *= 0.3
			profile.aggression *= 0.75
		Difficulty.NORMAL:
			reaction_ticks += NORMAL_EXTRA_REACTION_TICKS
			profile.block_chance *= NORMAL_DEFENSE_MULT
			# El esquive casi no se toca: es el sello del contragolpeador (si no, pierde su estilo).
			profile.dodge_chance *= NORMAL_DODGE_MULT
			profile.punish_chance *= NORMAL_DEFENSE_MULT
			profile.read_skill *= 0.6
		Difficulty.HARD:
			reaction_ticks = maxi(MIN_REACTION_TICKS, reaction_ticks - HARD_REACTION_REDUCTION_TICKS)
			profile.block_chance = minf(1.0, profile.block_chance * HARD_DEFENSE_MULT)
			profile.dodge_chance = minf(1.0 - profile.block_chance, profile.dodge_chance * HARD_DEFENSE_MULT)
			profile.punish_chance = minf(1.0, profile.punish_chance * HARD_DEFENSE_MULT)
			profile.read_skill = minf(1.0, profile.read_skill * 1.25)
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed


func get_command(me: Fighter, opponent: Fighter) -> FighterCommand:
	_t += 1
	_history.push_back(_observe(opponent))
	while _history.size() > reaction_ticks + 1:
		_history.pop_front()
	var seen: Snapshot = _history[0]
	var cmd := FighterCommand.new()

	if me.state == Fighter.State.KNOCKDOWN:
		intent = "levantarse"
		var every: int = maxi(1, roundi(CombatTime.TICKS_PER_SECOND / profile.getup_taps_per_second))
		cmd.jab = _t % every == 0 or _rng.randf() < 0.05
		return cmd
	if me.is_down():
		return cmd

	var gap: float = absf(seen.x - me.position.x) - me.half_width() - opponent.half_width()
	var can_act: bool = me.state in [Fighter.State.IDLE, Fighter.State.MOVING, Fighter.State.BLOCKING]

	_react_to_incoming(me, opponent)

	# Esquive programado (para que la invulnerabilidad coincida con el golpe que viene).
	if _dodge_in >= 0:
		_dodge_in -= 1
		if _dodge_in < 0:
			cmd.dodge = true
			intent = "esquivar"
			return cmd

	# Cubrirse mientras dura el golpe que vio venir.
	if _guard_left > 0:
		_guard_left -= 1
		cmd.guard = true
		cmd.move = -1 if me.is_tired() else 0
		intent = "cubrirse"
		return cmd

	# Sigue cargando el fuerte que decidió cargar.
	if _charge_hold_left > 0 and me.state == Fighter.State.ATTACKING:
		_charge_hold_left -= 1
		cmd.power_held = true
		intent = "cargar"
		return cmd
	_charge_hold_left = 0

	if not can_act:
		return cmd

	var jab_reach: float = me.setup.jab.reach
	# Counter después de un esquive exitoso.
	if me.counter_ready_left > 0 and gap <= jab_reach:
		intent = "counter"
		if gap <= me.setup.power_punch.reach and _rng.randf() < profile.counter_with_power_chance:
			cmd.power = true
		else:
			cmd.jab = true
		return cmd

	# Castigar al rival expuesto (también mientras carga un fuerte: está quieto y abierto).
	var exposed: bool = (seen.state == Fighter.State.ATTACKING and seen.phase == Fighter.AttackPhase.RECOVERY) \
			or seen.state == Fighter.State.GUARD_BROKEN or seen.state == Fighter.State.DODGING or seen.charging
	if exposed and gap <= jab_reach and _t % 3 == 0 and _rng.randf() < profile.punish_chance * 0.5:
		intent = "castigar"
		_attack(cmd, me, seen, gap)
		return cmd

	# Pegar y salir.
	if _step_back_left > 0:
		_step_back_left -= 1
		intent = "salir"
		cmd.move = -1
		return cmd

	if _t % profile.decision_interval_ticks == 0:
		_decide(cmd, me, seen, gap)
	var attacking_now: bool = cmd.jab or cmd.power
	cmd.move = _move_dir if not attacking_now else 0
	cmd.guard = _idle_guard and not attacking_now
	return cmd


## Re-piensa: moverse para ajustar la distancia o atacar si está en rango.
func _decide(cmd: FighterCommand, me: Fighter, seen: Snapshot, gap: float) -> void:
	var jab_reach: float = me.setup.jab.reach
	_idle_guard = false
	# Cansada: según su estilo, retrocede (a veces cubierta) hasta la próxima decisión.
	if me.is_tired() and _rng.randf() < profile.tired_caution:
		intent = "recuperar aire"
		_move_dir = -1
		_idle_guard = gap < jab_reach + 40.0 and _rng.randf() < 0.5
		return
	if gap <= jab_reach and _rng.randf() < profile.aggression * 0.75:
		intent = "atacar"
		_attack(cmd, me, seen, gap)
		_move_dir = 0
		return
	# Cerca y sin atacar: a veces mide con la guardia arriba.
	if gap <= me.setup.power_punch.reach + 40.0 and _rng.randf() < profile.guard_up_chance:
		_idle_guard = true
	var pref: float = profile.preferred_gap
	if gap > pref + 25.0:
		_move_dir = 1 if _rng.randf() < profile.approach_chance else 0
		intent = "acercarse" if _move_dir > 0 else "esperar"
	elif gap < pref - 35.0:
		_move_dir = -1 if _rng.randf() < profile.retreat_chance else 0
		intent = "tomar distancia" if _move_dir < 0 else "plantarse"
	else:
		# En su distancia: pequeños ajustes (según su estilo) para no quedarse quieta como una estatua.
		var roll: float = _rng.randf()
		var forward: float = 0.1 + profile.approach_chance * 0.2
		var back: float = 0.05 + profile.retreat_chance * 0.2
		_move_dir = 1 if roll < forward else (-1 if roll < forward + back else 0)
		intent = "medir"


func _attack(cmd: FighterCommand, me: Fighter, seen: Snapshot, gap: float) -> void:
	_choose_attack(cmd, me, seen, gap)
	if _rng.randf() < profile.step_back_after_attack:
		_step_back_left = 18


func _choose_attack(cmd: FighterCommand, me: Fighter, seen: Snapshot, gap: float) -> void:
	var low_stamina: bool = me.stamina < me.setup.power_punch.stamina_cost + 10.0
	var power_bonus: float = 0.25 if seen.guarding else 0.0  # contra la guardia conviene el fuerte o el cuerpo
	var roll: float = _rng.randf()
	if not low_stamina and gap <= me.setup.power_punch.reach and roll < profile.power_chance + power_bonus:
		cmd.power = true
		cmd.body = _rng.randf() < profile.body_chance
		if _rng.randf() < profile.charge_chance:
			cmd.power_held = true
			_charge_hold_left = _rng.randi_range(15, 45)
	elif gap <= me.setup.jab_body.reach and roll < profile.power_chance + power_bonus + profile.body_chance:
		cmd.jab = true
		cmd.body = true
	else:
		cmd.jab = true


## Decide UNA vez por golpe del rival cómo defenderse, mirando la "foto" retrasada.
## Lectura de patrones: si el rival viene repitiendo un golpe, la IA lo está ESPERANDO y reconoce
## ese golpe antes (percepción más rápida, proporcional a qué tan predecible es). Si el rival tira
## otra cosa, la sorprende con su retraso normal.
func _react_to_incoming(me: Fighter, opponent: Fighter) -> void:
	var predicted: StringName = _predicted_move()
	var read: float = _read_level(predicted) * profile.read_skill
	# Nunca menos de MIN_READ_DELAY_TICKS de retraso: ni leyendo a la perfección es instantánea.
	var anticipation: int = mini(roundi(read * READ_MAX_ANTICIPATION_TICKS), reaction_ticks - MIN_READ_DELAY_TICKS)
	var delay: int = reaction_ticks
	var view: Snapshot = _history[0]
	if anticipation > 0:
		var fast_delay: int = reaction_ticks - anticipation
		var fast: Snapshot = _history[clampi(_history.size() - 1 - fast_delay, 0, _history.size() - 1)]
		if _is_winding_up(fast) and fast.move_id == predicted:
			view = fast
			delay = fast_delay
	if not _is_winding_up(view):
		return
	# Si ve que lo está CARGANDO, cancela lo que iba a hacer y vuelve a reaccionar cuando lo suelte.
	if view.charging:
		if view.start_t == _reacted_start:
			_reacted_start = -1
			_guard_left = 0
			_dodge_in = -1
		return
	if view.start_t != _registered_start:
		_registered_start = view.start_t
		last_read = read if view.move_id == predicted else 0.0
		_remember(view.move_id)
	var gap: float = absf(view.x - me.position.x) - me.half_width() - opponent.half_width()
	if view.start_t == _reacted_start or gap > view.reach + 15.0:
		return
	_reacted_start = view.start_t
	# La foto es de hace `delay` ticks: estima cuánto le falta al golpe ahora.
	var eta: int = view.ticks_until_active - delay
	var bonus: float = last_read * READ_MAX_DEFENSE_BONUS
	var roll: float = _rng.randf()
	var dodge_p: float = profile.dodge_chance * (1.0 + bonus)
	var block_p: float = profile.block_chance + bonus
	if roll < dodge_p and view.zone == MoveData.Zone.HEAD and eta >= 2:
		_dodge_in = maxi(0, eta - 3)   # que la invulnerabilidad (desde el tick 3) cubra el golpe
	elif roll < dodge_p + block_p and eta >= 0:
		_guard_left = eta + 12
	# Si no le da el tiempo (eta < 0), el golpe le entra: así es un humano con reflejos normales.


func _is_winding_up(s: Snapshot) -> bool:
	return s.state == Fighter.State.ATTACKING and s.phase == Fighter.AttackPhase.STARTUP


## El golpe que más viene repitiendo el rival (el que la IA "espera").
func _predicted_move() -> StringName:
	var best: StringName = &""
	var best_count: int = 0
	for id in _opponent_moves:
		var c: int = _opponent_moves.count(id)
		if c > best_count:
			best = id
			best_count = c
	return best


## Fracción de los últimos golpes del rival que fueron este mismo (0 = nunca, 1 = siempre lo mismo).
func _read_level(move_id: StringName) -> float:
	if _opponent_moves.size() < 2:
		return 0.0
	return float(_opponent_moves.count(move_id)) / READ_MEMORY


func _remember(move_id: StringName) -> void:
	_opponent_moves.push_back(move_id)
	while _opponent_moves.size() > READ_MEMORY:
		_opponent_moves.pop_front()


func _observe(f: Fighter) -> Snapshot:
	var s := Snapshot.new()
	s.x = f.position.x
	s.state = f.state
	s.phase = f.attack_phase
	s.attack_tick = f.attack_tick
	s.ticks_until_active = f.ticks_until_active()
	s.reach = f.current_move.reach if f.current_move != null else 0.0
	s.zone = f.current_move.zone if f.current_move != null else MoveData.Zone.HEAD
	s.guarding = f.is_guarding()
	s.move_id = f.current_move.id if f.current_move != null else &""
	s.charging = f.charging
	s.can_charge = f.current_move.can_charge if f.current_move != null else false
	s.start_t = f.attack_serial
	return s
