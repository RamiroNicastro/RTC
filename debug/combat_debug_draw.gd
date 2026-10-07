class_name CombatDebugDraw
extends Node2D
## Dibuja en el MUNDO el alcance de los golpes (solo debug; el combate no lo conoce).
##
## - En reposo: contornos tenues del alcance del jab (blanco) y del fuerte (amarillo).
## - Atacando: barra del alcance coloreada según la fase:
##     gris = arranque (no pega), rojo = activo (puede conectar), azul = recuperación (expuesto).
## Se activa o desactiva con F2.

const COLOR_IDLE := Color(1, 1, 1, 0.25)
const COLOR_POWER_IDLE := Color(1, 0.85, 0.2, 0.25)
const COLOR_STARTUP := Color(0.7, 0.7, 0.7, 0.6)
const COLOR_ACTIVE := Color(1.0, 0.15, 0.15, 0.75)
const COLOR_RECOVERY := Color(0.3, 0.5, 1.0, 0.6)
const BAR_HEIGHT: float = 14.0

var _fighters: Array[Fighter] = []


func attach(a: Fighter, b: Fighter) -> void:
	_fighters = [a, b]
	z_index = 10


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for f in _fighters:
		if f.setup == null:
			continue
		var y: float = -f.setup.body_height * 0.75 + 8.0
		var front: float = f.position.x + f.half_width() * f.facing
		if f.state == Fighter.State.ATTACKING and f.current_move != null:
			if f.current_move.zone == MoveData.Zone.BODY:
				y = -f.setup.body_height * 0.5 + 8.0
			var color: Color = COLOR_STARTUP
			match f.attack_phase:
				Fighter.AttackPhase.ACTIVE:
					color = COLOR_ACTIVE
				Fighter.AttackPhase.RECOVERY:
					color = COLOR_RECOVERY
			draw_rect(_range_rect(front, f.current_move.reach, f.facing, y), color)
		else:
			# Contornos: alcance del fuerte (amarillo) y del jab (blanco). Relleno = su zona de distancia justa.
			var power: MoveData = f.setup.power_punch
			var jab: MoveData = f.setup.jab
			draw_rect(_range_rect(front, power.reach, f.facing, y + 9.0), COLOR_POWER_IDLE, false, 2.0)
			draw_rect(_sweet_rect(front, power, f.facing, y + 9.0), Color(COLOR_POWER_IDLE, 0.35))
			draw_rect(_range_rect(front, jab.reach, f.facing, y - 9.0), COLOR_IDLE, false, 2.0)
			draw_rect(_sweet_rect(front, jab, f.facing, y - 9.0), Color(COLOR_IDLE, 0.3))


func _sweet_rect(front: float, move: MoveData, facing: int, y: float) -> Rect2:
	var a: float = front + facing * move.sweet_gap_min
	var b: float = front + facing * minf(move.sweet_gap_max, move.reach)
	return Rect2(Vector2(minf(a, b), y - BAR_HEIGHT * 0.5), Vector2(absf(b - a), BAR_HEIGHT))


func _range_rect(front: float, reach: float, facing: int, y: float) -> Rect2:
	var x: float = front if facing > 0 else front - reach
	return Rect2(Vector2(x, y - BAR_HEIGHT * 0.5), Vector2(reach, BAR_HEIGHT))
