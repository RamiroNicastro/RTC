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

## Ajustes de dificultad encima del perfil.
const EASY_EXTRA_REACTION_TICKS: int = 6
const EASY_DEFENSE_MULT: float = 0.7
const HARD_REACTION_REDUCTION_TICKS: int = 4
const HARD_DEFENSE_MULT: float = 1.2
const MIN_REACTION_TICKS: int = 6

## Perfil efectivo (copia del .tres con la dificultad aplicada).
var profile: AIProfile = AIProfile.new()
var difficulty: Difficulty = Difficulty.NORMAL
var reaction_ticks: int = 12

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
var _reacted_to_attack: bool = false
var _last_seen_attack_tick: int = 0
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
		Difficulty.HARD:
			reaction_ticks = maxi(MIN_REACTION_TICKS, reaction_ticks - HARD_REACTION_REDUCTION_TICKS)
			profile.block_chance = minf(1.0, profile.block_chance * HARD_DEFENSE_MULT)
			profile.dodge_chance = minf(1.0 - profile.block_chance, profile.dodge_chance * HARD_DEFENSE_MULT)
			profile.punish_chance = minf(1.0, profile.punish_chance * HARD_DEFENSE_MULT)
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

	_react_to_incoming(seen, gap)

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

	# Castigar al rival expuesto.
	var exposed: bool = (seen.state == Fighter.State.ATTACKING and seen.phase == Fighter.AttackPhase.RECOVERY) \
			or seen.state == Fighter.State.GUARD_BROKEN or seen.state == Fighter.State.DODGING
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
	elif gap <= me.setup.jab_body.reach and roll < profile.power_chance + power_bonus + profile.body_chance:
		cmd.jab = true
		cmd.body = true
	else:
		cmd.jab = true


## Mira la "foto" retrasada: si ve un golpe nuevo que la alcanza, decide UNA vez cómo defenderse.
func _react_to_incoming(seen: Snapshot, gap: float) -> void:
	var attacking: bool = seen.state == Fighter.State.ATTACKING and seen.phase == Fighter.AttackPhase.STARTUP
	if not attacking:
		_reacted_to_attack = false
		_last_seen_attack_tick = 0
		return
	if seen.attack_tick < _last_seen_attack_tick:
		_reacted_to_attack = false  # empezó otro golpe
	_last_seen_attack_tick = seen.attack_tick
	if _reacted_to_attack or gap > seen.reach + 15.0:
		return
	_reacted_to_attack = true
	# Lo que vio pasó hace reaction_ticks: estima cuánto le falta al golpe ahora.
	var eta: int = seen.ticks_until_active - reaction_ticks
	var roll: float = _rng.randf()
	if roll < profile.dodge_chance and seen.zone == MoveData.Zone.HEAD and eta >= 2:
		_dodge_in = maxi(0, eta - 3)   # que la invulnerabilidad (desde el tick 3) cubra el golpe
	elif roll < profile.dodge_chance + profile.block_chance and eta >= 0:
		_guard_left = eta + 12
	# Si no le da el tiempo (eta < 0), el golpe le entra: así es un humano con reflejos normales.


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
	return s
