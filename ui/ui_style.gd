class_name UIStyle
extends RefCounted
## Estilo visual común de las pantallas (placeholder arcade): fuente gruesa, botones grandes para el dedo,
## paneles oscuros. Todo construido por código, sin archivos de arte.

const GOLD := Color(1.0, 0.82, 0.25)
const RED := Color(0.92, 0.25, 0.2)
const TEXT := Color(0.95, 0.95, 0.97)
const MUTED := Color(0.7, 0.72, 0.78)
const BG := Color(0.06, 0.06, 0.09)

static var _font: Font


## Fuente gruesa del sistema (Impact / Arial Black…), con la de Godot como respaldo.
static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Impact", "Arial Black", "Roboto Condensed", "Roboto", "sans-serif"])
		f.font_weight = 800
		_font = f
	return _font


static func label(text: String, size: int, color: Color = TEXT, outline: int = 8) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	return l


## Botón grande (mínimo ~1 cm en el celular).
static func button(text: String, on_pressed: Callable, primary: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(380, 84)
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", 34)
	var base: Color = RED if primary else Color(0.22, 0.24, 0.3)
	b.add_theme_stylebox_override("normal", _box(base))
	b.add_theme_stylebox_override("hover", _box(base.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _box(base.darkened(0.2)))
	b.add_theme_stylebox_override("focus", _box(base.lightened(0.15), GOLD))
	b.add_theme_color_override("font_color", TEXT)
	b.pressed.connect(on_pressed)
	# Pequeño "pop" al aparecer: la UI también tiene que sentirse viva.
	b.pivot_offset = b.custom_minimum_size * 0.5
	return b


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.08, 0.96)
	box.set_corner_radius_all(14)
	box.set_border_width_all(3)
	box.border_color = Color(1.0, 0.82, 0.25, 0.5)
	box.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", box)
	return p


static func _box(color: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(12)
	s.set_border_width_all(4 if border.a > 0.0 else 0)
	s.border_color = border
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	s.set_content_margin_all(12)
	return s


## Anima la entrada de un control: escala desde chico con rebote.
static func pop_in(node: Control, delay: float = 0.0) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.6, 0.6)
	node.modulate.a = 0.0
	var t := node.create_tween()
	t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(node, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, 0.2)
