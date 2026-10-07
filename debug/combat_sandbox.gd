extends Node
## Sandbox de combate: arma un FightSetup de prueba y lanza el combate sin carrera ni autoloads.
##
## Controles:
##   ← / → o A / D  moverse
##   J              jab
##   K              golpe fuerte
##   L (mantener)   guardia
##   ESPACIO        esquive (solo protege la cabeza)
##   S / ↓          mantener para pegar al cuerpo (S + J = jab al cuerpo, S + K = fuerte al cuerpo)
##   1 / 2 / 4      el rival tira un jab / un fuerte / un jab al cuerpo
##   3              cambiar el modo del rival (quieto, bloquea, jab, fuerte, bloquea y jab, esquiva, cuerpo)
##   F1             cambiar el límite de FPS (sin límite → 30 → 144) para probar que la lógica no depende de los FPS
##   F2             mostrar u ocultar los rangos de golpe
##   F3             mostrar u ocultar los botones táctiles (en la PC se usan con el mouse)
##
## En el celular no hay teclado: arriba al centro hay botones para cambiar el modo del rival,
## mostrar u ocultar el debug y reiniciar.
##   R              reiniciar la escena

const COMBAT_SCENE: PackedScene = preload("res://combat/combat_scene.tscn")
const FPS_CAPS: Array[int] = [0, 30, 144]

var _fps_cap_index: int = 0
var _combat: CombatScene
var _debug_draw: CombatDebugDraw
var _overlay: CombatDebugOverlay
var _mode_button: Button


func _ready() -> void:
	_combat = COMBAT_SCENE.instantiate()
	add_child(_combat)
	_combat.start(_make_default_setup())

	_debug_draw = CombatDebugDraw.new()
	_combat.add_child(_debug_draw)
	_debug_draw.attach(_combat.fighter_a, _combat.fighter_b)

	_overlay = CombatDebugOverlay.new()
	add_child(_overlay)
	_overlay.attach(_combat)
	# En el celular el overlay tapa mucho: arranca oculto (se muestra con el botón "Debug").
	_overlay.visible = not DisplayServer.is_touchscreen_available()
	_build_touch_debug_buttons()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F1:
			_cycle_fps_cap()
		KEY_F2:
			_debug_draw.visible = not _debug_draw.visible
		KEY_F3:
			_combat.touch_controls.visible = not _combat.touch_controls.visible
		KEY_1, KEY_2, KEY_3, KEY_4:
			var dummy := _combat.controller_b as DummyInput
			if dummy == null:
				return
			match key.physical_keycode:
				KEY_1:
					dummy.queue_jab()
				KEY_2:
					dummy.queue_power()
				KEY_3:
					_cycle_dummy_mode()
				KEY_4:
					dummy.queue_body_jab()
		KEY_R:
			get_tree().reload_current_scene()


func _cycle_dummy_mode() -> void:
	var dummy := _combat.controller_b as DummyInput
	if dummy == null:
		return
	dummy.cycle_mode()
	_mode_button.text = "Rival: " + dummy.mode_name()


func _build_touch_debug_buttons() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	row.position.y = 100.0
	layer.add_child(row)

	_mode_button = _small_button(row, "Rival: QUIETO", _cycle_dummy_mode)
	_small_button(row, "Debug", func() -> void:
		_overlay.visible = not _overlay.visible
		_debug_draw.visible = _overlay.visible)
	_small_button(row, "Reiniciar", func() -> void: get_tree().reload_current_scene())
	# Centrar la fila después de que calcule su tamaño.
	row.resized.connect(func() -> void: row.position.x = (get_viewport().get_visible_rect().size.x - row.size.x) * 0.5)


func _small_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150, 56)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


func _cycle_fps_cap() -> void:
	_fps_cap_index = (_fps_cap_index + 1) % FPS_CAPS.size()
	var cap: int = FPS_CAPS[_fps_cap_index]
	# Con V-Sync activado no se puede pasar la frecuencia del monitor; para probar 144 se desactiva.
	if cap == 0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = cap


func _make_default_setup() -> FightSetup:
	var player := FighterSetup.new()
	player.display_name = "Jugador"
	player.controller_type = FighterSetup.ControllerType.PLAYER
	player.color = Color(0.2, 0.55, 0.9)

	var dummy := FighterSetup.new()
	dummy.display_name = "Rival (quieto)"
	dummy.controller_type = FighterSetup.ControllerType.DUMMY
	dummy.color = Color(0.85, 0.55, 0.15)

	var fight := FightSetup.new()
	fight.fighter_a = player
	fight.fighter_b = dummy
	return fight
