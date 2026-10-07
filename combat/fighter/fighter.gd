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
signal guard_broken()
## Esquivó un golpe a la cabeza: tiene un counter disponible.
signal dodge_succeeded(info: HitInfo)

enum State { IDLE, MOVING, ATTACKING, HITSTUN, BLOCKING, BLOCKSTUN, GUARD_BROKEN, DODGING }
enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

## Si se aprieta un golpe hasta estos ticks antes de poder actuar, igual sale (se siente más responsivo).
const INPUT_BUFFER_TICKS: int = 6
## Ticks del destello al recibir un golpe (placeholder de feedback).
const FLASH_TICKS: int = 5

## --- Stamina (valores iniciales; se balancean en el Hito H) ---
## Ticks sin regenerar después de gastar stamina.
const REGEN_DELAY_TICKS: int = 40
## Multiplicadores de regeneración según lo que esté haciendo.
const REGEN_MULT_RETREAT: float = 1.0
const REGEN_MULT_ADVANCE: float = 0.4
const REGEN_MULT_GUARD: float = 0.3
## Debajo de este porcentaje de stamina, el peleador está CANSADO.
const TIRED_RATIO: float = 0.3
const TIRED_DAMAGE_MULT: float = 0.6
const TIRED_EXTRA_STARTUP_TICKS: int = 4
const TIRED_EXTRA_RECOVERY_TICKS: int = 4
const TIRED_MOVE_SPEED_MULT: float = 0.8
## Si la guardia se rompe por quedarse sin stamina (no por un golpe fuerte).
const EXHAUSTED_GUARD_BREAK_TICKS: int = 30

const GUARD_MOVE_SPEED_MULT: float = 0.5

var setup: FighterSetup
## +1 = mira a la derecha, -1 = mira a la izquierda.
var facing: int = 1
var state: State = State.IDLE
## Posición al empezar el tick actual. Ring la usa para saber quién se movió hacia quién.
var previous_x: float = 0.0

var health: int = 100
var max_health: int = 100
var stamina: float = 100.0
## Máximo actual = máximo base - fatiga - desgaste por golpes al cuerpo.
var max_stamina: float = 100.0
var base_max_stamina: float = 100.0
## Cansancio acumulado durante la pelea. Baja el máximo; entre rounds se recupera una parte.
var fatigue: float = 0.0
## Desgaste por golpes al cuerpo recibidos. Baja el máximo (con tope); entre rounds se recupera una parte.
var body_drain: float = 0.0

## Golpe en curso (null si no está atacando).
var current_move: MoveData
var attack_phase: AttackPhase = AttackPhase.NONE
## Ticks transcurridos desde que empezó el golpe actual (1 = primer tick de arranque).
var attack_tick: int = 0
## Un golpe aplica su efecto UNA sola vez, aunque tenga varios ticks activos.
var move_has_connected: bool = false
## Ticks que quedan de HITSTUN, BLOCKSTUN o GUARD_BROKEN.
var stun_left: int = 0
var flash_left: int = 0
## Ticks transcurridos del esquive actual (1 = primer tick).
var dodge_tick: int = 0
## Ticks que quedan para que el próximo golpe sea un COUNTER (después de un esquive exitoso).
var counter_ready_left: int = 0

# Arranque y recuperación efectivos del golpe actual (más largos si está cansado).
var _startup_ticks: int = 0
var _recovery_ticks: int = 0
var _attack_is_counter: bool = false
var _buffered_move: MoveData
var _buffered_dodge: bool = false
var _buffer_left: int = 0
var _regen_delay_left: int = 0
var _last_move_dir: int = 0


func configure(fighter_setup: FighterSetup, facing_dir: int) -> void:
	setup = fighter_setup
	facing = facing_dir
	max_health = setup.max_health
	health = max_health
	base_max_stamina = setup.max_stamina
	fatigue = 0.0
	body_drain = 0.0
	max_stamina = base_max_stamina
	stamina = max_stamina
	queue_redraw()


## Avanza un tick de lógica.
func tick(cmd: FighterCommand) -> void:
	previous_x = position.x
	_last_move_dir = 0
	_read_buffer(cmd)
	if flash_left > 0:
		flash_left -= 1
	if counter_ready_left > 0:
		counter_ready_left -= 1
	match state:
		State.IDLE, State.MOVING, State.BLOCKING:
			_tick_neutral(cmd)
		State.ATTACKING:
			_tick_attack(cmd)
		State.HITSTUN, State.BLOCKSTUN, State.GUARD_BROKEN:
			_tick_stun(cmd)
		State.DODGING:
			_tick_dodge(cmd)
	_regen_stamina()
	queue_redraw()


# --- Consultas (las usan HitResolver, HUD y debug) ---

func half_width() -> float:
	return setup.body_width * 0.5


## true si el golpe actual está en su fase activa y todavía no conectó.
func is_hit_active() -> bool:
	return state == State.ATTACKING and attack_phase == AttackPhase.ACTIVE and not move_has_connected


## true durante la ventana de invulnerabilidad del esquive. Protege SOLO la cabeza.
func is_dodging_head() -> bool:
	if state != State.DODGING:
		return false
	return dodge_tick > setup.dodge_startup_ticks \
			and dodge_tick <= setup.dodge_startup_ticks + setup.dodge_invuln_ticks


## true si el golpe actual es un counter (salió dentro de la ventana de un esquive exitoso).
func is_counter_attack() -> bool:
	return state == State.ATTACKING and _attack_is_counter


## Ticks que faltan para que el golpe actual llegue a su fase activa (0 si ya pasó o no está atacando).
## Lo usa el dummy de práctica para esquivar "a tiempo".
func ticks_until_active() -> int:
	if state != State.ATTACKING or attack_phase != AttackPhase.STARTUP:
		return 0
	return _startup_ticks - attack_tick + 1


func dodge_total_ticks() -> int:
	return setup.dodge_startup_ticks + setup.dodge_invuln_ticks + setup.dodge_recovery_ticks


func is_guarding() -> bool:
	return state == State.BLOCKING or state == State.BLOCKSTUN


func is_tired() -> bool:
	# Se mide contra el máximo BASE: la fatiga no hace que "cansado" se active más tarde.
	return stamina < base_max_stamina * TIRED_RATIO


func damage_multiplier() -> float:
	return TIRED_DAMAGE_MULT if is_tired() else 1.0


func guard_damage_reduction() -> float:
	return setup.tired_guard_damage_reduction if is_tired() else setup.guard_damage_reduction


## Total de ticks del golpe actual, con el arranque efectivo.
func current_move_total_ticks() -> int:
	if current_move == null:
		return 0
	return _startup_ticks + current_move.active_ticks + _recovery_ticks


# --- Llamadas desde CombatScene ---

## El HitResolver confirmó que el golpe de ESTE peleador conectó (o fue bloqueado).
func mark_move_connected() -> void:
	move_has_connected = true


## ESTE peleador recibe un golpe (conectado, bloqueado o esquivado).
func receive_hit(info: HitInfo) -> void:
	if info.result == HitInfo.Result.DODGED:
		_on_dodge_succeeded(info)
		return
	flash_left = FLASH_TICKS
	match info.result:
		HitInfo.Result.HIT:
			_take_damage(info.damage)
			_interrupt_attack()
			counter_ready_left = 0
			if info.move.max_stamina_drain > 0.0:
				_add_body_drain(info.move.max_stamina_drain)
			_enter_stun(State.HITSTUN, info.move.hitstun_ticks)
		HitInfo.Result.BLOCKED:
			_take_damage(info.damage)  # daño que pasa la guardia
			# Aguantar en los brazos cansa, pero NO genera fatiga: eso queda para lo que uno hace.
			spend_stamina(info.move.block_stamina_damage, false)
			if info.guard_broken:
				_enter_stun(State.GUARD_BROKEN, info.move.guard_break_ticks)
				guard_broken.emit()
			elif stamina <= 0.0:
				_enter_stun(State.GUARD_BROKEN, EXHAUSTED_GUARD_BREAK_TICKS)
				guard_broken.emit()
			else:
				_enter_stun(State.BLOCKSTUN, info.move.blockstun_ticks)
	hit_received.emit(info)
	queue_redraw()


## causes_fatigue = false para gastos que no son esfuerzo propio (por ejemplo, golpes recibidos en la guardia).
func spend_stamina(amount: float, causes_fatigue: bool = true) -> void:
	if amount <= 0.0:
		return
	stamina = maxf(0.0, stamina - amount)
	_regen_delay_left = REGEN_DELAY_TICKS
	if causes_fatigue:
		_add_fatigue(amount * setup.fatigue_ratio)


## Recupera una fracción de la fatiga (0.5 = la mitad). Lo va a usar el descanso entre rounds (Hito E2).
func recover_fatigue(fraction: float) -> void:
	fatigue *= 1.0 - clampf(fraction, 0.0, 1.0)
	_update_max_stamina()


## Recupera una fracción del desgaste por golpes al cuerpo. Lo va a usar el descanso entre rounds (Hito E2).
func recover_body_drain(fraction: float) -> void:
	body_drain *= 1.0 - clampf(fraction, 0.0, 1.0)
	_update_max_stamina()


func _add_fatigue(amount: float) -> void:
	fatigue = minf(fatigue + amount, base_max_stamina * setup.max_fatigue_ratio)
	_update_max_stamina()


func _add_body_drain(amount: float) -> void:
	body_drain = minf(body_drain + amount, base_max_stamina * setup.body_drain_cap_ratio)
	_update_max_stamina()


func _update_max_stamina() -> void:
	max_stamina = base_max_stamina - fatigue - body_drain
	stamina = minf(stamina, max_stamina)


# --- Estados ---

func _tick_neutral(cmd: FighterCommand) -> void:
	if _buffered_dodge:
		_start_dodge()
		return
	if _buffered_move != null:
		_start_attack(_buffered_move)
		return
	var speed: float = setup.forward_speed if cmd.move > 0 else setup.backward_speed
	if cmd.guard:
		speed *= GUARD_MOVE_SPEED_MULT
	if is_tired():
		speed *= TIRED_MOVE_SPEED_MULT
	if cmd.move != 0:
		position.x += cmd.move * facing * speed * CombatTime.SECONDS_PER_TICK
		_last_move_dir = cmd.move
	if cmd.guard:
		_set_state(State.BLOCKING)
	elif cmd.move != 0:
		_set_state(State.MOVING)
	else:
		_set_state(State.IDLE)


func _start_attack(move: MoveData) -> void:
	# El cansancio se evalúa ANTES de pagar el golpe.
	var tired: bool = is_tired()
	_startup_ticks = move.startup_ticks + (TIRED_EXTRA_STARTUP_TICKS if tired else 0)
	_recovery_ticks = move.recovery_ticks + (TIRED_EXTRA_RECOVERY_TICKS if tired else 0)
	spend_stamina(move.stamina_cost)
	current_move = move
	_attack_is_counter = counter_ready_left > 0
	counter_ready_left = 0
	_clear_buffer()
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
	if attack_tick <= _startup_ticks:
		attack_phase = AttackPhase.STARTUP
	elif attack_tick <= _startup_ticks + m.active_ticks:
		attack_phase = AttackPhase.ACTIVE
	elif attack_tick <= current_move_total_ticks():
		attack_phase = AttackPhase.RECOVERY
	else:
		_end_attack()
		return
	if previous_phase == AttackPhase.ACTIVE and attack_phase == AttackPhase.RECOVERY and not move_has_connected:
		spend_stamina(m.whiff_stamina_penalty)
		attack_whiffed.emit(m)


func _end_attack() -> void:
	_interrupt_attack()
	_set_state(State.IDLE)


func _interrupt_attack() -> void:
	current_move = null
	attack_phase = AttackPhase.NONE
	attack_tick = 0
	_attack_is_counter = false


func _start_dodge() -> void:
	spend_stamina(setup.dodge_stamina_cost)
	_clear_buffer()
	dodge_tick = 1
	_set_state(State.DODGING)


func _tick_dodge(cmd: FighterCommand) -> void:
	dodge_tick += 1
	if dodge_tick > dodge_total_ticks():
		dodge_tick = 0
		_set_state(State.IDLE)
		_tick_neutral(cmd)


## Esquive exitoso: se cancela la recuperación del esquive y el próximo golpe es un counter.
func _on_dodge_succeeded(info: HitInfo) -> void:
	dodge_tick = 0
	_set_state(State.IDLE)
	counter_ready_left = setup.counter_window_ticks
	dodge_succeeded.emit(info)
	hit_received.emit(info)


func _enter_stun(stun_state: State, ticks: int) -> void:
	stun_left = ticks
	_set_state(stun_state)


func _tick_stun(cmd: FighterCommand) -> void:
	stun_left -= 1
	if stun_left <= 0:
		_set_state(State.IDLE)
		_tick_neutral(cmd)


func _take_damage(amount: int) -> void:
	health = maxi(0, health - amount)  # Llegar a 0 todavía no hace nada: knockdown en el Hito E1.


func _regen_stamina() -> void:
	if _regen_delay_left > 0:
		_regen_delay_left -= 1
		return
	var mult: float = 0.0
	match state:
		State.IDLE:
			mult = 1.0
		State.MOVING:
			mult = REGEN_MULT_RETREAT if _last_move_dir < 0 else REGEN_MULT_ADVANCE
		State.BLOCKING:
			mult = REGEN_MULT_GUARD
	stamina = minf(max_stamina, stamina + setup.stamina_regen * mult * CombatTime.SECONDS_PER_TICK)


## Guarda la última acción apretada unos ticks. Prioridad si se aprietan juntas: esquive > fuerte > jab.
## Con el modificador de cuerpo apretado, el jab y el fuerte salen al cuerpo.
func _read_buffer(cmd: FighterCommand) -> void:
	if cmd.dodge:
		_buffered_dodge = true
		_buffered_move = null
		_buffer_left = INPUT_BUFFER_TICKS
	elif cmd.power:
		_buffered_move = setup.power_body if cmd.body else setup.power_punch
		_buffered_dodge = false
		_buffer_left = INPUT_BUFFER_TICKS
	elif cmd.jab:
		_buffered_move = setup.jab_body if cmd.body else setup.jab
		_buffered_dodge = false
		_buffer_left = INPUT_BUFFER_TICKS
	elif _buffer_left > 0:
		_buffer_left -= 1
		if _buffer_left == 0:
			_clear_buffer()


func _clear_buffer() -> void:
	_buffered_move = null
	_buffered_dodge = false
	_buffer_left = 0


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)


# --- Placeholder visual (rectángulos). La lógica no depende de nada de esto. ---

const GLOVE_COLOR := Color(0.85, 0.1, 0.1)

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
		State.BLOCKSTUN:
			lean = -4.0 * facing
		State.GUARD_BROKEN:
			body_color = setup.color.lerp(Color(0.6, 0.2, 0.8), 0.45)
			lean = -10.0 * facing
		State.DODGING:
			lean = -26.0 * facing  # se tira hacia atrás
	if flash_left > 0:
		body_color = Color(0.7, 0.85, 1.0) if state == State.BLOCKSTUN else Color.WHITE
	if is_tired():
		body_color = body_color.darkened(0.15)

	# Torso y piernas.
	draw_rect(Rect2(-w * 0.5 + lean, -h * 0.82, w, h * 0.82), body_color)
	# Cabeza (su borde superior coincide con body_height, que usa la cámara para encuadrar).
	var head_radius: float = w * 0.32
	var head_color: Color = body_color.lightened(0.25)
	if is_dodging_head():
		head_color.a = 0.35  # cabeza invulnerable
	draw_circle(Vector2(lean * 1.5, -h + head_radius), head_radius, head_color)
	_draw_gloves(w, h, head_radius)


func _draw_gloves(w: float, h: float, head_radius: float) -> void:
	var glove := Vector2(36.0, 30.0)
	match state:
		State.BLOCKING, State.BLOCKSTUN:
			# Guantes arriba, delante de la cara.
			var gx: float = w * 0.42 * facing
			draw_rect(Rect2(Vector2(gx - glove.x * 0.5, -h + head_radius * 0.4), glove), GLOVE_COLOR)
			draw_rect(Rect2(Vector2(gx - glove.x * 0.5, -h + head_radius * 0.4 + glove.y + 2.0), glove), GLOVE_COLOR)
		State.GUARD_BROKEN:
			# Brazos abiertos: guantes hacia atrás y abajo.
			var gx_back: float = -w * 0.55 * facing
			draw_rect(Rect2(Vector2(gx_back - glove.x * 0.5, -h * 0.55), glove), GLOVE_COLOR.darkened(0.3))
		_:
			# Dorado = tiene un counter listo.
			var color: Color = Color(1.0, 0.8, 0.1) if counter_ready_left > 0 or _attack_is_counter else GLOVE_COLOR
			draw_rect(_attack_glove_rect(w, h, glove), color)


func _attack_glove_rect(w: float, h: float, glove: Vector2) -> Rect2:
	var rest_front: float = w * 0.35
	var front: float = rest_front
	var size: Vector2 = glove
	var glove_y: float = -h * 0.75
	if state == State.ATTACKING and current_move != null:
		if current_move.zone == MoveData.Zone.BODY:
			glove_y = -h * 0.5
		var is_power: bool = current_move == setup.power_punch
		if is_power:
			size = glove * 1.25
		var full_extension: float = w * 0.5 + current_move.reach - size.x * 0.5
		match attack_phase:
			AttackPhase.STARTUP:
				front = rest_front - (24.0 if is_power else 8.0)  # carga hacia atrás
			AttackPhase.ACTIVE:
				front = full_extension
			AttackPhase.RECOVERY:
				var t: float = float(attack_tick - _startup_ticks - current_move.active_ticks) \
						/ float(_recovery_ticks)
				front = lerpf(full_extension, rest_front, t)
	var center_x: float = front * facing
	return Rect2(Vector2(center_x - size.x * 0.5, glove_y), size)
