class_name FightManager
extends RefCounted
## Árbitro de la pelea: knockdowns, cuenta, KO y TKO. (Hito E1; en el E2 se suman los rounds y el reloj).
##
## No mueve peleadores ni decide golpes: solo lleva el flujo de la pelea y le dice a CombatScene
## en qué fase está. Avanza con tick(), una vez por tick de lógica.

signal knockdown_started(fighter: Fighter)
signal count_changed(count: int)
signal fighter_rose(fighter: Fighter)
signal fight_resumed()
signal fight_ended(winner: Fighter, method: Method)

enum Phase { FIGHTING, COUNT, RESUME, ENDED }
enum Method { NONE, KO, TKO }

## Ticks por cada número de la cuenta (arcade: más rápida que un segundo real).
const COUNT_TICKS_PER_NUMBER: int = 45
const COUNT_OUT: int = 10
## Aunque llene la barra, no se levanta antes de esta cuenta (siempre hay un respiro para el que pegó).
const MIN_COUNT_TO_RISE: int = 3
## Caídas que terminan la pelea por KO técnico (en el E2 pasan a contarse por round).
const KNOCKDOWNS_FOR_TKO: int = 3
## Pausa con el cartel "¡BOXEEN!" antes de seguir peleando.
const RESUME_TICKS: int = 50

var phase: Phase = Phase.FIGHTING
var count: int = 0
var downed: Fighter
var winner: Fighter
var method: Method = Method.NONE

var _a: Fighter
var _b: Fighter
var _phase_ticks: int = 0


func setup(a: Fighter, b: Fighter) -> void:
	_a = a
	_b = b


func is_fighting() -> bool:
	return phase == Phase.FIGHTING


## CombatScene lo llama cuando un golpe deja a un peleador en KNOCKDOWN.
func on_knockdown(fighter: Fighter) -> void:
	if phase != Phase.FIGHTING:
		return
	downed = fighter
	count = 0
	_phase_ticks = 0
	knockdown_started.emit(fighter)
	if fighter.knockdowns >= KNOCKDOWNS_FOR_TKO:
		_end(_other(fighter), Method.TKO)
		fighter.stay_down()
		return
	phase = Phase.COUNT


func tick() -> void:
	_phase_ticks += 1
	match phase:
		Phase.COUNT:
			_tick_count()
		Phase.RESUME:
			if _phase_ticks >= RESUME_TICKS:
				phase = Phase.FIGHTING
				_phase_ticks = 0
				fight_resumed.emit()


func _tick_count() -> void:
	if downed.wants_to_rise() and count >= MIN_COUNT_TO_RISE:
		downed.rise()
		fighter_rose.emit(downed)
		downed = null
		phase = Phase.RESUME
		_phase_ticks = 0
		return
	if _phase_ticks % COUNT_TICKS_PER_NUMBER == 0:
		count += 1
		count_changed.emit(count)
		if count >= COUNT_OUT:
			downed.stay_down()
			_end(_other(downed), Method.KO)


func _end(fight_winner: Fighter, fight_method: Method) -> void:
	phase = Phase.ENDED
	winner = fight_winner
	method = fight_method
	fight_ended.emit(winner, method)


func _other(f: Fighter) -> Fighter:
	return _b if f == _a else _a
