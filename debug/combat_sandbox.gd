extends Node
## Sandbox de combate: arma un FightSetup de prueba y lanza el combate sin carrera ni autoloads.
##
## Controles:
##   ← / → o A / D  moverse
##   F1             cambiar el límite de FPS (sin límite → 30 → 144) para probar que la lógica no depende de los FPS
##   R              reiniciar la escena

const COMBAT_SCENE: PackedScene = preload("res://combat/combat_scene.tscn")
const FPS_CAPS: Array[int] = [0, 30, 144]

var _fps_cap_index: int = 0


func _ready() -> void:
	var combat: CombatScene = COMBAT_SCENE.instantiate()
	add_child(combat)
	combat.start(_make_default_setup())

	var overlay := CombatDebugOverlay.new()
	add_child(overlay)
	overlay.attach(combat)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F1:
			_cycle_fps_cap()
		KEY_R:
			get_tree().reload_current_scene()


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
