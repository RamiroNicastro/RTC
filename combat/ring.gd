class_name Ring
extends Node2D
## El ring: cuerdas, piso y escenario (placeholder), más las reglas de espacio.
##
## Las cuerdas limitan el movimiento, no los bordes de la pantalla: el espacio jugable
## es el mismo en 16:9, 19.5:9 y 20:9. En pantallas más anchas solo se ve más escenario.
## El piso está en y = 0.

## Ancho extra de escenario (público) a cada lado de las cuerdas.
const STAGE_MARGIN: float = 550.0

var ring_width: float = 1500.0


func configure(width: float) -> void:
	ring_width = width
	queue_redraw()


func half_width() -> float:
	return ring_width * 0.5


## Mitad del ancho total visible del escenario. La cámara no se va más allá.
func stage_half_width() -> float:
	return half_width() + STAGE_MARGIN


## Se llama después de mover a los dos peleadores en el tick.
## a = peleador izquierdo, b = peleador derecho. Nunca se cruzan.
func resolve_positions(a: Fighter, b: Fighter) -> void:
	_clamp_to_ropes(a)
	_clamp_to_ropes(b)

	var min_gap: float = a.half_width() + b.half_width()
	var overlap: float = min_gap - (b.position.x - a.position.x)
	if overlap <= 0.0:
		return

	# El que avanzó hacia el otro es el que se frena. No se empujan entre ellos.
	var a_advance: float = maxf(0.0, a.position.x - a.previous_x)
	var b_advance: float = maxf(0.0, b.previous_x - b.position.x)
	var total: float = a_advance + b_advance
	if total > 0.0:
		a.position.x -= overlap * (a_advance / total)
		b.position.x += overlap * (b_advance / total)
	else:
		a.position.x -= overlap * 0.5
		b.position.x += overlap * 0.5

	_clamp_to_ropes(a)
	_clamp_to_ropes(b)


func _clamp_to_ropes(f: Fighter) -> void:
	var limit: float = half_width() - f.half_width()
	f.position.x = clampf(f.position.x, -limit, limit)


# --- Placeholder visual (escenario arcade). La lógica no depende de nada de esto. ---

## Excitación del público (0–1): sube con los golpes y baja sola. Solo visual.
var crowd_excitement: float = 0.15
var _time: float = 0.0
var _flashes: Array[Vector3] = []  # x, y, vida (flashes de cámaras del público)
var _rng := RandomNumberGenerator.new()


## CombatScene: el público reacciona (0.2 = golpe, 0.6 = fuerte, 1.0 = knockdown).
func excite(amount: float) -> void:
	crowd_excitement = clampf(crowd_excitement + amount, 0.0, 1.0)
	var flashes: int = roundi(amount * 10.0)
	for i in flashes:
		_flashes.append(Vector3(_rng.randf_range(-stage_half_width(), stage_half_width()),
				_rng.randf_range(-640.0, -380.0), _rng.randf_range(0.08, 0.2)))


func _process(delta: float) -> void:
	_time += delta
	crowd_excitement = maxf(0.12, crowd_excitement - 0.25 * delta)
	for i in range(_flashes.size() - 1, -1, -1):
		_flashes[i].z -= delta
		if _flashes[i].z <= 0.0:
			_flashes.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var half: float = half_width()
	var stage: float = stage_half_width()
	var wide: float = stage + 500.0

	# Fondo del estadio: degradé oscuro (arriba casi negro).
	var top := Color(0.03, 0.03, 0.06)
	var mid := Color(0.1, 0.09, 0.14)
	draw_polygon(PackedVector2Array([Vector2(-wide, -1200), Vector2(wide, -1200), Vector2(wide, 60), Vector2(-wide, 60)]),
			PackedColorArray([top, top, mid, mid]))

	_draw_crowd(stage)

	# Focos de luz cayendo sobre el ring.
	for side in [-1.0, 1.0]:
		var light := Color(1.0, 0.95, 0.8, 0.07)
		var clear := Color(1.0, 0.95, 0.8, 0.0)
		# Haz de luz: angosto arriba (el foco) y ancho abajo (sobre la lona). Puntos en orden horario.
		var bottom_a: float = side * 60.0 - 260.0 * side
		var bottom_b: float = side * 60.0 + 520.0 * side
		draw_polygon(PackedVector2Array([
				Vector2(side * 260.0 - 40.0, -1100.0), Vector2(side * 260.0 + 40.0, -1100.0),
				Vector2(maxf(bottom_a, bottom_b), 20.0), Vector2(minf(bottom_a, bottom_b), 20.0)]),
				PackedColorArray([light, light, clear, clear]))

	# Piso del estadio.
	draw_rect(Rect2(-wide, 60.0, wide * 2.0, 700.0), Color(0.07, 0.07, 0.09))
	# Lona (con una zona más clara bajo los focos) y faldón con el nombre del juego.
	draw_rect(Rect2(-half - 60.0, 0.0, ring_width + 120.0, 26.0), Color(0.62, 0.66, 0.74))
	draw_rect(Rect2(-half * 0.6, 0.0, half * 1.2, 26.0), Color(0.72, 0.76, 0.84))
	draw_rect(Rect2(-half - 60.0, 26.0, ring_width + 120.0, 80.0), Color(0.12, 0.18, 0.4))
	draw_rect(Rect2(-half - 60.0, 26.0, ring_width + 120.0, 5.0), Color(0.9, 0.75, 0.25))
	var font: Font = UIStyle.font()
	draw_string(font, Vector2(-half, 88.0), tr("GAME_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, ring_width, 46,
			Color(1.0, 0.85, 0.3, 0.85))

	# Postes con esquineros (azul a la izquierda, rojo a la derecha).
	for side in [-1.0, 1.0]:
		var x: float = side * half
		draw_rect(Rect2(x - 13.0, -300.0, 26.0, 300.0), Color(0.78, 0.78, 0.82))
		var pad: Color = Color(0.2, 0.4, 0.95) if side < 0.0 else Color(0.9, 0.2, 0.2)
		draw_rect(Rect2(x - 18.0, -275.0, 36.0, 190.0), pad)
	# Cuerdas (rojo, blanco y azul), con una leve curva hacia abajo.
	var rope_colors: Array[Color] = [Color(0.9, 0.2, 0.2), Color(0.95, 0.95, 0.95), Color(0.2, 0.4, 0.95)]
	var rope_heights: Array[float] = [-260.0, -185.0, -110.0]
	for i in 3:
		var pts := PackedVector2Array()
		for k in 17:
			var t: float = k / 16.0
			var x: float = lerpf(-half, half, t)
			pts.append(Vector2(x, rope_heights[i] + sin(t * PI) * 8.0))
		draw_polyline(pts, rope_colors[i].darkened(0.1), 7.0, true)


## Público: filas de siluetas (cabeza + hombros) que se mueven más cuanto más excitado está.
func _draw_crowd(stage: float) -> void:
	var palette: Array[Color] = [Color(0.2, 0.19, 0.24), Color(0.25, 0.22, 0.27), Color(0.17, 0.2, 0.25), Color(0.28, 0.24, 0.22)]
	for row in 5:
		var y: float = -380.0 - row * 62.0
		var spacing: float = 58.0
		var x: float = -stage - 60.0 + (row % 2) * spacing * 0.5
		var shade: float = 1.0 - row * 0.12
		var i: int = 0
		while x < stage + 60.0:
			var seed: float = float(i * 31 + row * 17)
			var bob: float = sin(_time * (2.0 + crowd_excitement * 9.0) + seed) * (2.0 + crowd_excitement * 16.0)
			var jump: float = maxf(0.0, sin(_time * 7.0 + seed * 0.7)) * crowd_excitement * crowd_excitement * 22.0
			var c: Color = palette[int(seed) % palette.size()] * shade
			c.a = 1.0
			var cy: float = y - bob - jump
			draw_rect(Rect2(x - 22.0, cy + 12.0, 44.0, 40.0), c)
			draw_circle(Vector2(x, cy), 16.0, c.lightened(0.08))
			# Con mucha excitación, algunos levantan los brazos.
			if crowd_excitement > 0.55 and int(seed) % 3 == 0:
				draw_line(Vector2(x - 20.0, cy + 16.0), Vector2(x - 30.0, cy - 22.0 - jump), c, 7.0)
				draw_line(Vector2(x + 20.0, cy + 16.0), Vector2(x + 30.0, cy - 22.0 - jump), c, 7.0)
			x += spacing
			i += 1
	for f in _flashes:
		draw_circle(Vector2(f.x, f.y), 10.0 + f.z * 40.0, Color(1, 1, 1, clampf(f.z * 6.0, 0.0, 0.9)))
