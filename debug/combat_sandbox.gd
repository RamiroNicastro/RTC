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
##   3              cambiar el rival: IA presionador → técnico → contragolpeador → dummy (quieto, bloquea, jab, …) → IA
##   8              dificultad de la IA: fácil → normal → difícil
##   5              el rival se levanta o no después de una caída (para probar el KO)
##   6              dejar al rival con 10 de vida (para probar knockdowns rápido)
##   7              dejar el round en 5 segundos (para probar el descanso y el final)
##   En el piso: apretá J o K repetido para levantarte.
##   F1             cambiar el límite de FPS (sin límite → 30 → 144) para probar que la lógica no depende de los FPS
##   F2             mostrar u ocultar los rangos de golpe
##   F3             mostrar u ocultar los botones táctiles (en la PC se usan con el mouse)
##
## En el celular no hay teclado: arriba al centro hay botones para cambiar el modo del rival,
## mostrar u ocultar el debug y reiniciar.
##   R              reiniciar la escena
##   Esc            volver al menú

const COMBAT_SCENE: PackedScene = preload("res://combat/combat_scene.tscn")
const AI_PROFILES: Array[AIProfile] = [
	preload("res://data/ai_profiles/pressure.tres"),
	preload("res://data/ai_profiles/outboxer.tres"),
	preload("res://data/ai_profiles/counter.tres"),
]
const FPS_CAPS: Array[int] = [0, 30, 144]

var _fps_cap_index: int = 0
var _combat: CombatScene
var _debug_draw: CombatDebugDraw
var _overlay: CombatDebugOverlay
var _mode_button: Button
var _difficulty_button: Button
## Qué estilo de IA tiene el rival (índice en AI_PROFILES).
var _profile_index: int = 0
var _difficulty: AIInput.Difficulty = AIInput.Difficulty.NORMAL


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
	_overlay.visible = not OS.has_feature("mobile")
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
		KEY_8:
			_cycle_difficulty()
		KEY_7:
			_combat.fight.round_ticks_left = mini(_combat.fight.round_ticks_left, CombatTime.seconds_to_ticks(5.0))
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
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
				KEY_5:
					dummy.getup_enabled = not dummy.getup_enabled
				KEY_6:
					if not _combat.fighter_b.is_down():
						_combat.fighter_b.health = mini(_combat.fighter_b.health, 10)
		KEY_R:
			get_tree().reload_current_scene()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://ui/title/title_screen.tscn")


## Rota el rival: los tres estilos de IA y después los modos del dummy de práctica.
func _cycle_dummy_mode() -> void:
	var dummy := _combat.controller_b as DummyInput
	if dummy == null:
		_profile_index += 1
		if _profile_index >= AI_PROFILES.size():
			_combat.controller_b = DummyInput.new()
		else:
			_set_ai(_profile_index)
	elif dummy.mode == DummyInput.Mode.size() - 1:
		_set_ai(0)
	else:
		dummy.cycle_mode()
	_update_buttons()


func _cycle_difficulty() -> void:
	_difficulty = ((_difficulty + 1) % AIInput.Difficulty.size()) as AIInput.Difficulty
	if _combat.controller_b is AIInput:
		_set_ai(_profile_index)
	_update_buttons()


func _set_ai(index: int) -> void:
	_profile_index = index
	var ai := AIInput.new()
	ai.configure(AI_PROFILES[index], 0, _difficulty)
	_combat.controller_b = ai
	_combat.fighter_b.setup.display_name = "Rival (%s)" % tr(AI_PROFILES[index].style_name_key)


func _update_buttons() -> void:
	var dummy := _combat.controller_b as DummyInput
	_mode_button.text = "Rival: " + (dummy.mode_name() if dummy != null else tr(AI_PROFILES[_profile_index].style_name_key))
	_difficulty_button.text = tr("AI_DIFFICULTY_" + AIInput.Difficulty.keys()[_difficulty])


func _build_touch_debug_buttons() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	row.position.y = 100.0
	layer.add_child(row)

	_mode_button = _small_button(row, "Rival", _cycle_dummy_mode)
	_difficulty_button = _small_button(row, "Normal", _cycle_difficulty)
	_small_button(row, "Debug", func() -> void:
		_overlay.visible = not _overlay.visible
		_debug_draw.visible = _overlay.visible)
	_small_button(row, "Reiniciar", func() -> void: get_tree().reload_current_scene())
	_update_buttons()
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
	dummy.display_name = "Rival (%s)" % tr(AI_PROFILES[0].style_name_key)
	dummy.controller_type = FighterSetup.ControllerType.AI
	dummy.ai_profile = AI_PROFILES[0]
	dummy.color = Color(0.85, 0.55, 0.15)

	var fight := FightSetup.new()
	fight.fighter_a = player
	fight.fighter_b = dummy
	return fight
