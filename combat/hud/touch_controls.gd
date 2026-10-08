class_name TouchControls
extends CanvasLayer
## Controles táctiles (Hito I): mover, jab, fuerte (mantener = cargar), guardia y esquive.
## Golpe al CUERPO: tocar JAB o FUERTE y deslizar el dedo hacia abajo (decisión de la persona: libera la
## mano izquierda para moverse mientras pega). Se esperan SWIPE_WINDOW_MS para saber si desliza.
##
## Cada botón dispara una acción del Input Map: exactamente las mismas que el teclado.
## Por eso PlayerInput no cambia y se respeta R1.
## TouchScreenButton soporta multitouch: se puede mantener la guardia o el cuerpo mientras se pega.
## Respeta la safe area (notch / cámara perforada): los botones nunca quedan debajo.
##
## Distribución (unidades lógicas; la altura siempre es 720):
##   izquierda abajo:  ◀ ▶
##   derecha abajo:    GUARDIA en la esquina, JAB a su izquierda, FUERTE arriba entre los dos, ESQUIVE arriba de la guardia
## left_handed = true espeja todo (golpes a la izquierda, movimiento a la derecha).

const MOVE_DIAMETER: float = 140.0
const JAB_DIAMETER: float = 150.0
const POWER_DIAMETER: float = 136.0
const GUARD_DIAMETER: float = 160.0
const DODGE_DIAMETER: float = 112.0
## Deslizar hacia abajo: cuánto (unidades) y en qué ventana (ms) para que el golpe salga al cuerpo.
const SWIPE_DOWN_DISTANCE: float = 34.0
const SWIPE_WINDOW_MS: int = 50
## Ticks de física que se mantiene "apretado" un golpe tocado (para que el control lo registre).
const TAP_HOLD_FRAMES: int = 2
const EDGE_MARGIN: float = 36.0

const COLOR_MOVE := Color(0.75, 0.75, 0.8)
const COLOR_JAB := Color(0.95, 0.85, 0.3)
const COLOR_POWER := Color(0.95, 0.35, 0.25)
const COLOR_GUARD := Color(0.35, 0.6, 1.0)
const COLOR_DODGE := Color(0.4, 0.95, 0.7)

## 0–1: opacidad de los botones (configurable más adelante desde opciones).
var opacity: float = 0.6:
	set(value):
		opacity = clampf(value, 0.15, 1.0)
		for b in _buttons:
			b.modulate.a = opacity
## Modo zurdo: espeja la distribución.
var left_handed: bool = false:
	set(value):
		left_handed = value
		if is_inside_tree():
			_layout()

var _buttons: Array[TouchScreenButton] = []
var _left: TouchScreenButton
var _right: TouchScreenButton
var _jab: TouchScreenButton
var _power: TouchScreenButton
var _guard: TouchScreenButton
var _dodge: TouchScreenButton


func _ready() -> void:
	layer = 10
	_left = _make_button("move_left", "◀", MOVE_DIAMETER, COLOR_MOVE, true)
	_right = _make_button("move_right", "▶", MOVE_DIAMETER, COLOR_MOVE, true)
	# JAB y FUERTE no disparan la acción solos: los maneja _input() (para detectar el deslizar hacia abajo).
	_jab = _make_button("", tr("TOUCH_JAB"), JAB_DIAMETER, COLOR_JAB, false, true)
	_power = _make_button("", tr("TOUCH_POWER"), POWER_DIAMETER, COLOR_POWER, false, true)
	_guard = _make_button("guard", tr("TOUCH_GUARD"), GUARD_DIAMETER, COLOR_GUARD, false)
	_dodge = _make_button("dodge", tr("TOUCH_DODGE"), DODGE_DIAMETER, COLOR_DODGE, false)
	get_viewport().size_changed.connect(_layout)
	_layout()


## Rectángulo usable (safe area) en coordenadas del viewport lógico.
func usable_rect() -> Rect2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var full := Rect2(Vector2.ZERO, view)
	if not OS.has_feature("mobile"):
		return full
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return full
	var scale := Vector2(view.x / screen.x, view.y / screen.y)
	return Rect2(Vector2(safe.position) * scale, Vector2(safe.size) * scale)


## Acomoda los botones en las esquinas del área usable (16:9, 20:9, con o sin notch).
func _layout() -> void:
	var area: Rect2 = usable_rect()
	var left_x: float = area.position.x + EDGE_MARGIN
	var right_x: float = area.end.x - EDGE_MARGIN
	var bottom: float = area.end.y - EDGE_MARGIN

	# Bloque de movimiento (relativo a su esquina).
	var move_left_center := Vector2(MOVE_DIAMETER * 0.5, -MOVE_DIAMETER * 0.5)
	var move_right_center := Vector2(MOVE_DIAMETER * 1.5 + 22.0, -MOVE_DIAMETER * 0.5)
	# Bloque de golpes (relativo a su esquina, hacia adentro = x negativa).
	var guard_center := Vector2(-GUARD_DIAMETER * 0.5, -GUARD_DIAMETER * 0.5)
	var jab_center := guard_center + Vector2(-(GUARD_DIAMETER + JAB_DIAMETER) * 0.5 - 20.0, 12.0)
	var power_center := guard_center + Vector2(-112.0, -(GUARD_DIAMETER + POWER_DIAMETER) * 0.5 - 10.0)
	var dodge_center := guard_center + Vector2(14.0, -(GUARD_DIAMETER + DODGE_DIAMETER) * 0.5 - 52.0)

	var move_anchor := Vector2(left_x, bottom)
	var hit_anchor := Vector2(right_x, bottom)
	var flip: float = 1.0
	if left_handed:
		move_anchor = Vector2(right_x, bottom)
		hit_anchor = Vector2(left_x, bottom)
		flip = -1.0
	_place(_left, move_anchor + Vector2(move_left_center.x * flip, move_left_center.y))
	_place(_right, move_anchor + Vector2(move_right_center.x * flip, move_right_center.y))
	_place(_guard, hit_anchor + Vector2(guard_center.x * flip, guard_center.y))
	_place(_jab, hit_anchor + Vector2(jab_center.x * flip, jab_center.y))
	_place(_power, hit_anchor + Vector2(power_center.x * flip, power_center.y))
	_place(_dodge, hit_anchor + Vector2(dodge_center.x * flip, dodge_center.y))
	# Zurdos: ◀ sigue a la izquierda de ▶ aunque el bloque esté espejado.
	if left_handed and _left.position.x > _right.position.x:
		var tmp: Vector2 = _left.position
		_left.position = _right.position
		_right.position = tmp


func _place(button: TouchScreenButton, center: Vector2) -> void:
	var diameter: float = (button.shape as CircleShape2D).radius * 2.0
	button.position = center - Vector2.ONE * diameter * 0.5


## passby = true: se activa al deslizar el dedo encima sin levantarlo (útil para ◀ ▶).
## swipe_hint = true: muestra "▼ cuerpo" (el golpe sale al cuerpo deslizando hacia abajo).
func _make_button(action: StringName, text: String, diameter: float, color: Color, passby: bool,
		swipe_hint: bool = false) -> TouchScreenButton:
	var button := TouchScreenButton.new()
	button.action = action
	button.passby_press = passby
	button.texture_normal = _circle_texture(diameter, color)
	button.texture_pressed = _circle_texture(diameter, color.lightened(0.45))
	var shape := CircleShape2D.new()
	shape.radius = diameter * 0.5
	button.shape = shape
	button.shape_centered = true
	button.modulate.a = opacity

	var label := Label.new()
	label.text = text
	label.size = Vector2.ONE * diameter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UIStyle.font())
	label.add_theme_font_size_override("font_size", 24 if text.length() > 2 else 44)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	button.add_child(label)
	if swipe_hint:
		label.size.y = diameter * 0.8
		var hint := Label.new()
		hint.text = tr("TOUCH_SWIPE_HINT")
		hint.size = Vector2(diameter, 30.0)
		hint.position = Vector2(0.0, diameter * 0.62)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_override("font", UIStyle.font())
		hint.add_theme_font_size_override("font_size", 16)
		hint.add_theme_color_override("font_outline_color", Color.BLACK)
		hint.add_theme_constant_override("outline_size", 4)
		button.add_child(hint)

	add_child(button)
	_buttons.append(button)
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


# --- JAB y FUERTE con "deslizar hacia abajo = al cuerpo" ---

## Un dedo apoyado sobre JAB o FUERTE.
class Press:
	var action: StringName   # "jab" o "power"
	var start: Vector2
	var pos: Vector2
	var start_ms: int
	var fired: bool = false


var _presses: Dictionary = {}          # índice del dedo -> Press
var _release_queue: Array = []         # [acción, frames que faltan]


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			var action: StringName = _hit_action(touch.position)
			if action != &"":
				var p := Press.new()
				p.action = action
				p.start = touch.position
				p.pos = touch.position
				p.start_ms = Time.get_ticks_msec()
				_presses[touch.index] = p
				get_viewport().set_input_as_handled()
		elif _presses.has(touch.index):
			var p: Press = _presses[touch.index]
			if not p.fired:
				_fire(p)
			if p.action == &"power":
				_queue_release(&"power", TAP_HOLD_FRAMES)
			_presses.erase(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag != null and _presses.has(drag.index):
		var p: Press = _presses[drag.index]
		p.pos = drag.position
		if not p.fired and p.pos.y - p.start.y >= SWIPE_DOWN_DISTANCE:
			_fire(p)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	for p: Press in _presses.values():
		if not p.fired and now - p.start_ms >= SWIPE_WINDOW_MS:
			_fire(p)


# Las acciones se sueltan contando ticks de FÍSICA (los mismos que lee PlayerInput), no frames de pantalla:
# en una pantalla de 120 Hz, contar frames soltaba el "cuerpo" antes de que la lógica lo leyera.
func _physics_process(_delta: float) -> void:
	for i in range(_release_queue.size() - 1, -1, -1):
		_release_queue[i][1] -= 1
		if _release_queue[i][1] <= 0:
			Input.action_release(_release_queue[i][0])
			_release_queue.remove_at(i)


## Dispara el golpe: al cuerpo si el dedo bajó lo suficiente.
func _fire(p: Press) -> void:
	p.fired = true
	var body: bool = p.pos.y - p.start.y >= SWIPE_DOWN_DISTANCE
	if body:
		Input.action_press(&"body")
		_queue_release(&"body", TAP_HOLD_FRAMES + 1)
	Input.action_press(p.action)
	# El jab se suelta solo; el fuerte se mantiene mientras el dedo esté apoyado (para cargarlo).
	if p.action == &"jab":
		_queue_release(&"jab", TAP_HOLD_FRAMES)


func _queue_release(action: StringName, frames: int) -> void:
	_release_queue.append([action, frames])


func _hit_action(point: Vector2) -> StringName:
	for pair in [[_jab, &"jab"], [_power, &"power"]]:
		var b: TouchScreenButton = pair[0]
		var r: float = (b.shape as CircleShape2D).radius
		if point.distance_to(b.position + Vector2.ONE * r) <= r:
			return pair[1]
	return &""
