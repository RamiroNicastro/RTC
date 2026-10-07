class_name FighterVisual
extends Node2D
## Placeholder visual ARTICULADO del peleador: un boxeador en silueta estilizada dibujado por código.
##
## Es hijo del Fighter y SOLO LEE su estado ("la lógica manda y la animación obedece"): nunca lo
## modifica ni decide timings. Los golpes se dibujan a partir de attack_tick y sus fases; durante
## ACTIVE el borde del guante llega EXACTAMENTE a borde del cuerpo + reach (lo que dibuja el debug).
## Las animaciones secundarias (respiración, rebote, caminata, latigazo, caída) usan tiempo propio y
## delta: son solo visuales y no influyen en nada de la lógica.
## Medidas que respeta: pies en y = 0, punta de la cabeza en y = -body_height, ancho ~ body_width.
## Todo se calcula en "espacio adelante" (+x = hacia el rival) y se espeja con facing al dibujar.
## No usa imágenes: el estilo de arte final todavía no está decidido.

const OUTLINE_COLOR := Color(0.07, 0.06, 0.1)
const GLOVE_COLOR := Color(0.86, 0.1, 0.12)
const GLOVE_GOLD := Color(1.0, 0.76, 0.1)
const GLOVE_CHARGED := Color(1.0, 0.95, 0.4)
const CUFF_COLOR := Color(0.95, 0.93, 0.88)
const SHOE_COLOR := Color(0.14, 0.13, 0.17)
const SOCK_COLOR := Color(0.94, 0.94, 0.96)
const FLASH_HIT := Color(1.0, 1.0, 1.0)
const FLASH_BLOCK := Color(0.62, 0.8, 1.0)
const SWEAT_COLOR := Color(0.72, 0.9, 1.0, 0.9)
const STAR_COLOR := Color(1.0, 0.92, 0.3)
const SHADOW_COLOR := Color(0.0, 0.0, 0.05, 0.3)

## El muñeco se diseñó para un cuerpo de 90 × 250 y se escala a body_width × body_height.
const DESIGN_WIDTH: float = 90.0
const DESIGN_HEIGHT: float = 250.0
const HEAD_RADIUS: float = 25.0
const UPPER_ARM: float = 42.0
const FOREARM: float = 42.0
const THIGH: float = 60.0
const SHIN: float = 58.0
const GLOVE_RADIUS: float = 17.0
const OUTLINE: float = 2.5

## Suavizado de poses (por segundo): más alto = sigue más rápido al estado.
const BLEND_RATE: float = 14.0
const BLEND_RATE_FAST: float = 36.0
const BLEND_RATE_DOWN: float = 9.0
const BLEND_RATE_RISE: float = 6.0
const FALL_SECONDS: float = 0.42
const LAND_BOUNCE_SECONDS: float = 0.3
const RISE_SECONDS: float = 0.6


## Posiciones de las articulaciones en espacio adelante (+x hacia el rival, y hacia abajo, pies en 0).
class Pose:
	var hip := Vector2.ZERO
	var chest := Vector2.ZERO
	var head := Vector2.ZERO
	var lead_shoulder := Vector2.ZERO
	var rear_shoulder := Vector2.ZERO
	var lead_glove := Vector2.ZERO
	var rear_glove := Vector2.ZERO
	var lead_foot := Vector2.ZERO
	var rear_foot := Vector2.ZERO
	## Hacia dónde se doblan las rodillas y apuntan los pies: adelante parado, arriba acostado.
	var knee_dir := Vector2.RIGHT

	func copy() -> Pose:
		var p := Pose.new()
		p.blend_to(self, 1.0)
		return p

	## Se acerca a otra pose (t = 1: queda igual).
	func blend_to(o: Pose, t: float) -> void:
		hip = hip.lerp(o.hip, t)
		chest = chest.lerp(o.chest, t)
		head = head.lerp(o.head, t)
		lead_shoulder = lead_shoulder.lerp(o.lead_shoulder, t)
		rear_shoulder = rear_shoulder.lerp(o.rear_shoulder, t)
		lead_glove = lead_glove.lerp(o.lead_glove, t)
		rear_glove = rear_glove.lerp(o.rear_glove, t)
		lead_foot = lead_foot.lerp(o.lead_foot, t)
		rear_foot = rear_foot.lerp(o.rear_foot, t)
		knee_dir = knee_dir.lerp(o.knee_dir, t).normalized()

	func offset(v: Vector2) -> void:
		hip += v
		chest += v
		head += v
		lead_shoulder += v
		rear_shoulder += v
		lead_glove += v
		rear_glove += v
		lead_foot += v
		rear_foot += v

	func rotated_around(pivot: Vector2, angle: float) -> Pose:
		var p := copy()
		p.hip = pivot + (hip - pivot).rotated(angle)
		p.chest = pivot + (chest - pivot).rotated(angle)
		p.head = pivot + (head - pivot).rotated(angle)
		p.lead_shoulder = pivot + (lead_shoulder - pivot).rotated(angle)
		p.rear_shoulder = pivot + (rear_shoulder - pivot).rotated(angle)
		p.lead_glove = pivot + (lead_glove - pivot).rotated(angle)
		p.rear_glove = pivot + (rear_glove - pivot).rotated(angle)
		p.lead_foot = pivot + (lead_foot - pivot).rotated(angle)
		p.rear_foot = pivot + (rear_foot - pivot).rotated(angle)
		p.knee_dir = knee_dir.rotated(angle)
		return p


var _fighter: Fighter
var _pose: Pose
var _time: float = 0.0
## Escala de diseño a medidas reales.
var _sx: float = 1.0
var _sy: float = 1.0

# Caminata (se mide con el desplazamiento real del Fighter).
var _last_x: float = 0.0
var _speed: float = 0.0
var _walk_phase: float = 0.0
var _walk_amount: float = 0.0

# Caída y levantada.
var _prev_state: Fighter.State = Fighter.State.IDLE
var _fall_from: Pose
var _fall_t: float = 99.0
var _rise_left: float = 0.0

# Latigazo del último golpe recibido (resorte amortiguado, solo visual).
var _kick := Vector2.ZERO
var _kick_vel := Vector2.ZERO
var _stun_total: int = 1
var _hit_power: float = 0.55
var _hit_body: bool = false
var _hit_blocked: bool = false

# Variables de trabajo mientras se arma la pose objetivo (offsets en unidades de diseño).
var _guard_lead := Vector2.ZERO
var _guard_rear := Vector2.ZERO
var _lead_sh := Vector2.ZERO
var _rear_sh := Vector2.ZERO
var _atk_k: float = 0.0
var _atk_ext: float = 0.0
var _atk_wind: float = 0.0
var _atk_coil: float = 0.0
var _atk_crouch: float = 0.0

# Colores del frame (con destello aplicado).
var _flash: float = 0.0
var _flash_color := FLASH_HIT

# Triángulos del frame (se mandan juntos en una sola llamada).
var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
static var _unit_circle: PackedVector2Array = _make_unit_circle(18)
static var _unit_circle_small: PackedVector2Array = _make_unit_circle(10)


func _ready() -> void:
	_fighter = get_parent() as Fighter
	if _fighter != null:
		_fighter.hit_received.connect(_on_hit_received)
		_last_x = _fighter.position.x


func _process(delta: float) -> void:
	if _fighter == null or _fighter.setup == null:
		return
	var dt: float = minf(delta, 0.05)
	_time += dt
	_sx = _fighter.setup.body_width / DESIGN_WIDTH
	_sy = _fighter.setup.body_height / DESIGN_HEIGHT
	_update_walk(dt)
	_update_spring(dt)
	_update_state_change()
	_rise_left = maxf(0.0, _rise_left - dt)

	var target: Pose = _target_pose()
	if _pose == null:
		_pose = target
	elif _fighter.is_down() and _fall_t < 1.0:
		# Cayendo: la caída la arma _fall_pose directamente, sin suavizado.
		_fall_t = minf(1.0, _fall_t + dt / FALL_SECONDS)
		_pose = _fall_pose(_lying_pose())
	else:
		if _fighter.is_down():
			_fall_t += dt / LAND_BOUNCE_SECONDS
		_pose.blend_to(target, 1.0 - exp(-_blend_rate() * dt))
	if _fighter.state == Fighter.State.ATTACKING and _fighter.current_move != null:
		# El guante que pega sigue los ticks sin suavizado: en ACTIVE llega exacto al alcance.
		if _uses_lead_arm(_fighter.current_move):
			_pose.lead_glove = target.lead_glove
		else:
			_pose.rear_glove = target.rear_glove
	queue_redraw()


func _on_hit_received(info: HitInfo) -> void:
	# El que esquiva también recibe la señal (con DODGED): ahí no hay latigazo.
	if info.result == HitInfo.Result.DODGED or info.result == HitInfo.Result.WHIFF:
		return
	_hit_blocked = info.result == HitInfo.Result.BLOCKED
	_hit_body = info.zone == MoveData.Zone.BODY
	_hit_power = 1.0 if info.move != null and info.move.is_power_punch else 0.55
	_stun_total = maxi(1, _fighter.stun_left)
	var push: float = _hit_power * (1.0 + info.charge_ratio * 0.5)
	if _hit_blocked:
		_kick_vel += Vector2(-170.0, 10.0) * push
	elif _hit_body:
		_kick_vel += Vector2(140.0, 280.0) * push
	else:
		_kick_vel += Vector2(-700.0, 40.0) * push


func _update_walk(dt: float) -> void:
	var dx: float = _fighter.position.x - _last_x
	_last_x = _fighter.position.x
	if absf(dx) > 60.0:  # teletransporte (inicio de round): no es caminar
		dx = 0.0
	var moving: bool = _fighter.state == Fighter.State.MOVING or _fighter.state == Fighter.State.BLOCKING
	_speed = lerpf(_speed, absf(dx) / maxf(dt, 0.001) if moving else 0.0, 1.0 - exp(-12.0 * dt))
	_walk_amount = clampf(_speed / 140.0, 0.0, 1.0)
	# El paso avanza con la distancia recorrida (hacia atrás, el ciclo se invierte).
	_walk_phase += dx * float(_fighter.facing) / (34.0 * _sx) * PI


func _update_spring(dt: float) -> void:
	var acc: Vector2 = -_kick * 240.0 - _kick_vel * 17.0
	_kick_vel += acc * dt
	_kick += _kick_vel * dt


func _update_state_change() -> void:
	var s: Fighter.State = _fighter.state
	if s == _prev_state:
		return
	var was_down: bool = _prev_state == Fighter.State.KNOCKDOWN or _prev_state == Fighter.State.KO
	if _fighter.is_down() and not was_down and _pose != null:
		_fall_from = _pose.copy()
		_fall_t = 0.0
	if was_down and not _fighter.is_down():
		_rise_left = RISE_SECONDS
		_fall_t = 99.0
	_prev_state = s


func _blend_rate() -> float:
	if _rise_left > 0.0:
		return BLEND_RATE_RISE
	match _fighter.state:
		Fighter.State.ATTACKING, Fighter.State.HITSTUN, Fighter.State.BLOCKSTUN, \
				Fighter.State.GUARD_BROKEN, Fighter.State.DODGING:
			return BLEND_RATE_FAST
		Fighter.State.KNOCKDOWN, Fighter.State.KO:
			return BLEND_RATE_DOWN
	return BLEND_RATE


# --- Poses ---

func _d(x: float, y: float) -> Vector2:
	return Vector2(x * _sx, y * _sy)


## Pose a la que quiere llegar el muñeco según el estado actual del Fighter.
func _target_pose() -> Pose:
	var f: Fighter = _fighter
	if f.is_down():
		return _lying_pose()
	var p := Pose.new()
	var tired: bool = f.is_tired()
	# Rebote en puntas de pie: la cadera marca el ritmo y lo de arriba lo sigue con un poco de retraso.
	var bounce_hz: float = 1.6
	var bounce: float = 0.5 + 0.5 * sin(_time * TAU * bounce_hz)
	var lag: float = 0.5 + 0.5 * sin(_time * TAU * bounce_hz - 0.8)
	var breath: float = 0.5 + 0.5 * sin(_time * TAU * 0.45)
	if tired:
		bounce *= 0.25
		lag *= 0.25
		breath = 0.5 + 0.5 * sin(_time * TAU * 1.3)  # respiración agitada

	p.lead_foot = _d(30.0, -8.0)
	p.rear_foot = _d(-36.0, -8.0)
	p.hip = _d(-3.0, -104.0 + 3.0 * bounce)
	p.chest = _d(8.0, -184.0 + 2.5 * lag + 1.5 * breath)
	p.head = _d(16.0, -225.0 + 2.5 * lag + 1.0 * breath)
	# Guantes relativos a la cabeza (siguen a la cara) y hombros en la base del torso (adelante, abajo).
	_guard_lead = _d(54.0, 15.0 + 2.0 * lag)
	_guard_rear = _d(18.0, 29.0 + 1.5 * lag)
	_lead_sh = Vector2(16.0, 3.0 - 1.0 * breath)
	_rear_sh = Vector2(-15.0, 4.0 - 1.0 * breath)
	if tired:
		# Hombros caídos, encorvado, guardia más baja y el pecho subiendo y bajando.
		p.hip += _d(0.0, 4.0)
		p.chest += _d(4.0, 8.0 + 3.0 * breath)
		p.head += _d(8.0, 14.0 + 4.0 * breath)
		_lead_sh += Vector2(0.0, 5.0 - 3.0 * breath)
		_rear_sh += Vector2(0.0, 5.0 - 3.0 * breath)
		_guard_lead += _d(2.0, 22.0)
		_guard_rear += _d(-2.0, 24.0)

	# Inclinación por el impulso (avanzando se carga adelante).
	p.chest.x += 5.0 * _sx * f.momentum
	p.head.x += 7.0 * _sx * f.momentum

	# Caminata: pasos cortos alternados, el pie en el aire se levanta y la cadera sube un poco.
	if _walk_amount > 0.01:
		var a: float = _walk_amount
		var ph: float = _walk_phase
		p.lead_foot += _d(13.0 * sin(ph), -10.0 * maxf(0.0, cos(ph))) * a
		p.rear_foot += _d(13.0 * sin(ph + PI), -10.0 * maxf(0.0, cos(ph + PI))) * a
		var lift: float = absf(cos(ph))
		p.hip.y -= 3.0 * _sy * lift * a
		p.chest.y -= 2.0 * _sy * lift * a
		p.head.y -= 1.5 * _sy * lift * a

	var lead_abs := Vector2.ZERO
	var lead_w: float = 0.0
	var rear_abs := Vector2.ZERO
	var rear_w: float = 0.0
	match f.state:
		Fighter.State.BLOCKING, Fighter.State.BLOCKSTUN:
			_set_high_guard(p, tired)
			if f.state == Fighter.State.BLOCKSTUN:
				var k: float = _stun_ratio()
				p.chest += _d(-7.0, 1.0) * k
				p.head += _d(-10.0, 3.0) * k
				p.hip += _d(-3.0, 1.0) * k
				_guard_lead += _d(-5.0, 0.0) * k
				_guard_rear += _d(-3.0, 0.0) * k
		Fighter.State.HITSTUN:
			var k: float = sqrt(_stun_ratio()) * _hit_power
			if _hit_body:
				# Se dobla hacia adelante, cola atrás, guantes al estómago.
				p.chest += _d(9.0, 20.0) * k
				p.head += _d(15.0, 32.0) * k
				p.hip += _d(-9.0, 7.0) * k
				lead_abs = p.hip + _d(30.0, -34.0)
				rear_abs = p.hip + _d(18.0, -26.0)
			else:
				# Latigazo: la cabeza se va para atrás más que el torso, mentón arriba.
				p.chest += _d(-18.0, 5.0) * k
				p.head += _d(-36.0, 5.0) * k
				p.hip += _d(-6.0, 6.0) * k  # se le aflojan las rodillas
				lead_abs = p.chest + _d(30.0, 24.0)
				rear_abs = p.chest + _d(8.0, 34.0)
			lead_w = 0.9 * minf(1.0, k * 1.6)
			rear_w = lead_w
		Fighter.State.GUARD_BROKEN:
			var wob: float = sin(_time * TAU * 1.7)
			p.hip += _d(-4.0, 6.0)
			p.chest += _d(-9.0 + 3.0 * wob, 6.0)
			p.head += _d(-9.0 + 6.0 * wob, 10.0 + 2.0 * absf(wob))
			_lead_sh += Vector2(3.0, 0.0)
			_rear_sh += Vector2(-6.0, 0.0)
			lead_abs = p.chest + _d(60.0, 40.0 + 6.0 * wob)
			rear_abs = p.chest + _d(-52.0, 36.0 - 6.0 * wob)
			lead_w = 1.0
			rear_w = 1.0
		Fighter.State.DODGING:
			var d: float = _dodge_amount()
			p.hip += _d(-10.0, 18.0) * d
			p.chest += _d(-26.0, 38.0) * d
			p.head += _d(-36.0, 50.0) * d
			p.rear_foot += _d(-6.0, 0.0) * d
			p.lead_foot += _d(4.0, 0.0) * d
			_guard_lead = _guard_lead.lerp(_d(28.0, 10.0), d)
			_guard_rear = _guard_rear.lerp(_d(20.0, 28.0), d)
		Fighter.State.ATTACKING:
			if f.current_move != null:
				_attack_progress()
				_attack_body(p)

	# Latigazo del golpe recibido (resorte): mueve más la cabeza que el torso.
	p.head += _kick * _sx
	p.chest += _kick * 0.45 * _sx
	p.hip += _kick * 0.12 * _sx

	p.lead_glove = (p.head + _guard_lead).lerp(lead_abs, lead_w)
	p.rear_glove = (p.head + _guard_rear).lerp(rear_abs, rear_w)
	if f.state == Fighter.State.ATTACKING and f.current_move != null:
		_attack_gloves(p)

	# Temblor de esfuerzo mientras carga el fuerte.
	if f.charging:
		var c: float = f.charge_ratio()
		var shake := Vector2(sin(_time * 71.0), cos(_time * 53.0)) * 1.6 * c * _sx
		p.head += shake
		p.chest += shake * 0.6

	_place_shoulders(p)
	p.knee_dir = Vector2.RIGHT
	return p


## Guardia cerrada: los dos guantes delante de la cara, mentón abajo, un poco más agachado.
func _set_high_guard(p: Pose, tired: bool) -> void:
	p.hip += _d(0.0, 4.0)
	p.chest += _d(3.0, 6.0)
	p.head += _d(-1.0, 10.0)
	_guard_lead = _d(31.0, 2.0)
	_guard_rear = _d(24.0, 26.0)
	if tired:
		_guard_lead += _d(0.0, 12.0)
		_guard_rear += _d(0.0, 10.0)


func _place_shoulders(p: Pose) -> void:
	var up: Vector2 = (p.chest - p.hip).normalized()
	var fwd := Vector2(-up.y, up.x)
	p.lead_shoulder = p.chest + fwd * _lead_sh.x * _sx - up * _lead_sh.y * _sy
	p.rear_shoulder = p.chest + fwd * _rear_sh.x * _sx - up * _rear_sh.y * _sy


func _stun_ratio() -> float:
	return clampf(float(_fighter.stun_left) / float(_stun_total), 0.0, 1.0)


## 0 = parado, 1 = esquive a fondo. Sigue los ticks del esquive (arranque, invulnerable, recuperación).
func _dodge_amount() -> float:
	var s: FighterSetup = _fighter.setup
	var t: int = _fighter.dodge_tick
	if t <= s.dodge_startup_ticks:
		return _ease_out(float(t) / maxf(1.0, s.dodge_startup_ticks))
	if t <= s.dodge_startup_ticks + s.dodge_invuln_ticks:
		return 1.0
	var r: float = float(t - s.dodge_startup_ticks - s.dodge_invuln_ticks) / maxf(1.0, s.dodge_recovery_ticks)
	return 1.0 - _smooth(clampf(r, 0.0, 1.0))


func _uses_lead_arm(m: MoveData) -> bool:
	# Jab con la mano adelantada; el fuerte con la de atrás (cruzado).
	return not m.is_power_punch


## Calcula cuánto del golpe se ve (todo a partir de attack_tick y las fases del Fighter).
func _attack_progress() -> void:
	var f: Fighter = _fighter
	var m: MoveData = f.current_move
	var su: int = maxi(1, f.startup_ticks_effective())
	var rc: int = maxi(1, f.recovery_ticks_effective())
	var t: int = f.attack_tick
	_atk_k = 0.0
	_atk_ext = 0.0
	_atk_wind = 0.0
	_atk_coil = 0.0
	_atk_crouch = 0.0
	match f.attack_phase:
		Fighter.AttackPhase.STARTUP:
			var s: float = clampf(float(t) / su, 0.0, 1.0)
			_atk_crouch = minf(1.0, s * 2.5)
			if m.is_power_punch:
				# Se arma rápido (antes del tick de carga), espera, y los últimos ticks suelta.
				var hold: int = mini(Fighter.CHARGE_HOLD_TICK, su)
				var throw_ticks: int = maxi(1, mini(4, su - hold))
				var throw_start: int = su - throw_ticks
				if t <= throw_start:
					_atk_coil = _ease_out(clampf(float(t) / maxf(1.0, hold), 0.0, 1.0))
				else:
					var th: float = float(t - throw_start) / throw_ticks
					_atk_coil = 1.0 - th
					_atk_ext = 0.45 * th * th
					_atk_k = 0.5 * th
			else:
				# Jab: amague mínimo hacia atrás y sale.
				_atk_wind = s / 0.5 if s < 0.5 else (1.0 - s) / 0.5
				_atk_ext = 0.0 if s < 0.5 else (s - 0.5) / 0.5 * 0.5
				_atk_k = 0.4 * s
		Fighter.AttackPhase.ACTIVE:
			_atk_k = 1.0
			_atk_ext = 1.0
			_atk_crouch = 1.0
		Fighter.AttackPhase.RECOVERY:
			var r: float = clampf(float(t - su - m.active_ticks) / rc, 0.0, 1.0)
			var back: float = 1.0 - (_ease_out(r) if not m.is_power_punch else _smooth(r))
			_atk_k = back
			_atk_ext = back
			_atk_crouch = back


func _attack_body(p: Pose) -> void:
	var m: MoveData = _fighter.current_move
	var c: float = _fighter.charge_ratio()
	if m.zone == MoveData.Zone.BODY:
		# Al cuerpo: flexiona las piernas y baja el torso para pegar a la altura del estómago.
		var cz: float = _atk_crouch
		p.hip += _d(-2.0, 14.0) * cz
		p.chest += _d(8.0, 24.0) * cz
		p.head += _d(10.0, 28.0) * cz
		p.lead_foot += _d(5.0, 0.0) * cz
	var k: float = _atk_k
	if _uses_lead_arm(m):
		p.chest += _d(9.0, 2.0) * k
		p.head += _d(8.0, 4.0) * k
		p.hip += _d(3.0, 0.0) * k
		p.lead_foot += _d(5.0, 0.0) * k
		_lead_sh += Vector2(12.0, -1.0) * k
		_rear_sh += Vector2(-4.0, 0.0) * k
	else:
		# Fuerte: se carga hacia atrás (más cuanto más carga) y después rota el torso entero.
		var coil: float = _atk_coil
		p.chest += _d(-11.0 - 12.0 * c, 5.0 + 5.0 * c) * coil + _d(18.0, 4.0) * k
		p.hip += _d(-4.0, 6.0 + 7.0 * c) * coil + _d(7.0, 0.0) * k
		p.head += _d(-10.0 - 11.0 * c, 8.0 + 6.0 * c) * coil + _d(17.0, 6.0) * k
		_rear_sh += Vector2(-9.0 - 7.0 * c, 0.0) * coil + Vector2(38.0, -1.0) * k
		_lead_sh += Vector2(4.0, 0.0) * coil + Vector2(-20.0, 1.0) * k
		p.rear_foot += _d(8.0, -5.0) * k  # gira sobre la punta del pie de atrás
		# La mano adelantada "mide" la distancia mientras se arma; al soltar, vuelve a cubrir el mentón.
		_guard_lead = _guard_lead.lerp(_d(66.0, 22.0), coil * (1.0 - k)).lerp(_d(18.0, 26.0), k)


func _attack_gloves(p: Pose) -> void:
	var f: Fighter = _fighter
	var m: MoveData = f.current_move
	var r: float = GLOVE_RADIUS * _sx + OUTLINE
	var aim_y: float = -0.55 if m.zone == MoveData.Zone.BODY else -0.84
	# El borde exterior del guante llega exacto a borde del cuerpo + alcance (igual que el debug).
	var target := Vector2(f.half_width() + m.reach - r, aim_y * f.setup.body_height)
	var active: bool = f.attack_phase == Fighter.AttackPhase.ACTIVE
	if _uses_lead_arm(m):
		var guard: Vector2 = p.head + _guard_lead
		p.lead_glove = target if active else guard.lerp(target, _atk_ext) + _d(-8.0, 3.0) * _atk_wind
	else:
		var c: float = f.charge_ratio()
		var cocked: Vector2 = p.head + _d(-12.0 - 16.0 * c, 20.0 - 4.0 * c)
		var start: Vector2 = (p.head + _guard_rear).lerp(cocked, _atk_coil)
		p.rear_glove = target if active else start.lerp(target, _atk_ext)


## Tirado en la lona boca arriba, con la cabeza lejos del rival. Con la barra para levantarse se incorpora.
func _lying_pose() -> Pose:
	var p := Pose.new()
	p.knee_dir = Vector2.UP
	var ko: bool = _fighter.state == Fighter.State.KO
	var torso_len: float = 80.0
	if ko:
		# KO: estirado e inerte, un brazo por encima de la cabeza.
		p.lead_foot = _d(44.0, -8.0)
		p.rear_foot = _d(58.0, -7.0)
		p.hip = _d(-50.0, -19.0)
		p.chest = p.hip + _d(-torso_len, -2.0)
		p.head = p.chest + _d(-40.0, -4.0)
		p.lead_glove = _d(-210.0, -17.0)
		p.rear_glove = _d(-56.0, -17.0)
	else:
		# Knockdown: rodillas arriba; se va apoyando en los codos a medida que llena la barra.
		var g: float = _fighter.getup_progress
		var breath: float = 0.5 + 0.5 * sin(_time * TAU * 0.9)
		var ang: float = 0.55 * g + 0.04 * breath
		p.lead_foot = _d(16.0, -8.0)
		p.rear_foot = _d(38.0, -7.0)
		p.hip = _d(-46.0, -20.0)
		p.chest = p.hip + _d(-torso_len, 0.0).rotated(ang)
		p.head = p.chest + _d(-39.0, -6.0).rotated(ang * 1.4)
		p.lead_glove = _d(-98.0 + 22.0 * g, -17.0)
		p.rear_glove = _d(-74.0 + 16.0 * g, -17.0)
	# Rebote al tocar la lona.
	if _fall_t >= 1.0 and _fall_t < 2.0:
		var b: float = sin((_fall_t - 1.0) * PI) * 7.0 * _sy
		p.hip.y -= b * 0.6
		p.chest.y -= b
		p.head.y -= b * 1.2
	_lead_sh = Vector2(16.0, 3.0)
	_rear_sh = Vector2(-15.0, 4.0)
	_place_shoulders(p)
	return p


## Caída hacia atrás: gira sobre los pies con aceleración (como con gravedad) y termina en la pose tirada.
func _fall_pose(lying: Pose) -> Pose:
	var e: float = 0.3 * _fall_t + 0.7 * _fall_t * _fall_t  # arranca con el envión del golpe y acelera
	var pivot: Vector2 = (_fall_from.lead_foot + _fall_from.rear_foot) * 0.5
	var p: Pose = _fall_from.rotated_around(pivot, -PI * 0.5 * e)
	p.blend_to(lying, e)
	return p


# --- Dibujo ---
# Todo el muñeco se arma como UNA lista de triángulos y se manda en una sola llamada al RenderingServer:
# draw_circle / draw_colored_polygon cuestan decenas de microsegundos cada una (triangulan en cada llamada)
# y con ~150 piezas por peleador se notaba en el frame. Los triángulos se dibujan en orden (de atrás hacia adelante).

func _draw() -> void:
	if _fighter == null or _fighter.setup == null or _pose == null:
		return
	var f: Fighter = _fighter
	var p: Pose = _pose
	_pts.resize(0)
	_cols.resize(0)
	_idx.resize(0)

	_flash = float(f.flash_left) / float(Fighter.FLASH_TICKS)
	_flash_color = FLASH_BLOCK if _hit_blocked else FLASH_HIT

	var base: Color = f.setup.color
	var skin: Color = base
	if f.is_tired() and not f.is_down():
		var gray: float = skin.get_luminance()
		skin = skin.lerp(Color(gray, gray, gray), 0.25).darkened(0.08)
	if f.state == Fighter.State.KO:
		skin = skin.darkened(0.18)
	var skin_far: Color = skin.darkened(0.24)
	var shorts := Color.from_hsv(base.h, clampf(base.s * 1.1, 0.3, 1.0), base.v * 0.36)
	var shorts_far: Color = shorts.darkened(0.25)
	var stripe := Color.from_hsv(base.h, base.s * 0.2, 0.97)
	var hair := Color.from_hsv(base.h, base.s * 0.5, base.v * 0.22)

	var gold: bool = f.counter_ready_left > 0 or f.is_counter_attack()
	var glove: Color = GLOVE_COLOR
	if gold:
		glove = GLOVE_GOLD.lightened(0.15 * (0.5 + 0.5 * sin(_time * TAU * 3.0)))
	var rear_glove: Color = glove
	var charge: float = f.charge_ratio() if f.state == Fighter.State.ATTACKING else 0.0
	if charge > 0.0:
		rear_glove = GLOVE_COLOR.lerp(GLOVE_CHARGED, charge)

	_draw_shadow(p)

	var up: Vector2 = (p.chest - p.hip).normalized()
	var fwd := Vector2(-up.y, up.x)
	var lead_hip: Vector2 = p.hip + fwd * 7.0 * _sx
	var rear_hip: Vector2 = p.hip - fwd * 7.0 * _sx
	var elbow_pref := Vector2(-0.35, 1.0)

	# Atrás (lado lejano, más oscuro): pierna y brazo adelantados.
	_draw_leg(lead_hip, p.lead_foot, p.knee_dir, skin_far, shorts_far, stripe.darkened(0.25))
	var lead_elbow: Vector2 = _ik(p.lead_shoulder, p.lead_glove, UPPER_ARM * _sy, FOREARM * _sy, elbow_pref)
	_draw_arm(p.lead_shoulder, lead_elbow, p.lead_glove, skin_far)
	# Torso, cintura del short, pierna cercana (con su pernera), elástico y cabeza.
	_draw_torso(p, skin)
	_draw_shorts_waist(p, shorts)
	_draw_leg(rear_hip, p.rear_foot, p.knee_dir, skin, shorts, stripe)
	_draw_waistband(p, stripe)
	_draw_head(p, skin, hair)
	# Guante adelantado (delante de la cara en guardia) y brazo trasero, el más cercano.
	_draw_glove_fx(p.lead_glove, lead_elbow, true, charge)
	_draw_glove(p.lead_glove, lead_elbow, glove.darkened(0.12))
	var rear_elbow: Vector2 = _ik(p.rear_shoulder, p.rear_glove, UPPER_ARM * _sy, FOREARM * _sy, elbow_pref)
	_draw_arm(p.rear_shoulder, rear_elbow, p.rear_glove, skin)
	_draw_glove_fx(p.rear_glove, rear_elbow, false, charge)
	_draw_glove(p.rear_glove, rear_elbow, rear_glove)
	_draw_status_fx(p)

	# Espejado según hacia dónde mira y una sola llamada con todos los triángulos.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(f.facing), 1.0))
	if not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _idx, _pts, _cols)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tint(c: Color) -> Color:
	if _flash <= 0.0:
		return c
	return Color(c.lerp(_flash_color, 0.75 * _flash), c.a)


func _draw_shadow(p: Pose) -> void:
	var x0: float = minf(minf(p.lead_foot.x, p.rear_foot.x), minf(p.head.x, p.hip.x)) - 16.0 * _sx
	var x1: float = maxf(maxf(p.lead_foot.x, p.rear_foot.x), maxf(p.head.x, p.hip.x)) + 16.0 * _sx
	_tri_ellipse(Vector2((x0 + x1) * 0.5, 0.0), Vector2((x1 - x0) * 0.5, 7.0 * _sy), SHADOW_COLOR)


## Dos segmentos gruesos con contorno (el contorno de los dos va primero para que la articulación no se marque).
func _draw_limb(a: Vector2, b: Vector2, c: Vector2, w1: float, w2: float, col: Color) -> void:
	var oc: Color = OUTLINE_COLOR
	_tri_segment(a, b, w1 + OUTLINE * 2.0, oc)
	_tri_segment(b, c, w2 + OUTLINE * 2.0, oc)
	_tri_circle(a, w1 * 0.5 + OUTLINE, oc)
	_tri_circle(b, w1 * 0.5 + OUTLINE, oc)
	_tri_circle(c, w2 * 0.5 + OUTLINE, oc)
	var fill: Color = _tint(col)
	_tri_segment(a, b, w1, fill)
	_tri_segment(b, c, w2, fill)
	_tri_circle(a, w1 * 0.5, fill)
	_tri_circle(b, w1 * 0.5, fill)
	_tri_circle(c, w2 * 0.5, fill)


func _draw_leg(hip_joint: Vector2, ankle: Vector2, knee_dir: Vector2, skin: Color, shorts: Color, stripe: Color) -> void:
	var knee: Vector2 = _ik(hip_joint, ankle, THIGH * _sy, SHIN * _sy, knee_dir)
	_draw_limb(hip_joint, knee, ankle, 21.0 * _sx, 16.0 * _sx, skin)
	# Media y botita de boxeo.
	var shin_dir: Vector2 = (ankle - knee).normalized()
	var toe: Vector2 = knee_dir.normalized()
	var down: Vector2 = toe.rotated(PI * 0.5)
	var sock_top: Vector2 = ankle - shin_dir * 12.0 * _sy
	_tri_segment(sock_top, ankle, 17.0 * _sx + OUTLINE * 2.0, OUTLINE_COLOR)
	_tri_segment(sock_top, ankle, 17.0 * _sx, _tint(SOCK_COLOR))
	var heel: Vector2 = ankle + down * 2.0 * _sy - toe * 5.0 * _sx
	var tip: Vector2 = ankle + down * 3.0 * _sy + toe * 14.0 * _sx
	var shoe_w: float = 12.0 * _sy
	_tri_capsule(heel, tip, shoe_w * 0.5 + OUTLINE, OUTLINE_COLOR)
	_tri_capsule(heel, tip, shoe_w * 0.5, _tint(SHOE_COLOR))
	# Pernera holgada que se abre hacia abajo. Arriba no lleva contorno: se funde con la cintura.
	var thigh_dir: Vector2 = (knee - hip_joint).normalized()
	var a: Vector2 = hip_joint - thigh_dir * 13.0 * _sy
	var b: Vector2 = hip_joint + thigh_dir * THIGH * 0.52 * _sy
	var sw: float = 30.0 * _sx
	var n := Vector2(-thigh_dir.y, thigh_dir.x)
	if n.dot(knee_dir) < 0.0:
		n = -n
	var top_front: Vector2 = a + n * sw * 0.45
	var top_back: Vector2 = a - n * sw * 0.45
	var low_front: Vector2 = b + n * sw * 0.6
	var low_back: Vector2 = b - n * sw * 0.6
	var ol: float = OUTLINE * 1.6
	_tri_quad(top_front, low_front, low_back, top_back, _tint(shorts))
	_tri_segment(top_front, low_front, ol, OUTLINE_COLOR)
	_tri_segment(low_front, low_back, ol, OUTLINE_COLOR)
	_tri_segment(low_back, top_back, ol, OUTLINE_COLOR)
	# Franja lateral del short.
	_tri_segment(top_front.lerp(top_back, 0.2), low_front.lerp(low_back, 0.2), 3.0 * _sx, _tint(stripe))


func _draw_arm(shoulder: Vector2, elbow: Vector2, glove: Vector2, skin: Color) -> void:
	var wrist: Vector2 = glove - (glove - elbow).normalized() * GLOVE_RADIUS * 0.9 * _sx
	_draw_limb(shoulder, elbow, wrist, 17.0 * _sx, 14.0 * _sx, skin)
	# Deltoides: hombro redondeado.
	var r: float = 12.0 * _sx
	_tri_circle(shoulder, r + OUTLINE, OUTLINE_COLOR)
	_tri_circle(shoulder, r, _tint(skin))


## Puntos en "espacio del torso": x = u (0 en la cadera, 1 en la base del cuello), y = lado (+ = pecho).
func _torso_points(p: Pose, shape: Array[Vector2]) -> PackedVector2Array:
	var axis: Vector2 = p.chest - p.hip
	var length: float = axis.length()
	var up: Vector2 = axis / maxf(length, 0.001)
	var fwd := Vector2(-up.y, up.x)
	var pts := PackedVector2Array()
	for s in shape:
		pts.append(p.hip + up * length * s.x + fwd * s.y * _sx)
	return pts


func _draw_torso(p: Pose, skin: Color) -> void:
	var pts: PackedVector2Array = _chaikin(_torso_points(p, [
		Vector2(1.1, 13.0), Vector2(1.02, 27.0), Vector2(0.72, 25.0), Vector2(0.38, 17.0),
		Vector2(0.0, 18.0), Vector2(-0.06, 0.0), Vector2(0.0, -19.0), Vector2(0.38, -17.0),
		Vector2(0.72, -24.0), Vector2(1.02, -25.0), Vector2(1.1, -12.0),
	]), 2)
	_tri_fan(pts, OUTLINE_COLOR, OUTLINE * 1.3)
	_tri_fan(pts, _tint(skin))
	# Brillo del pecho (volumen) y línea del pectoral.
	_tri_fan(_chaikin(_torso_points(p, [
		Vector2(0.98, 22.0), Vector2(0.78, 22.0), Vector2(0.6, 16.0), Vector2(0.72, 8.0), Vector2(0.95, 10.0),
	]), 2), _tint(skin.lightened(0.18)))
	var pec: PackedVector2Array = _torso_points(p, [Vector2(0.62, 23.0), Vector2(0.56, 14.0), Vector2(0.62, 4.0)])
	var pec_col: Color = _tint(skin.darkened(0.3))
	_tri_segment(pec[0], pec[1], 2.0, pec_col)
	_tri_segment(pec[1], pec[2], 2.0, pec_col)


func _draw_shorts_waist(p: Pose, shorts: Color) -> void:
	var pts: PackedVector2Array = _chaikin(_torso_points(p, [
		Vector2(0.26, 21.0), Vector2(0.26, -20.0), Vector2(-0.1, -24.0), Vector2(-0.22, -4.0), Vector2(-0.12, 25.0),
	]), 1)
	_tri_fan(pts, OUTLINE_COLOR, OUTLINE * 1.3)
	_tri_fan(pts, _tint(shorts))


## Cintura elástica clara (va encima de las perneras).
func _draw_waistband(p: Pose, stripe: Color) -> void:
	var band: PackedVector2Array = _torso_points(p, [Vector2(0.21, 21.0), Vector2(0.21, -20.0)])
	_tri_segment(band[0], band[1], 8.0 * _sy + OUTLINE * 2.0, OUTLINE_COLOR)
	_tri_segment(band[0], band[1], 8.0 * _sy, _tint(stripe))


func _draw_head(p: Pose, skin: Color, hair: Color) -> void:
	var f: Fighter = _fighter
	var r: float = HEAD_RADIUS * _sy
	var up: Vector2 = (p.head - p.chest).normalized()
	var fwd := Vector2(-up.y, up.x)
	var alpha: float = 0.4 if f.is_dodging_head() else 1.0
	# Cuello.
	var neck_a: Vector2 = p.chest - up * 4.0 * _sy
	var neck_b: Vector2 = p.head - up * r * 0.3
	_tri_segment(neck_a, neck_b, 19.0 * _sx + OUTLINE * 2.0, OUTLINE_COLOR)
	_tri_segment(neck_a, neck_b, 19.0 * _sx, _tint(skin.darkened(0.12)))

	var oc := Color(OUTLINE_COLOR, alpha)
	var face := Color(_tint(skin), alpha)
	var jaw: Vector2 = p.head + fwd * r * 0.38 - up * r * 0.42
	var jaw_r: float = r * 0.6
	_tri_circle(p.head, r + OUTLINE, oc)
	_tri_circle(jaw, jaw_r + OUTLINE, oc)
	_tri_circle(p.head, r, face)
	_tri_circle(jaw, jaw_r, face)
	# Pelo: casquete arriba y atrás (franja entre dos arcos).
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var steps: int = 10
	for i in steps + 1:
		var t: float = float(i) / steps
		outer.append(p.head + up.rotated(lerpf(0.55, -2.05, t)) * r)
		inner.append(p.head + up.rotated(lerpf(0.4, -1.75, t)) * r * 0.55 + up * r * 0.12)
	_tri_strip(outer, inner, Color(_tint(hair), alpha))
	# Oreja.
	var ear: Vector2 = p.head - fwd * r * 0.22 - up * r * 0.08
	_tri_circle(ear, r * 0.17, Color(_tint(skin.darkened(0.2)), alpha))
	_tri_circle(ear, r * 0.07, Color(_tint(skin.darkened(0.45)), alpha))
	# Nariz.
	_tri_circle(p.head + fwd * r * 0.98 - up * r * 0.12, r * 0.17, Color(_tint(skin.darkened(0.08)), alpha))
	# Ojo y ceja (cambian con el estado).
	var eye: Vector2 = p.head + fwd * r * 0.55 + up * r * 0.12
	var brow_a: Vector2 = eye + up * r * 0.28 - fwd * r * 0.2
	var brow_b: Vector2 = eye + up * r * 0.2 + fwd * r * 0.25
	var ink := Color(OUTLINE_COLOR, alpha)
	match f.state:
		Fighter.State.KO:
			var s: float = r * 0.16
			_tri_segment(eye + Vector2(-s, -s), eye + Vector2(s, s), 2.5, ink)
			_tri_segment(eye + Vector2(-s, s), eye + Vector2(s, -s), 2.5, ink)
		Fighter.State.HITSTUN, Fighter.State.KNOCKDOWN, Fighter.State.GUARD_BROKEN:
			_tri_segment(eye - fwd * r * 0.16, eye + fwd * r * 0.16, 2.5, ink)
			brow_a += up * r * 0.08
		_:
			_tri_circle(eye, r * 0.11, ink)
			if f.state == Fighter.State.ATTACKING or f.charging:
				brow_b -= up * r * 0.12  # ceño fruncido al pegar
	_tri_segment(brow_a, brow_b, 3.0, ink)


func _draw_glove(c: Vector2, elbow: Vector2, col: Color) -> void:
	var r: float = GLOVE_RADIUS * _sx
	var dir: Vector2 = (c - elbow).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var n := Vector2(-dir.y, dir.x)
	if n.y > 0.0:
		n = -n  # el pulgar va del lado de arriba
	var cuff_a: Vector2 = c - dir * r * 0.75
	var cuff_b: Vector2 = c - dir * r * 1.3
	var thumb: Vector2 = c + n * r * 0.6 - dir * r * 0.3
	var oc: Color = OUTLINE_COLOR
	_tri_segment(cuff_a, cuff_b, r * 1.25 + OUTLINE * 2.0, oc)
	_tri_circle(c, r + OUTLINE, oc)
	_tri_circle(thumb, r * 0.42 + OUTLINE, oc)
	_tri_segment(cuff_a, cuff_b, r * 1.25, _tint(CUFF_COLOR))
	_tri_circle(c, r, _tint(col))
	_tri_circle(thumb, r * 0.42 + 1.2, Color(oc, 0.45))
	_tri_circle(thumb, r * 0.42, _tint(col.darkened(0.12)))
	# Brillo.
	_tri_circle(c + n * r * 0.3 + dir * r * 0.25, r * 0.3, Color(_tint(col.lightened(0.45)), 0.7))


## Brillos alrededor del guante: carga del fuerte, counter listo y líneas de velocidad en el golpe activo.
func _draw_glove_fx(c: Vector2, elbow: Vector2, is_lead: bool, charge: float) -> void:
	var f: Fighter = _fighter
	var r: float = GLOVE_RADIUS * _sx
	if charge > 0.0 and not is_lead:
		var pulse: float = 0.5 + 0.5 * sin(_time * 22.0)
		_tri_circle(c, r * (1.5 + 0.25 * pulse + 0.4 * charge), Color(1.0, 0.85, 0.25, 0.18 + 0.2 * charge))
	if f.counter_ready_left > 0:
		var pulse: float = 0.5 + 0.5 * sin(_time * TAU * 3.0)
		_tri_circle(c, r * (1.4 + 0.2 * pulse), Color(1.0, 0.8, 0.2, 0.22))
	if f.state == Fighter.State.ATTACKING and f.attack_phase == Fighter.AttackPhase.ACTIVE \
			and f.current_move != null and _uses_lead_arm(f.current_move) == is_lead:
		var dir: Vector2 = (c - elbow).normalized()
		var n := Vector2(-dir.y, dir.x)
		for i in 3:
			var off: Vector2 = n * (float(i) - 1.0) * r * 0.6
			var length: float = (34.0 if i == 1 else 22.0) * _sx
			var a: Vector2 = c - dir * (r + 6.0 * _sx) + off
			_tri_segment(a, a - dir * length, 2.5, Color(1.0, 1.0, 1.0, 0.65))


func _draw_status_fx(p: Pose) -> void:
	var f: Fighter = _fighter
	var r: float = HEAD_RADIUS * _sy
	var up: Vector2 = (p.head - p.chest).normalized()
	var fwd := Vector2(-up.y, up.x)
	# Guardia rota: estrellitas girando alrededor de la cabeza.
	if f.state == Fighter.State.GUARD_BROKEN:
		var center: Vector2 = p.head + up * r * 0.9
		for i in 3:
			var a: float = _time * 5.0 + TAU * i / 3.0
			_draw_star(center + Vector2(cos(a) * r * 1.3, sin(a) * r * 0.35), 6.0 * _sx)
	# Cansado: gotas de sudor que saltan de la cabeza hacia atrás.
	if f.is_tired() and not f.is_down():
		for i in 2:
			var t: float = fposmod(_time * 1.4 + i * 0.5, 1.0)
			var start: Vector2 = p.head - fwd * r * 0.5 + up * r * 0.7
			var pos: Vector2 = start - fwd * 26.0 * _sx * t + up * (14.0 * t - 34.0 * t * t) * _sy
			var col := Color(SWEAT_COLOR, SWEAT_COLOR.a * (1.0 - t))
			_tri_circle(pos, 3.2 * _sx, col)
			_tri_fan(PackedVector2Array([pos + up * 6.0 * _sy, pos + fwd * 3.0 * _sx, pos - fwd * 3.0 * _sx]), col)


func _draw_star(pos: Vector2, size: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad: float = size if i % 2 == 0 else size * 0.45
		var a: float = -PI * 0.5 + TAU * i / 10.0 + _time * 3.0
		pts.append(pos + Vector2(cos(a), sin(a)) * rad)
	_tri_fan(pts, OUTLINE_COLOR, 1.5)
	_tri_fan(pts, STAR_COLOR)


# --- Primitivas: agregan triángulos a la lista del frame ---

func _tri_circle(c: Vector2, r: float, col: Color) -> void:
	_tri_ellipse(c, Vector2(r, r), col)


func _tri_ellipse(c: Vector2, radius: Vector2, col: Color) -> void:
	var unit: PackedVector2Array = _unit_circle_small if maxf(radius.x, radius.y) < 9.0 else _unit_circle
	var base: int = _pts.size()
	var n: int = unit.size()
	_pts.append(c)
	_cols.append(col)
	for v in unit:
		_pts.append(c + v * radius)
		_cols.append(col)
	for i in n:
		_idx.append(base)
		_idx.append(base + 1 + i)
		_idx.append(base + 1 + (i + 1) % n)


## Segmento grueso (rectángulo) de a a b.
func _tri_segment(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var d: Vector2 = b - a
	var length: float = d.length()
	if length < 0.001:
		return
	var n: Vector2 = Vector2(-d.y, d.x) * (width * 0.5 / length)
	_tri_quad(a + n, b + n, b - n, a - n, col)


func _tri_capsule(a: Vector2, b: Vector2, radius: float, col: Color) -> void:
	_tri_segment(a, b, radius * 2.0, col)
	_tri_circle(a, radius, col)
	_tri_circle(b, radius, col)


func _tri_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var base: int = _pts.size()
	_pts.append_array(PackedVector2Array([a, b, c, d]))
	_cols.append_array(PackedColorArray([col, col, col, col]))
	_idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


## Polígono en abanico desde su centro (sirve para formas "estrelladas" como el torso).
## grow > 0 lo agranda hacia afuera (para el contorno).
func _tri_fan(points: PackedVector2Array, col: Color, grow: float = 0.0) -> void:
	var n: int = points.size()
	if n < 3:
		return
	var center := Vector2.ZERO
	for v in points:
		center += v
	center /= float(n)
	var base: int = _pts.size()
	_pts.append(center)
	_cols.append(col)
	for v in points:
		_pts.append(v + (v - center).normalized() * grow if grow > 0.0 else v)
		_cols.append(col)
	for i in n:
		_idx.append(base)
		_idx.append(base + 1 + i)
		_idx.append(base + 1 + (i + 1) % n)


## Franja entre dos líneas paralelas de puntos (misma cantidad).
func _tri_strip(a: PackedVector2Array, b: PackedVector2Array, col: Color) -> void:
	var base: int = _pts.size()
	var n: int = a.size()
	for i in n:
		_pts.append(a[i])
		_pts.append(b[i])
		_cols.append(col)
		_cols.append(col)
	for i in n - 1:
		var k: int = base + i * 2
		_idx.append_array(PackedInt32Array([k, k + 1, k + 3, k, k + 3, k + 2]))


# --- Utilidades ---

## Dos huesos (a y b) desde root hacia target. Si no llega, el brazo se estira derecho (estilo arcade).
## pref elige hacia qué lado se dobla la articulación (codos abajo, rodillas adelante).
func _ik(root: Vector2, target: Vector2, a: float, b: float, pref: Vector2) -> Vector2:
	var to: Vector2 = target - root
	var d: float = to.length()
	if d < 0.001:
		return root + pref.normalized() * a
	var dir: Vector2 = to / d
	if d >= a + b:
		return root + dir * (a * d / (a + b))
	d = maxf(d, absf(a - b) + 0.01)
	var x: float = (a * a - b * b + d * d) / (2.0 * d)
	var y: float = sqrt(maxf(0.0, a * a - x * x))
	var n := Vector2(-dir.y, dir.x)
	if n.dot(pref) < 0.0:
		n = -n
	return root + dir * x + n * y


static func _make_unit_circle(segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a: float = TAU * i / segments
		pts.append(Vector2(cos(a), sin(a)))
	return pts


## Suaviza un polígono cerrado (esquinas redondeadas).
func _chaikin(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var pts: PackedVector2Array = points
	for _i in iterations:
		var out := PackedVector2Array()
		var n: int = pts.size()
		for j in n:
			var a: Vector2 = pts[j]
			var b: Vector2 = pts[(j + 1) % n]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		pts = out
	return pts


func _ease_out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
