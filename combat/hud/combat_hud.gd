class_name CombatHUD
extends CanvasLayer
## HUD del combate (placeholder): barras de salud y de stamina de los dos peleadores.
##
## Solo LEE el estado de los Fighters; nunca lo modifica.
## La parte clara de la barra de salud muestra el daño reciente y baja con retraso (es solo visual).
## La barra de stamina se pone naranja cuando el peleador está cansado.
## El tramo gris del final es la FATIGA: stamina que no se puede recuperar hasta el descanso.
## En el Hito I se ancla a la safe area.

const BAR_SIZE := Vector2(460.0, 26.0)
const STAMINA_BAR_HEIGHT: float = 10.0
const MARGIN := Vector2(28.0, 24.0)
## Velocidad (fracción de barra por segundo) con la que baja la marca del daño reciente.
const TRAIL_SPEED: float = 0.6

const COLOR_STAMINA := Color(0.3, 0.85, 0.4)
const COLOR_STAMINA_TIRED := Color(1.0, 0.55, 0.1)
const COLOR_FATIGUE := Color(0.45, 0.45, 0.48)

var _a: Fighter
var _b: Fighter
var _trail_a: float = 1.0
var _trail_b: float = 1.0
var _canvas: Control


func setup(a: Fighter, b: Fighter) -> void:
	_a = a
	_b = b


func _ready() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_canvas_draw)
	add_child(_canvas)


# La animación de la barra es puramente visual: puede usar delta.
func _process(delta: float) -> void:
	if _a == null:
		return
	_trail_a = _approach_trail(_trail_a, _health_ratio(_a), delta)
	_trail_b = _approach_trail(_trail_b, _health_ratio(_b), delta)
	_canvas.queue_redraw()


func _approach_trail(trail: float, real: float, delta: float) -> float:
	if real >= trail:
		return real
	return maxf(real, trail - TRAIL_SPEED * delta)


func _health_ratio(f: Fighter) -> float:
	return float(f.health) / float(f.max_health)


func _on_canvas_draw() -> void:
	if _a == null:
		return
	var width: float = _canvas.size.x
	_draw_fighter_bars(Vector2(MARGIN.x, MARGIN.y), _a, _trail_a, false)
	_draw_fighter_bars(Vector2(width - MARGIN.x - BAR_SIZE.x, MARGIN.y), _b, _trail_b, true)


## mirrored = true: las barras se vacían hacia la derecha (lado del rival).
func _draw_fighter_bars(pos: Vector2, f: Fighter, trail: float, mirrored: bool) -> void:
	# Salud.
	_canvas.draw_rect(Rect2(pos - Vector2(3, 3), BAR_SIZE + Vector2(6, 6)), Color(0, 0, 0, 0.7))
	_canvas.draw_rect(Rect2(pos, BAR_SIZE), Color(0.25, 0.05, 0.05))
	_canvas.draw_rect(_fill_rect(pos, BAR_SIZE, trail, mirrored), Color(1.0, 0.85, 0.6))
	_canvas.draw_rect(_fill_rect(pos, BAR_SIZE, _health_ratio(f), mirrored), Color(0.9, 0.2, 0.15))

	# Stamina.
	var st_pos := Vector2(pos.x, pos.y + BAR_SIZE.y + 6.0)
	var st_size := Vector2(BAR_SIZE.x, STAMINA_BAR_HEIGHT)
	_canvas.draw_rect(Rect2(st_pos - Vector2(2, 2), st_size + Vector2(4, 4)), Color(0, 0, 0, 0.7))
	_canvas.draw_rect(Rect2(st_pos, st_size), Color(0.08, 0.15, 0.08))
	var st_color: Color = COLOR_STAMINA_TIRED if f.is_tired() else COLOR_STAMINA
	_canvas.draw_rect(_fill_rect(st_pos, st_size, f.stamina / f.base_max_stamina, mirrored), st_color)
	if f.fatigue > 0.0:
		var fatigue_ratio: float = f.fatigue / f.base_max_stamina
		var fatigue_width: float = st_size.x * fatigue_ratio
		var fx: float = st_pos.x if mirrored else st_pos.x + st_size.x - fatigue_width
		_canvas.draw_rect(Rect2(Vector2(fx, st_pos.y), Vector2(fatigue_width, st_size.y)), COLOR_FATIGUE)

	# Nombre.
	var font: Font = ThemeDB.fallback_font
	var name_pos := Vector2(pos.x, st_pos.y + STAMINA_BAR_HEIGHT + 22.0)
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	_canvas.draw_string_outline(font, name_pos, f.setup.display_name, align, BAR_SIZE.x, 18, 5, Color.BLACK)
	_canvas.draw_string(font, name_pos, f.setup.display_name, align, BAR_SIZE.x, 18, Color.WHITE)


func _fill_rect(pos: Vector2, size: Vector2, ratio: float, mirrored: bool) -> Rect2:
	var fill_width: float = size.x * clampf(ratio, 0.0, 1.0)
	var x: float = pos.x + (size.x - fill_width if mirrored else 0.0)
	return Rect2(Vector2(x, pos.y), Vector2(fill_width, size.y))
