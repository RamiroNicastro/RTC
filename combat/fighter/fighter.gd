class_name Fighter
extends Node2D
## Un peleador dentro del combate.
##
## Regla R1: NO sabe quién lo controla. Cada tick recibe un FighterCommand y actualiza su estado.
## No tiene _physics_process propio: CombatScene lo avanza con tick() para controlar el orden.
## No resuelve choques con el rival ni con las cuerdas (eso lo hace Ring).
## Su origen (position) está en el centro de los pies.

signal state_changed(new_state: State)

enum State { IDLE, MOVING }

var setup: FighterSetup
## +1 = mira a la derecha, -1 = mira a la izquierda.
var facing: int = 1
var state: State = State.IDLE
## Posición al empezar el tick actual. Ring la usa para saber quién se movió hacia quién.
var previous_x: float = 0.0


func configure(fighter_setup: FighterSetup, facing_dir: int) -> void:
	setup = fighter_setup
	facing = facing_dir
	queue_redraw()


## Avanza un tick de lógica.
func tick(cmd: FighterCommand) -> void:
	previous_x = position.x
	match state:
		State.IDLE, State.MOVING:
			_tick_neutral(cmd)


func half_width() -> float:
	return setup.body_width * 0.5


func _tick_neutral(cmd: FighterCommand) -> void:
	if cmd.move == 0:
		_set_state(State.IDLE)
		return
	var speed: float = setup.forward_speed if cmd.move > 0 else setup.backward_speed
	position.x += cmd.move * facing * speed * CombatTime.SECONDS_PER_TICK
	_set_state(State.MOVING)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)
	queue_redraw()


# --- Placeholder visual (rectángulos). La lógica no depende de nada de esto. ---

func _draw() -> void:
	if setup == null:
		return
	var w: float = setup.body_width
	var h: float = setup.body_height
	var body_color: Color = setup.color.lightened(0.15) if state == State.MOVING else setup.color
	# Torso y piernas.
	draw_rect(Rect2(-w * 0.5, -h * 0.82, w, h * 0.82), body_color)
	# Cabeza (su borde superior coincide con body_height, que usa la cámara para encuadrar).
	var head_radius: float = w * 0.32
	draw_circle(Vector2(0, -h + head_radius), head_radius, body_color.lightened(0.25))
	# Guante adelantado: indica hacia dónde mira.
	var glove := Rect2(w * 0.35 * facing - 18.0, -h * 0.75, 36.0, 30.0)
	draw_rect(glove, Color(0.85, 0.1, 0.1))
