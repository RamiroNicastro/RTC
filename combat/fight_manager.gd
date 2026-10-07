class_name FightManager
extends RefCounted
## Árbitro de la pelea: rounds, reloj, knockdowns, cuenta, KO, TKO y final por tiempo.
##
## No mueve peleadores ni decide golpes: solo lleva el flujo de la pelea y le dice a CombatScene
## en qué fase está. Avanza con tick(), una vez por tick de lógica.
## Los jueces (decisión por puntos) llegan en el Hito E3.
##
## Flujo:  ROUND_INTRO → FIGHTING ⇄ COUNT → RESUME → FIGHTING … → (fin del tiempo) ROUND_BREAK → ROUND_INTRO …
##         Después del último round, o con KO/TKO: ENDED.

signal round_started(round_number: int)
signal round_ended(round_number: int)
## CombatScene lo escucha para devolver a los peleadores a su lugar y recuperarlos.
signal round_break_started(round_number: int)
signal knockdown_started(fighter: Fighter)
signal count_changed(count: int)
signal fighter_rose(fighter: Fighter)
signal fight_resumed()
signal fight_ended(winner: Fighter, method: Method)

enum Phase { ROUND_INTRO, FIGHTING, COUNT, RESUME, ROUND_BREAK, ENDED }
## DECISION: se terminaron los rounds (en el E3 los jueces deciden el ganador).
enum Method { NONE, KO, TKO, DECISION }

## Ticks por cada número de la cuenta (arcade: más rápida que un segundo real).
const COUNT_TICKS_PER_NUMBER: int = 45
const COUNT_OUT: int = 10
## Aunque llene la barra, no se levanta antes de esta cuenta (siempre hay un respiro para el que pegó).
const MIN_COUNT_TO_RISE: int = 3
## Caídas EN UN MISMO ROUND que terminan la pelea por KO técnico.
const KNOCKDOWNS_FOR_TKO: int = 3
## Pausa con el cartel "¡BOXEEN!" después de levantarse.
const RESUME_TICKS: int = 50
## Cartel "ROUND N — ¡BOXEEN!" al empezar cada round.
const ROUND_INTRO_TICKS: int = 80
## Descanso entre rounds (arcade: corto).
const ROUND_BREAK_TICKS: int = 180

var phase: Phase = Phase.FIGHTING
var round_number: int = 1
var total_rounds: int = 3
## Ticks que le quedan al round. El reloj solo corre en FIGHTING.
var round_ticks_left: int = 0
var count: int = 0
var downed: Fighter
var winner: Fighter
var method: Method = Method.NONE

var _a: Fighter
var _b: Fighter
var _round_ticks: int = 0
var _phase_ticks: int = 0


func setup(a: Fighter, b: Fighter, fight_setup: FightSetup) -> void:
	_a = a
	_b = b
	total_rounds = fight_setup.rounds
	_round_ticks = CombatTime.seconds_to_ticks(fight_setup.round_seconds)
	round_number = 1
	round_ticks_left = _round_ticks
	if fight_setup.start_with_intro:
		_set_phase(Phase.ROUND_INTRO)
	else:
		_set_phase(Phase.FIGHTING)
		round_started.emit(round_number)


func is_fighting() -> bool:
	return phase == Phase.FIGHTING


func is_last_round() -> bool:
	return round_number >= total_rounds


## CombatScene lo llama cuando un golpe deja a un peleador en KNOCKDOWN.
func on_knockdown(fighter: Fighter) -> void:
	if phase != Phase.FIGHTING:
		return
	downed = fighter
	count = 0
	knockdown_started.emit(fighter)
	if fighter.round_knockdowns >= KNOCKDOWNS_FOR_TKO:
		fighter.stay_down()
		_end(_other(fighter), Method.TKO)
		return
	_set_phase(Phase.COUNT)


func tick() -> void:
	_phase_ticks += 1
	match phase:
		Phase.ROUND_INTRO:
			if _phase_ticks >= ROUND_INTRO_TICKS:
				_set_phase(Phase.FIGHTING)
				round_started.emit(round_number)
		Phase.FIGHTING:
			round_ticks_left -= 1
			if round_ticks_left <= 0:
				_end_round()
		Phase.COUNT:
			_tick_count()
		Phase.RESUME:
			if _phase_ticks >= RESUME_TICKS:
				_set_phase(Phase.FIGHTING)
				fight_resumed.emit()
		Phase.ROUND_BREAK:
			if _phase_ticks >= ROUND_BREAK_TICKS:
				round_number += 1
				round_ticks_left = _round_ticks
				_set_phase(Phase.ROUND_INTRO)


## Segundos que le quedan al round, redondeando hacia arriba (para mostrar el reloj).
func seconds_left() -> int:
	return ceili(CombatTime.ticks_to_seconds(maxi(0, round_ticks_left)))


func _end_round() -> void:
	round_ended.emit(round_number)
	if is_last_round():
		_end(null, Method.DECISION)
		return
	_set_phase(Phase.ROUND_BREAK)
	round_break_started.emit(round_number)


func _tick_count() -> void:
	if downed.wants_to_rise() and count >= MIN_COUNT_TO_RISE:
		downed.rise()
		fighter_rose.emit(downed)
		downed = null
		_set_phase(Phase.RESUME)
		return
	if _phase_ticks % COUNT_TICKS_PER_NUMBER == 0:
		count += 1
		count_changed.emit(count)
		if count >= COUNT_OUT:
			downed.stay_down()
			_end(_other(downed), Method.KO)


func _end(fight_winner: Fighter, fight_method: Method) -> void:
	winner = fight_winner
	method = fight_method
	_set_phase(Phase.ENDED)
	fight_ended.emit(winner, method)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	_phase_ticks = 0


func _other(f: Fighter) -> Fighter:
	return _b if f == _a else _a
