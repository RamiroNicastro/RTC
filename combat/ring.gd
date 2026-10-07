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


# --- Placeholder visual ---

func _draw() -> void:
	var half: float = half_width()
	var stage: float = stage_half_width()

	# Fondo del estadio (alto de sobra para tablets 4:3).
	draw_rect(Rect2(-stage - 400.0, -1100.0, (stage + 400.0) * 2.0, 1700.0), Color(0.08, 0.08, 0.11))
	# Público: filas de cabezas que llegan hasta los bordes del escenario.
	for row in 4:
		var y: float = -420.0 - row * 70.0
		var x: float = -stage + 30.0 + (row % 2) * 30.0
		while x < stage:
			var shade: float = 0.18 + 0.05 * float((int(x) / 60 + row) % 3)
			draw_circle(Vector2(x, y), 22.0, Color(shade, shade, shade + 0.04))
			x += 60.0
	# Piso del estadio.
	draw_rect(Rect2(-stage - 400.0, 60.0, (stage + 400.0) * 2.0, 600.0), Color(0.12, 0.12, 0.14))
	# Lona y faldón del ring.
	draw_rect(Rect2(-half - 60.0, 0.0, ring_width + 120.0, 24.0), Color(0.55, 0.6, 0.7))
	draw_rect(Rect2(-half - 60.0, 24.0, ring_width + 120.0, 70.0), Color(0.15, 0.22, 0.45))
	# Postes.
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(side * half - 12.0, -300.0, 24.0, 300.0), Color(0.75, 0.75, 0.78))
	# Cuerdas (detrás de los peleadores porque Ring se dibuja primero).
	for rope_y in [-110.0, -185.0, -260.0]:
		draw_line(Vector2(-half, rope_y), Vector2(half, rope_y), Color(0.85, 0.2, 0.2, 0.8), 6.0)
