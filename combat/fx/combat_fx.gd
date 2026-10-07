class_name CombatFX
extends Node2D
## Efectos visuales del combate (placeholder arcade): chispas, anillos de impacto, polvo,
## carteles flotantes ("¡COUNTER!", "3 GOLPES"…) y destello de pantalla.
##
## Solo MUESTRA cosas: no cambia la lógica ni los timings. CombatScene le avisa qué pasó.
## Se anima en _process (es visual: usa delta y sigue moviéndose durante el hitstop, que se ve bien).

const SPARK_COLOR_HIT := Color(1.0, 0.92, 0.6)
const SPARK_COLOR_BODY := Color(1.0, 0.65, 0.35)
const SPARK_COLOR_BLOCK := Color(0.6, 0.85, 1.0)
const SPARK_COLOR_COUNTER := Color(1.0, 0.8, 0.15)

## Golpes seguidos sin recibir para mostrar el cartel de combo.
const COMBO_MIN: int = 3


class Particle:
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var color: Color
	var size: float
	var kind: int  # 0 = chispa (línea), 1 = anillo, 2 = polvo (círculo)


class FloatText:
	var text: String
	var pos: Vector2
	var life: float
	var max_life: float
	var color: Color
	var font_size: int


var _particles: Array[Particle] = []
var _popups: Array[FloatText] = []
var _rng := RandomNumberGenerator.new()
var _combo_owner: Fighter
var _combo: int = 0
var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
## El peleador del jugador (fighter_a por convención) y su rival: para la marca de distancia justa
## y para pintar distinto los carteles de cada uno.
var _player: Fighter
var _rival: Fighter
var _time: float = 0.0


func setup(player: Fighter, rival: Fighter) -> void:
	_player = player
	_rival = rival


func _ready() -> void:
	z_index = 20
	_rng.randomize()
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 12
	add_child(_flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_layer.add_child(_flash_rect)


## CombatScene: un golpe llegó (HIT, BLOCKED o DODGED).
func on_hit(info: HitInfo) -> void:
	var d: Fighter = info.defender
	var h: float = d.setup.body_height
	var y: float = -h * (0.5 if info.zone == MoveData.Zone.BODY else 0.84)
	var point := Vector2(d.position.x - d.facing * d.half_width() * 0.8, y)
	var strength: float = clampf(info.damage / 14.0, 0.15, 1.6)
	match info.result:
		HitInfo.Result.HIT:
			var color: Color = SPARK_COLOR_COUNTER if info.counter else \
					(SPARK_COLOR_BODY if info.zone == MoveData.Zone.BODY else SPARK_COLOR_HIT)
			_burst(point, -d.facing, strength, color)
			_ring(point, 30.0 + strength * 60.0, color)
			_track_combo(info.attacker)
			# Los carteles del jugador en dorado/blanco; los del rival en rojo.
			var mine: bool = info.attacker == _player
			var big: Color = SPARK_COLOR_COUNTER if mine else Color(1.0, 0.4, 0.3)
			if info.counter:
				popup(tr("FX_COUNTER"), point + Vector2(0, -60), big, 40)
			elif info.charge_ratio >= 0.8:
				popup(tr("FX_CHARGED"), point + Vector2(0, -60), Color(1.0, 0.5, 0.2) if mine else big, 40)
			elif info.move.is_power_punch and info.range_mult >= 0.99 and info.momentum_mult >= 1.12:
				popup(tr("FX_CLEAN"), point + Vector2(0, -60), Color(1, 1, 1) if mine else big, 34)
			elif mine:
				# Calificaciones chicas que ENSEÑAN la capa estratégica (solo para los golpes del jugador).
				if info.range_mult < 0.6:
					popup(tr("FX_JAMMED"), point + Vector2(0, -50), Color(0.65, 0.65, 0.7), 22)
				elif info.momentum_mult >= 1.15:
					popup(tr("FX_MOMENTUM"), point + Vector2(0, -50), Color(0.95, 0.95, 1.0), 22)
			if strength >= 0.9:
				flash(0.18)
		HitInfo.Result.BLOCKED:
			_burst(point, -d.facing, strength * 0.5, SPARK_COLOR_BLOCK)
			if info.guard_broken:
				_ring(point, 110.0, Color(0.75, 0.4, 1.0))
				popup(tr("FX_GUARD_BREAK"), point + Vector2(0, -70), Color(0.8, 0.55, 1.0), 38)
			_reset_combo_if(d)
		HitInfo.Result.DODGED:
			popup(tr("FX_DODGE"), Vector2(d.position.x, -h - 30.0), Color(0.6, 1.0, 0.8), 30)
	# Recibir corta el combo del que recibe.
	if info.result == HitInfo.Result.HIT:
		_reset_combo_if(d)


## CombatScene: alguien cayó a la lona.
func on_knockdown(f: Fighter) -> void:
	for i in 18:
		var p := Particle.new()
		p.pos = Vector2(f.position.x + _rng.randf_range(-90.0, 90.0), -4.0)
		p.vel = Vector2(_rng.randf_range(-140.0, 140.0), _rng.randf_range(-170.0, -40.0))
		p.max_life = _rng.randf_range(0.5, 0.9)
		p.life = p.max_life
		p.color = Color(0.85, 0.85, 0.9, 0.7)
		p.size = _rng.randf_range(8.0, 18.0)
		p.kind = 2
		_particles.append(p)
	_ring(Vector2(f.position.x, -10.0), 180.0, Color(1, 1, 1, 0.8))
	flash(0.35)
	_combo = 0


## Destello de pantalla completa (0–1).
func flash(intensity: float) -> void:
	_flash_rect.color.a = maxf(_flash_rect.color.a, intensity)


func popup(text: String, pos: Vector2, color: Color, font_size: int) -> void:
	var p := FloatText.new()
	p.text = text
	p.pos = pos
	p.max_life = 0.9
	p.life = p.max_life
	p.color = color
	p.font_size = font_size
	_popups.append(p)


func _track_combo(attacker: Fighter) -> void:
	if attacker != _combo_owner:
		_combo_owner = attacker
		_combo = 0
	_combo += 1
	if _combo >= COMBO_MIN:
		var pos := Vector2(attacker.position.x, -attacker.setup.body_height - 70.0)
		popup(tr("FX_COMBO").format({"n": _combo}), pos, Color(1.0, 0.85, 0.3), 30 + mini(_combo, 8) * 3)


func _reset_combo_if(f: Fighter) -> void:
	if f == _combo_owner:
		_combo = 0


## Chispas que salen del punto de impacto hacia `dir` (−1 izquierda, +1 derecha).
func _burst(point: Vector2, dir: int, strength: float, color: Color) -> void:
	var count: int = 6 + roundi(strength * 14.0)
	for i in count:
		var p := Particle.new()
		p.pos = point
		var angle: float = _rng.randf_range(-0.9, 0.9) + (0.0 if dir > 0 else PI)
		var speed: float = _rng.randf_range(250.0, 650.0) * (0.6 + strength * 0.6)
		p.vel = Vector2.from_angle(angle) * speed
		p.max_life = _rng.randf_range(0.12, 0.28) * (0.8 + strength * 0.4)
		p.life = p.max_life
		p.color = color
		p.size = _rng.randf_range(2.0, 4.5) * (0.8 + strength * 0.5)
		p.kind = 0
		_particles.append(p)


func _ring(point: Vector2, radius: float, color: Color) -> void:
	var p := Particle.new()
	p.pos = point
	p.vel = Vector2.ZERO
	p.max_life = 0.22
	p.life = p.max_life
	p.color = color
	p.size = radius
	p.kind = 1
	_particles.append(p)


func _process(delta: float) -> void:
	_time += delta
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 1.0 - minf(1.0, 6.0 * delta)
		if p.kind == 2:
			p.vel.y += 300.0 * delta
	_particles = _particles.filter(func(p: Particle) -> bool: return p.life > 0.0)
	for p in _popups:
		p.life -= delta
		p.pos.y -= 60.0 * delta
	_popups = _popups.filter(func(p: FloatText) -> bool: return p.life > 0.0)
	if _flash_rect.color.a > 0.0:
		_flash_rect.color.a = maxf(0.0, _flash_rect.color.a - 2.5 * delta)
	queue_redraw()


func _draw() -> void:
	_draw_sweet_spot_marker()
	for f in [_player, _rival]:
		if f != null:
			_draw_telegraph(f)
	for p in _particles:
		var t: float = p.life / p.max_life
		var c: Color = p.color
		c.a *= t
		match p.kind:
			0:
				draw_line(p.pos, p.pos - p.vel * 0.035, c, p.size, true)
			1:
				draw_arc(p.pos, p.size * (1.0 - t * 0.7), 0.0, TAU, 32, c, 6.0 * t + 1.0, true)
			2:
				draw_circle(p.pos, p.size * (1.4 - t * 0.4), c)
	var font: Font = UIStyle.font()
	for p in _popups:
		var t: float = p.life / p.max_life
		# Entra grande y se asienta; se desvanece al final.
		var scale_in: float = 1.0 + 0.6 * clampf((t - 0.8) / 0.2, 0.0, 1.0)
		var size: int = roundi(p.font_size * scale_in)
		var c: Color = p.color
		c.a = clampf(t * 2.0, 0.0, 1.0)
		var width: float = 600.0
		var pos := Vector2(p.pos.x - width * 0.5, p.pos.y)
		draw_string_outline(font, pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 10, Color(0, 0, 0, c.a))
		draw_string(font, pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, width, size, c)


## Marca en el piso, bajo los pies del rival, cuando está en la distancia justa de un golpe del jugador:
## blanca = zona del jab, naranja = zona del fuerte. Enseña a pelear a la distancia correcta.
func _draw_sweet_spot_marker() -> void:
	if _player == null or _rival == null or _player.setup == null or _player.is_down() or _rival.is_down():
		return
	var gap: float = DistanceHitResolver.edge_gap(_player, _rival)
	var jab: MoveData = _player.setup.jab
	var power: MoveData = _player.setup.power_punch
	var color := Color(0, 0, 0, 0)
	if gap >= power.sweet_gap_min and gap <= power.sweet_gap_max:
		color = Color(1.0, 0.6, 0.2, 0.55)
	elif gap >= jab.sweet_gap_min and gap <= jab.sweet_gap_max:
		color = Color(1.0, 1.0, 1.0, 0.45)
	if color.a <= 0.0:
		return
	var pulse: float = 1.0 + 0.08 * sin(_time * 8.0)
	draw_set_transform(Vector2(_rival.position.x, 2.0), 0.0, Vector2(1.0, 0.22))
	draw_arc(Vector2.ZERO, 70.0 * pulse, 0.0, TAU, 40, color, 7.0, true)
	draw_set_transform(Vector2.ZERO)


## Aviso de golpe fuerte: un destello en el guante al empezar el arranque (y mientras carga).
## Amarillo = a la cabeza, violeta = al cuerpo. Le da al que defiende tiempo de leerlo.
func _draw_telegraph(f: Fighter) -> void:
	if f.state != Fighter.State.ATTACKING or f.current_move == null or not f.current_move.is_power_punch:
		return
	if f.attack_phase != Fighter.AttackPhase.STARTUP:
		return
	var early: bool = f.attack_tick <= 7
	if not early and not f.charging:
		return
	var h: float = f.setup.body_height
	var body: bool = f.current_move.zone == MoveData.Zone.BODY
	var color: Color = Color(0.8, 0.45, 1.0) if body else Color(1.0, 0.92, 0.4)
	var center := Vector2(f.position.x - f.facing * f.half_width() * 0.2, -h * (0.62 if body else 0.86))
	var t: float = 1.0 - float(f.attack_tick) / 8.0 if early else 0.6 + 0.4 * sin(_time * 18.0)
	var r: float = 18.0 + 22.0 * t
	color.a = 0.85
	# Estrella de 4 puntas.
	var pts := PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(r * 0.22, -r * 0.22), center + Vector2(r, 0),
		center + Vector2(r * 0.22, r * 0.22), center + Vector2(0, r), center + Vector2(-r * 0.22, r * 0.22),
		center + Vector2(-r, 0), center + Vector2(-r * 0.22, -r * 0.22)])
	draw_colored_polygon(pts, color)
	draw_circle(center, r * 0.25, Color(1, 1, 1, 0.9))
