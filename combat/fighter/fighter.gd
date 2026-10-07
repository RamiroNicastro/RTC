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
signal knocked_down()

enum State { IDLE, MOVING, ATTACKING, HITSTUN, BLOCKING, BLOCKSTUN, GUARD_BROKEN, DODGING, KNOCKDOWN, KO }
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

## --- Knockdown (valores iniciales; en la carrera los modifica el Mentón) ---
## Toques (JAB o FUERTE) para levantarse en la primera caída, y cuántos más por cada caída siguiente.
const GETUP_BASE_TAPS: float = 8.0
const GETUP_TAPS_PER_KNOCKDOWN: float = 6.0
## Toques extra según el castigo acumulado: con TODA la salud máxima perdida se suman estos toques.
const GETUP_TAPS_PER_DEEP_DAMAGE: float = 30.0
## La barra para levantarse se vacía sola a este ritmo (toques por segundo) si no se aprieta.
const GETUP_DECAY_TAPS_PER_SECOND: float = 3.0
## Salud al levantarse (fracción del máximo): baja en cada caída, con un mínimo.
const RISE_HEALTH_RATIO: float = 0.4
const RISE_HEALTH_STEP: float = 0.1
const RISE_HEALTH_MIN_RATIO: float = 0.25

## --- Salud en dos capas y descanso entre rounds ---
## Fracción de cada golpe recibido que es daño PROFUNDO: baja la salud máxima por el resto de la pelea.
const DEEP_DAMAGE_RATIO: float = 0.35
## La salud máxima nunca baja de esta fracción de la base.
const MIN_MAX_HEALTH_RATIO: float = 0.4
## En el descanso se recupera esta fracción de la salud perdida (hasta el máximo actual).
const ROUND_HEAL_RATIO: float = 0.5
## En el descanso se recupera esta fracción de la fatiga y del desgaste del cuerpo.
const ROUND_FATIGUE_RECOVERY: float = 0.5
const ROUND_BODY_DRAIN_RECOVERY: float = 0.5

## --- Impulso, empuje y carga ---
## Qué tan rápido el impulso sigue al movimiento (por tick). Moverse ~0,3 s hacia adelante = impulso casi completo.
const MOMENTUM_FOLLOW: float = 0.15
## Con impulso completo: +30 % de daño avanzando, −40 % retrocediendo.
const MOMENTUM_FORWARD_BONUS: float = 0.3
const MOMENTUM_BACKWARD_PENALTY: float = 0.4
## El empuje se reparte en varios ticks: cada tick se aplica esta fracción de lo que falta.
const KNOCKBACK_STEP: float = 0.3
## Tick del arranque en el que se "congela" el golpe mientras se carga. Es la "zona muerta":
## un toque corto (en el celular dura 80–120 ms) se suelta antes de este tick y sale un fuerte normal, sin demora.
const CHARGE_HOLD_TICK: int = 8
## Stamina que cuesta cada tick de carga.
const CHARGE_STAMINA_PER_TICK: float = 0.2

## --- Golpe estrella y combo 1-2 (ampliación pedida por la persona) ---
## Cuánto llena el medidor de estrella (0–1) cada cosa bien hecha, y cuánto baja al recibir un fuerte.
const STAR_GAIN_COUNTER: float = 0.4
const STAR_GAIN_CLEAN_POWER: float = 0.25
const STAR_GAIN_DODGE: float = 0.15
const STAR_GAIN_TIP_JAB: float = 0.05
const STAR_LOSS_POWER_HIT: float = 0.15
## Golpe estrella: multiplicadores de daño y empuje (y siempre rompe la guardia).
const STAR_DAMAGE_MULT: float = 1.6
const STAR_KNOCKBACK_MULT: float = 1.8
## Combo 1-2: después de un jab que CONECTA, durante estos ticks el fuerte arranca más rápido.
const COMBO_WINDOW_TICKS: int = 24
const COMBO_STARTUP_CUT_TICKS: int = 6

var setup: FighterSetup
## +1 = mira a la derecha, -1 = mira a la izquierda.
var facing: int = 1
var state: State = State.IDLE
## Posición al empezar el tick actual. Ring la usa para saber quién se movió hacia quién.
var previous_x: float = 0.0

var health: int = 100
## Salud máxima ACTUAL: baja con el daño profundo y no se recupera durante la pelea.
var max_health: int = 100
var base_max_health: int = 100
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
## Caídas en toda la pelea (cada una hace más difícil levantarse).
var knockdowns: int = 0
## Caídas en el round actual (3 = KO técnico).
var round_knockdowns: int = 0
## Barra para levantarse: 0 = vacía, 1 = se puede levantar.
var getup_progress: float = 0.0
## Impulso: -1 (venía retrocediendo) a +1 (venía avanzando). Sigue al movimiento con suavidad.
var momentum: float = 0.0
## true mientras está cargando el fuerte (el rival lo ve venir).
var charging: bool = false
## Número de serie del golpe actual: sube con cada golpe nuevo (identifica cada golpe, aunque se cargue).
var attack_serial: int = 0
## Medidor de estrella (0–1). Lleno: el próximo fuerte es un golpe estrella.
var star_meter: float = 0.0
## Ticks que quedan de la ventana del combo 1-2 (después de un jab que conectó).
var combo_window_left: int = 0

# Arranque y recuperación efectivos del golpe actual (más largos si está cansado).
var _startup_ticks: int = 0
var _recovery_ticks: int = 0
var _attack_is_counter: bool = false
var _attack_is_star: bool = false
var _attack_is_combo: bool = false
var _attack_momentum: float = 0.0
var _charge_ticks: int = 0
var _knockback_left: float = 0.0
var _buffered_move: MoveData
var _buffered_dodge: bool = false
var _buffer_left: int = 0
var _regen_delay_left: int = 0
var _last_move_dir: int = 0


func configure(fighter_setup: FighterSetup, facing_dir: int) -> void:
	setup = fighter_setup
	facing = facing_dir
	base_max_health = setup.max_health
	max_health = base_max_health
	health = max_health
	knockdowns = 0
	round_knockdowns = 0
	star_meter = 0.0
	combo_window_left = 0
	base_max_stamina = setup.max_stamina
	fatigue = 0.0
	body_drain = 0.0
	max_stamina = base_max_stamina
	stamina = max_stamina


## Avanza un tick de lógica.
func tick(cmd: FighterCommand) -> void:
	previous_x = position.x
	_last_move_dir = 0
	_apply_knockback()
	_read_buffer(cmd)
	if flash_left > 0:
		flash_left -= 1
	if counter_ready_left > 0:
		counter_ready_left -= 1
	if combo_window_left > 0:
		combo_window_left -= 1
	match state:
		State.IDLE, State.MOVING, State.BLOCKING:
			_tick_neutral(cmd)
		State.ATTACKING:
			_tick_attack(cmd)
		State.HITSTUN, State.BLOCKSTUN, State.GUARD_BROKEN:
			_tick_stun(cmd)
		State.DODGING:
			_tick_dodge(cmd)
		State.KNOCKDOWN:
			_tick_knockdown(cmd)
		State.KO:
			pass
	# El impulso sigue al movimiento real de este tick (quieto o atacando, se va apagando).
	momentum = lerpf(momentum, float(_last_move_dir), MOMENTUM_FOLLOW)
	_regen_stamina()


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


## true si el golpe actual es un golpe estrella (fuerte con el medidor lleno).
func is_star_attack() -> bool:
	return state == State.ATTACKING and _attack_is_star


## true si el golpe actual salió como segundo golpe del combo 1-2.
func is_combo_attack() -> bool:
	return state == State.ATTACKING and _attack_is_combo


func star_ready() -> bool:
	return star_meter >= 1.0


## CombatScene: un golpe de ESTE peleador llegó al rival (HIT, BLOCKED o DODGED).
## Llena el medidor de estrella y abre la ventana del combo 1-2.
func notify_attack_result(info: HitInfo) -> void:
	if info.result != HitInfo.Result.HIT:
		return
	if info.counter:
		_add_star(STAR_GAIN_COUNTER)
	elif info.move.is_power_punch and info.range_mult >= 0.99 and info.momentum_mult >= 1.12:
		_add_star(STAR_GAIN_CLEAN_POWER)
	elif not info.move.is_power_punch and info.range_mult >= 0.99:
		_add_star(STAR_GAIN_TIP_JAB)
	if not info.move.is_power_punch:
		combo_window_left = COMBO_WINDOW_TICKS


func _add_star(amount: float) -> void:
	star_meter = clampf(star_meter + amount, 0.0, 1.0)


## Ticks que faltan para que el golpe actual llegue a su fase activa (0 si ya pasó o no está atacando).
## Lo usa el dummy de práctica para esquivar "a tiempo".
func ticks_until_active() -> int:
	if state != State.ATTACKING or attack_phase != AttackPhase.STARTUP:
		return 0
	return _startup_ticks - attack_tick + 1


func dodge_total_ticks() -> int:
	return setup.dodge_startup_ticks + setup.dodge_invuln_ticks + setup.dodge_recovery_ticks


func is_down() -> bool:
	return state == State.KNOCKDOWN or state == State.KO


## Toques necesarios para levantarse en la caída actual.
func getup_taps_required() -> float:
	var battered: float = 1.0 - float(max_health) / float(base_max_health)
	return GETUP_BASE_TAPS + GETUP_TAPS_PER_KNOCKDOWN * maxf(0.0, knockdowns - 1) \
			+ GETUP_TAPS_PER_DEEP_DAMAGE * battered


## true cuando llenó la barra para levantarse (FightManager decide cuándo se levanta).
func wants_to_rise() -> bool:
	return state == State.KNOCKDOWN and getup_progress >= 1.0


func is_guarding() -> bool:
	return state == State.BLOCKING or state == State.BLOCKSTUN


func is_tired() -> bool:
	# Se mide contra el máximo BASE: la fatiga no hace que "cansado" se active más tarde.
	return stamina < base_max_stamina * TIRED_RATIO


func damage_multiplier() -> float:
	return TIRED_DAMAGE_MULT if is_tired() else 1.0


## Impulso con el que salió el golpe actual: avanzando suma daño, retrocediendo resta.
func momentum_damage_multiplier() -> float:
	var m: float = _attack_momentum
	return 1.0 + MOMENTUM_FORWARD_BONUS * m if m > 0.0 else 1.0 + MOMENTUM_BACKWARD_PENALTY * m


## Carga del golpe actual: 0 = sin cargar, 1 = carga completa.
func charge_ratio() -> float:
	if current_move == null or not current_move.can_charge or current_move.max_charge_ticks <= 0:
		return 0.0
	return clampf(float(_charge_ticks) / current_move.max_charge_ticks, 0.0, 1.0)


## CombatScene: empuja a este peleador hacia atrás (se reparte en varios ticks; las cuerdas lo frenan).
func push_back(distance: float) -> void:
	_knockback_left += distance


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
			combo_window_left = 0
			if info.move.is_power_punch:
				_add_star(-STAR_LOSS_POWER_HIT)
			if info.move.max_stamina_drain > 0.0:
				_add_body_drain(info.move.max_stamina_drain)
			if health <= 0:
				_knockdown()
			else:
				_enter_stun(State.HITSTUN, info.move.hitstun_ticks)
		HitInfo.Result.BLOCKED:
			# El daño que pasa la guardia nunca tumba: deja como mínimo 1 de salud.
			_take_damage(mini(info.damage, maxi(0, health - 1)))
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


## FightManager: se levanta después de llenar la barra.
func rise() -> void:
	var ratio: float = maxf(RISE_HEALTH_MIN_RATIO, RISE_HEALTH_RATIO - RISE_HEALTH_STEP * (knockdowns - 1))
	health = mini(max_health, maxi(health, roundi(base_max_health * ratio)))
	getup_progress = 0.0
	_clear_buffer()  # los toques para levantarse no deben convertirse en un golpe
	_set_state(State.IDLE)


## CombatScene, en el descanso entre rounds: recupera parte de la salud, la fatiga y el cuerpo,
## y vuelve a un estado limpio. La salud máxima perdida (daño profundo) NO se recupera.
func recover_between_rounds() -> void:
	health = mini(max_health, health + roundi((max_health - health) * ROUND_HEAL_RATIO))
	recover_fatigue(ROUND_FATIGUE_RECOVERY)
	recover_body_drain(ROUND_BODY_DRAIN_RECOVERY)
	stamina = max_stamina
	round_knockdowns = 0
	reset_to_neutral()


## Corta cualquier acción en curso y queda quieto (descanso, inicio de round).
func reset_to_neutral() -> void:
	_interrupt_attack()
	_clear_buffer()
	counter_ready_left = 0
	stun_left = 0
	dodge_tick = 0
	flash_left = 0
	getup_progress = 0.0
	_regen_delay_left = 0
	_knockback_left = 0.0
	momentum = 0.0
	_set_state(State.IDLE)


## FightManager: no se levanta más (KO o TKO).
func stay_down() -> void:
	_clear_buffer()
	_set_state(State.KO)


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
	# Combo 1-2: el fuerte que sigue a un jab que conectó arranca más rápido.
	_attack_is_combo = move.is_power_punch and combo_window_left > 0
	if _attack_is_combo:
		_startup_ticks = maxi(4, _startup_ticks - COMBO_STARTUP_CUT_TICKS)
		combo_window_left = 0
	# Golpe estrella: el primer fuerte con el medidor lleno lo consume.
	_attack_is_star = move.is_power_punch and star_ready()
	if _attack_is_star:
		star_meter = 0.0
	_recovery_ticks = move.recovery_ticks + (TIRED_EXTRA_RECOVERY_TICKS if tired else 0)
	spend_stamina(move.stamina_cost)
	current_move = move
	attack_serial += 1
	_attack_momentum = momentum
	_charge_ticks = 0
	charging = false
	_attack_is_counter = counter_ready_left > 0
	counter_ready_left = 0
	_clear_buffer()
	move_has_connected = false
	attack_tick = 0
	_set_state(State.ATTACKING)
	attack_started.emit(move)
	_advance_attack()


func _tick_attack(cmd: FighterCommand) -> void:
	# Fuerte cargado: mientras se mantiene el botón, el golpe queda "congelado" en el arranque.
	charging = current_move.can_charge and attack_tick == CHARGE_HOLD_TICK and cmd.power_held \
			and _charge_ticks < current_move.max_charge_ticks
	if charging:
		_charge_ticks += 1
		spend_stamina(CHARGE_STAMINA_PER_TICK)
		return
	_advance_attack()
	# Paso adelante (lunge) durante el arranque si venía avanzando.
	if state == State.ATTACKING and attack_phase == AttackPhase.STARTUP and current_move.lunge > 0.0 \
			and _attack_momentum > 0.0:
		position.x += facing * current_move.lunge * _attack_momentum / float(_startup_ticks)
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
	_attack_is_star = false
	_attack_is_combo = false
	_attack_momentum = 0.0
	_charge_ticks = 0
	charging = false


func _apply_knockback() -> void:
	if _knockback_left <= 0.5:
		_knockback_left = 0.0
		return
	var step: float = maxf(1.0, _knockback_left * KNOCKBACK_STEP)
	step = minf(step, _knockback_left)
	position.x -= facing * step
	_knockback_left -= step


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
	_add_star(STAR_GAIN_DODGE)
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
	health = maxi(0, health - amount)
	# Capa profunda: una parte del daño baja el máximo para el resto de la pelea.
	var min_max: int = roundi(base_max_health * MIN_MAX_HEALTH_RATIO)
	max_health = maxi(min_max, max_health - roundi(amount * DEEP_DAMAGE_RATIO))
	health = mini(health, max_health)


func _knockdown() -> void:
	knockdowns += 1
	round_knockdowns += 1
	getup_progress = 0.0
	dodge_tick = 0
	stun_left = 0
	_clear_buffer()
	_set_state(State.KNOCKDOWN)
	knocked_down.emit()


## En el piso: cada toque de JAB o FUERTE llena la barra; si no se aprieta, se vacía de a poco.
func _tick_knockdown(cmd: FighterCommand) -> void:
	var per_tap: float = 1.0 / getup_taps_required()
	getup_progress -= GETUP_DECAY_TAPS_PER_SECOND * per_tap * CombatTime.SECONDS_PER_TICK
	if cmd.jab or cmd.power:
		getup_progress += per_tap
	getup_progress = clampf(getup_progress, 0.0, 1.0)
	_clear_buffer()


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
		State.KNOCKDOWN:
			mult = 1.0  # en el piso se recupera el aire
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


# --- Datos de solo lectura para el placeholder visual (FighterVisual). La lógica no depende de esto. ---

## Arranque efectivo del golpe actual en ticks (más largo si salió cansado). Solo lectura.
func startup_ticks_effective() -> int:
	return _startup_ticks


## Recuperación efectiva del golpe actual en ticks (más larga si salió cansado). Solo lectura.
func recovery_ticks_effective() -> int:
	return _recovery_ticks
