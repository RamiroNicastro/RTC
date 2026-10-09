class_name WeekActions
extends RefCounted
## Las acciones de la semana (entrenar, trabajar, descansar) y el paso de la semana.
## Todos los números de balance de esta parte de la carrera están acá.
##
## Recibe el GameState como parámetro (`gs`) para poder probarlo sin depender del autoload.
## NO guarda en disco ni toca la pantalla: devuelve un resultado y la UI lo muestra.

## Entrenamientos del gimnasio, en el orden en que se muestran.
const TRAININGS: Array[TrainingData] = [
	preload("res://data/trainings/heavy_bag.tres"),
	preload("res://data/trainings/jump_rope.tres"),
	preload("res://data/trainings/running.tres"),
	preload("res://data/trainings/shadow.tres"),
	preload("res://data/trainings/mitts.tres"),
	preload("res://data/trainings/sparring.tres"),
]

## Puntos que sube la estadística principal en una sesión (con 30 en esa estadística).
const MAIN_GAIN: float = 2.6
## La secundaria sube esta fracción de la principal.
const SIDE_GAIN_RATIO: float = 0.4
## Sparring: lo que sube CADA estadística.
const SPARRING_GAIN: float = 0.9
## Rendimientos decrecientes: con 30 se gana el 100 %; con 100, casi nada.
const GROWTH_REFERENCE: float = 70.0
const MIN_GROWTH: float = 0.15
## Con menos de esta energía antes de entrenar, la sesión rinde menos.
const TIRED_ENERGY: int = 50
## Con 0 de energía la sesión rendiría esto (nunca se llega: hace falta energía para entrenar).
const TIRED_MIN_MULT: float = 0.6
## Con deuda (plata negativa) se entrena preocupado.
const DEBT_MULT: float = 0.75
## Moral: con esto o más se entrena con ganas; con menos de LOW_MORALE, desganado. Efecto chico.
const HIGH_MORALE: int = 70
const HIGH_MORALE_MULT: float = 1.1
const LOW_MORALE: int = 30
const LOW_MORALE_MULT: float = 0.85

const WORK_PAY: int = 150
const WORK_ENERGY: int = 30
const REST_ENERGY: int = 45
## Gastos fijos de cada semana (alquiler, comida, cuota del gimnasio).
const WEEKLY_EXPENSES: int = 100
## Energía que se recupera sola al pasar la semana (el domingo).
const WEEKEND_ENERGY: int = 25


static func find_training(id: StringName) -> TrainingData:
	for t in TRAININGS:
		if t.id == id:
			return t
	return null


static func can_train(gs: Object, t: TrainingData) -> bool:
	return gs.energy >= t.energy_cost


static func can_work(gs: Object) -> bool:
	return gs.energy >= WORK_ENERGY


## Cuánto rinde una sesión según la energía, la plata, la moral y las situaciones (1.0 = normal).
static func session_mult(gs: Object) -> float:
	var mult: float = 1.0
	if gs.energy < TIRED_ENERGY:
		mult *= lerpf(TIRED_MIN_MULT, 1.0, float(gs.energy) / TIRED_ENERGY)
	if gs.money < 0:
		mult *= DEBT_MULT
	mult *= morale_mult(gs.morale)
	mult *= EventRunner.training_mult(gs)
	return mult


static func morale_mult(morale: int) -> float:
	if morale >= HIGH_MORALE:
		return HIGH_MORALE_MULT
	if morale < LOW_MORALE:
		return LOW_MORALE_MULT
	return 1.0


## Rendimiento decreciente de una estadística (1.0 con 30).
static func growth(stat_value: int) -> float:
	return clampf((100.0 - stat_value) / GROWTH_REFERENCE, MIN_GROWTH, 1.3)


## Entrena. Devuelve {"gains": {stat: puntos enteros ganados}, "week": resultado de end_week o {}}.
static func train(gs: Object, t: TrainingData) -> Dictionary:
	if not can_train(gs, t):
		return {"gains": {}, "week": {}}
	var mult: float = session_mult(gs)
	var gains := {}
	if t.all_stats:
		for stat in gs.STAT_NAMES:
			_add_gain(gs, stat, SPARRING_GAIN * mult, gains)
	else:
		_add_gain(gs, t.main_stat, MAIN_GAIN * mult, gains)
		if t.side_stat != &"":
			_add_gain(gs, t.side_stat, MAIN_GAIN * SIDE_GAIN_RATIO * mult, gains)
	gs.energy -= t.energy_cost
	return {"gains": gains, "week": _use_action(gs)}


static func work(gs: Object) -> Dictionary:
	if not can_work(gs):
		return {"money": 0, "week": {}}
	gs.money += WORK_PAY
	gs.energy -= WORK_ENERGY
	return {"money": WORK_PAY, "week": _use_action(gs)}


static func rest(gs: Object) -> Dictionary:
	var before: int = gs.energy
	gs.energy = mini(gs.MAX_ENERGY, gs.energy + REST_ENERGY)
	return {"energy": gs.energy - before, "week": _use_action(gs)}


## Suma la ganancia (con rendimientos decrecientes) y guarda lo que no llega a un punto entero.
static func _add_gain(gs: Object, stat: StringName, amount: float, gains: Dictionary) -> void:
	var current: int = gs.fighter.get(stat)
	var key: String = String(stat)
	var total: float = float(gs.stat_progress.get(key, 0.0)) + amount * growth(current)
	var whole: int = mini(int(floor(total)), 100 - current)
	gs.fighter.set(stat, current + whole)
	gs.stat_progress[key] = 0.0 if current + whole >= 100 else total - whole
	if whole > 0:
		gains[stat] = whole


## Gasta una acción. Si era la última, pasa la semana y devuelve su resumen.
static func _use_action(gs: Object) -> Dictionary:
	gs.actions_left -= 1
	var result := {}
	if gs.actions_left <= 0:
		result = end_week(gs)
	gs.changed.emit()
	return result


## Pasa la semana: gastos fijos, algo de energía, acciones nuevas, la moral y las situaciones
## (EventRunner.apply_week) y, si toca, cumpleaños.
static func end_week(gs: Object) -> Dictionary:
	var age_before: int = gs.age()
	gs.week += 1
	gs.money -= WEEKLY_EXPENSES
	var before: int = gs.energy
	gs.energy = mini(gs.MAX_ENERGY, gs.energy + WEEKEND_ENERGY)
	var energy_gain: int = gs.energy - before
	var story: Dictionary = EventRunner.apply_week(gs)
	gs.actions_left = gs.ACTIONS_PER_WEEK
	return {
		"expenses": WEEKLY_EXPENSES,
		"energy": energy_gain,
		"birthday": gs.age() > age_before,
		"in_debt": gs.money < 0,
		"status_lines": story["lines"],
		"expired": story["expired"],
	}
