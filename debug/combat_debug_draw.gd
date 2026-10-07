class_name CombatDebugDraw
extends Node2D
## Dibuja en el MUNDO el alcance de los golpes (solo debug; el combate no lo conoce).
##
## - En reposo: contorno tenue del alcance del jab desde el borde delantero del cuerpo.
## - Atacando: barra del alcance coloreada según la fase:
##     gris = arranque (no pega), rojo = activo (puede conectar), azul = recuperación (expuesto).
## Se activa o desactiva con F2.

const COLOR_IDLE := Color(1, 1, 1, 0.25)
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
			var color: Color = COLOR_STARTUP
			match f.attack_phase:
				Fighter.AttackPhase.ACTIVE:
					color = COLOR_ACTIVE
				Fighter.AttackPhase.RECOVERY:
					color = COLOR_RECOVERY
			draw_rect(_range_rect(front, f.current_move.reach, f.facing, y), color)
		else:
			draw_rect(_range_rect(front, f.setup.jab.reach, f.facing, y), COLOR_IDLE, false, 2.0)


func _range_rect(front: float, reach: float, facing: int, y: float) -> Rect2:
	var x: float = front if facing > 0 else front - reach
	return Rect2(Vector2(x, y - BAR_HEIGHT * 0.5), Vector2(reach, BAR_HEIGHT))
