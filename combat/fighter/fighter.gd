class_name Fighter
extends Node2D
## Un peleador dentro del combate.
##
## Regla R1: NO sabe quién lo controla. Cada tick recibe un FighterCommand y actualiza su estado.
## No tiene _physics_process propio: CombatScene lo avanza con tick() para controlar el orden.
## No resuelve choques ni decide si sus golpes conectan (eso lo hacen Ring y HitResolver vía CombatScene).
## Su origen (position) está en el centro de los pies.

signal state_changed(new_state: State)
signal attack_started(move: MoveData)
## El golpe terminó su fase ACTIVE sin conectar.
signal attack_whiffed(move: MoveData)
signal hit_received(info: HitInfo)

enum State { IDLE, MOVING, ATTACKING, HITSTUN }
enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

## Si se aprieta un golpe hasta estos ticks antes de poder actuar, igual sale (se siente más responsivo).
const INPUT_BUFFER_TICKS: int = 6
## Ticks del destello blanco al recibir un golpe (placeholder de feedback).
const FLASH_TICKS: int = 5

var setup: FighterSetup
## +1 = mira a la derecha, -1 = mira a la izquierda.
var facing: int = 1
var state: State = State.IDLE
## Posición al empezar el tick actual. Ring la usa para saber quién se movió hacia quién.
var previous_x: float = 0.0

var health: int = 100
var max_health: int = 100

## Golpe en curso (null si no está atacando).
var current_move: MoveData
var attack_phase: AttackPhase = AttackPhase.NONE
## Ticks transcurridos desde que empezó el golpe actual (1 = primer tick de arranque).
var attack_tick: int = 0
## Un golpe aplica daño UNA sola vez, aunque tenga varios ticks activos.
var move_has_connected: bool = false
var hitstun_left: int = 0
var flash_left: int = 0

var _buffered_move: MoveData
var _buffer_left: int = 0


func configure(fighter_setup: FighterSetup, facing_dir: int) -> void:
	setup = fighter_setup
	facing = facing_dir
	max_health = setup.max_health
	health = max_health
	queue_redraw()


## Avanza un tick de lógica.
func tick(cmd: FighterCommand) -> void:
	previous_x = position.x
	_read_buffer(cmd)
	if flash_left > 0:
		flash_left -= 1
	match state:
		State.IDLE, State.MOVING:
			_tick_neutral(cmd)
		State.ATTACKING:
			_tick_attack(cmd)
		State.HITSTUN:
			_tick_hitstun(cmd)
	queue_redraw()


func half_width() -> float:
	return setup.body_width * 0.5


## true si el golpe actual está en su fase activa y todavía no conectó.
func is_hit_active() -> bool:
	return state == State.ATTACKING and attack_phase == AttackPhase.ACTIVE and not move_has_connected


## Lo llama CombatScene cuando el HitResolver confirma que el golpe de ESTE peleador conectó.
func mark_move_connected() -> void:
	move_has_connected = true


## Lo llama CombatScene cuando ESTE peleador recibe un golpe.
func receive_hit(info: HitInfo) -> void:
	health = maxi(0, health - info.damage)  # Llegar a 0 todavía no hace nada: knockdown en el Hito E1.
	flash_left = FLASH_TICKS
	# Recibir un golpe interrumpe cualquier ataque propio.
	current_move = null
	attack_phase = AttackPhase.NONE
	hitstun_left = info.move.hitstun_ticks
	_set_state(State.HITSTUN)
	hit_received.emit(info)
	queue_redraw()


# --- Estados ---

func _tick_neutral(cmd: FighterCommand) -> void:
	if _buffered_move != null:
		_start_attack(_buffered_move)
		return
	if cmd.move == 0:
		_set_state(State.IDLE)
		return
	var speed: float = setup.forward_speed if cmd.move > 0 else setup.backward_speed
	position.x += cmd.move * facing * speed * CombatTime.SECONDS_PER_TICK
	_set_state(State.MOVING)


func _start_attack(move: MoveData) -> void:
	current_move = move
	_buffered_move = null
	_buffer_left = 0
	move_has_connected = false
	attack_tick = 0
	_set_state(State.ATTACKING)
	attack_started.emit(move)
	_advance_attack()


func _tick_attack(cmd: FighterCommand) -> void:
	_advance_attack()
	if state != State.ATTACKING:
		# El golpe terminó en este tick: se puede actuar ya mismo (sin un tick muerto).
		_tick_neutral(cmd)


## Avanza el golpe un tick y calcula su fase a partir de los ticks del MoveData.
func _advance_attack() -> void:
	attack_tick += 1
	var m: MoveData = current_move
	var previous_phase: AttackPhase = attack_phase
	if attack_tick <= m.startup_ticks:
		attack_phase = AttackPhase.STARTUP
	elif attack_tick <= m.startup_ticks + m.active_ticks:
		attack_phase = AttackPhase.ACTIVE
	elif attack_tick <= m.total_ticks():
		attack_phase = AttackPhase.RECOVERY
	else:
		_end_attack()
		return
	if previous_phase == AttackPhase.ACTIVE and attack_phase == AttackPhase.RECOVERY and not move_has_connected:
		attack_whiffed.emit(m)


func _end_attack() -> void:
	current_move = null
	attack_phase = AttackPhase.NONE
	attack_tick = 0
	_set_state(State.IDLE)


func _tick_hitstun(cmd: FighterCommand) -> void:
	hitstun_left -= 1
	if hitstun_left <= 0:
		_set_state(State.IDLE)
		_tick_neutral(cmd)


func _read_buffer(cmd: FighterCommand) -> void:
	if cmd.jab:
		_buffered_move = setup.jab
		_buffer_left = INPUT_BUFFER_TICKS
	elif _buffer_left > 0:
		_buffer_left -= 1
		if _buffer_left == 0:
			_buffered_move = null


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)


# --- Placeholder visual (rectángulos). La lógica no depende de nada de esto. ---

func _draw() -> void:
	if setup == null:
		return
	var w: float = setup.body_width
	var h: float = setup.body_height
	var body_color: Color = setup.color
	var lean: float = 0.0
	match state:
		State.MOVING:
			body_color = setup.color.lightened(0.15)
		State.HITSTUN:
			body_color = setup.color.darkened(0.3)
			lean = -8.0 * facing  # se echa hacia atrás
	if flash_left > 0:
		body_color = Color.WHITE

	# Torso y piernas.
	draw_rect(Rect2(-w * 0.5 + lean, -h * 0.82, w, h * 0.82), body_color)
	# Cabeza (su borde superior coincide con body_height, que usa la cámara para encuadrar).
	var head_radius: float = w * 0.32
	draw_circle(Vector2(lean * 1.5, -h + head_radius), head_radius, body_color.lightened(0.25))
	# Guante: en reposo, adelante del pecho; al pegar se estira hasta el alcance del golpe.
	draw_rect(_glove_rect(w, h), Color(0.85, 0.1, 0.1))


func _glove_rect(w: float, h: float) -> Rect2:
	var glove_size := Vector2(36.0, 30.0)
	var rest_front: float = w * 0.35
	var front: float = rest_front
	if state == State.ATTACKING and current_move != null:
		var full_extension: float = w * 0.5 + current_move.reach - glove_size.x * 0.5
		match attack_phase:
			AttackPhase.STARTUP:
				front = rest_front - 8.0  # pequeña carga hacia atrás
			AttackPhase.ACTIVE:
				front = full_extension
			AttackPhase.RECOVERY:
				var t: float = float(attack_tick - current_move.startup_ticks - current_move.active_ticks) \
						/ float(current_move.recovery_ticks)
				front = lerpf(full_extension, rest_front, t)
	var center_x: float = front * facing
	return Rect2(Vector2(center_x - glove_size.x * 0.5, -h * 0.75), glove_size)
