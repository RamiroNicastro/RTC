class_name TouchControls
extends CanvasLayer
## Botones táctiles PROVISORIOS (Hito T).
##
## Cada botón dispara una acción del Input Map ("move_left", "jab", "guard"...): exactamente las mismas
## que el teclado. Por eso PlayerInput no cambia y se respeta R1.
## TouchScreenButton soporta multitouch: se puede mantener la guardia o moverse mientras se pega.
## La versión definitiva (safe area, modo zurdo, opacidad configurable, botón de esquive y cuerpo) llega en el Hito I.
##
## Distribución (en unidades lógicas, la altura siempre es 720):
##   izquierda abajo: ◀ ▶
##   derecha abajo:   GUARDIA (la más grande, en la esquina), JAB a su izquierda, FUERTE arriba entre los dos.

const MOVE_DIAMETER: float = 150.0
const JAB_DIAMETER: float = 150.0
const POWER_DIAMETER: float = 140.0
const GUARD_DIAMETER: float = 170.0
const EDGE_MARGIN: float = 44.0
const OPACITY: float = 0.6

const COLOR_MOVE := Color(0.75, 0.75, 0.8)
const COLOR_JAB := Color(0.95, 0.85, 0.3)
const COLOR_POWER := Color(0.95, 0.35, 0.25)
const COLOR_GUARD := Color(0.35, 0.6, 1.0)

var _left: TouchScreenButton
var _right: TouchScreenButton
var _jab: TouchScreenButton
var _power: TouchScreenButton
var _guard: TouchScreenButton


func _ready() -> void:
	layer = 10
	_left = _make_button("move_left", "◀", MOVE_DIAMETER, COLOR_MOVE, true)
	_right = _make_button("move_right", "▶", MOVE_DIAMETER, COLOR_MOVE, true)
	_jab = _make_button("jab", "JAB", JAB_DIAMETER, COLOR_JAB, false)
	_power = _make_button("power", "FUERTE", POWER_DIAMETER, COLOR_POWER, false)
	_guard = _make_button("guard", "GUARDIA", GUARD_DIAMETER, COLOR_GUARD, false)
	get_viewport().size_changed.connect(_layout)
	_layout()


## Acomoda los botones en las esquinas según el tamaño real de la pantalla (16:9, 20:9, etc.).
func _layout() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var bottom: float = view.y - EDGE_MARGIN

	_place(_left, Vector2(EDGE_MARGIN + MOVE_DIAMETER * 0.5, bottom - MOVE_DIAMETER * 0.5))
	_place(_right, Vector2(EDGE_MARGIN + MOVE_DIAMETER * 1.5 + 24.0, bottom - MOVE_DIAMETER * 0.5))

	var guard_center := Vector2(view.x - EDGE_MARGIN - GUARD_DIAMETER * 0.5, bottom - GUARD_DIAMETER * 0.5)
	_place(_guard, guard_center)
	_place(_jab, guard_center + Vector2(-(GUARD_DIAMETER + JAB_DIAMETER) * 0.5 - 22.0, 10.0))
	_place(_power, guard_center + Vector2(-100.0, -(GUARD_DIAMETER + POWER_DIAMETER) * 0.5 - 14.0))


func _place(button: TouchScreenButton, center: Vector2) -> void:
	var diameter: float = (button.shape as CircleShape2D).radius * 2.0
	button.position = center - Vector2.ONE * diameter * 0.5


## passby = true: se activa al deslizar el dedo encima sin levantarlo (útil para ◀ ▶).
func _make_button(action: StringName, text: String, diameter: float, color: Color, passby: bool) -> TouchScreenButton:
	var button := TouchScreenButton.new()
	button.action = action
	button.passby_press = passby
	button.texture_normal = _circle_texture(diameter, color)
	button.texture_pressed = _circle_texture(diameter, color.lightened(0.45))
	var shape := CircleShape2D.new()
	shape.radius = diameter * 0.5
	button.shape = shape
	button.shape_centered = true
	button.modulate.a = OPACITY

	var label := Label.new()
	label.text = text
	label.size = Vector2.ONE * diameter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26 if text.length() > 2 else 44)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	button.add_child(label)

	add_child(button)
	return button


## Círculo de color con borde, sin archivos de imagen (placeholder).
func _circle_texture(diameter: float, color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.84, 0.86, 0.96, 1.0])
	gradient.colors = PackedColorArray([
		color.darkened(0.2), color.darkened(0.2), color, color, Color(color, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = int(diameter)
	texture.height = int(diameter)
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
