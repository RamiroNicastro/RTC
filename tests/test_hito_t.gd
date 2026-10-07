extends SceneTree
# Prueba automática del Hito T: los botones táctiles disparan las mismas acciones que el teclado,
# con multitouch (mantener la guardia con un dedo y pegar con otro) y sin superponerse en 16:9 ni en 20:9.

var combat: CombatScene
var step: int = 0
var failures: PackedStringArray = []


func _initialize() -> void:
	combat = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func touch(index: int, button: TouchScreenButton, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	var radius: float = (button.shape as CircleShape2D).radius
	ev.position = button.position + Vector2.ONE * radius
	# Directo al viewport y en coordenadas locales (en headless la cola de Input no se procesa
	# y la ventana falsa tiene otra escala).
	root.push_input(ev, true)


func drag(index: int, button: TouchScreenButton, offset: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	var radius: float = (button.shape as CircleShape2D).radius
	ev.position = button.position + Vector2.ONE * radius + offset
	root.push_input(ev, true)


func _physics_process(_delta: float) -> bool:
	step += 1
	var tc: TouchControls = combat.touch_controls
	var a: Fighter = combat.fighter_a
	match step:
		1:
			var s := FightSetup.new()
			s.start_with_intro = false
			s.game_feel = false
			s.fighter_a = FighterSetup.new()
			s.fighter_a.controller_type = FighterSetup.ControllerType.PLAYER
			s.fighter_b = FighterSetup.new()
			s.start_distance = 140.0
			combat.start(s)
			tc.visible = true
			check_layout(tc, Vector2(1280, 720))
			check_layout(tc, Vector2(1600, 720))
			tc.left_handed = true
			check_layout(tc, Vector2(1280, 720))
			tc.left_handed = false
		3:
			touch(0, tc._guard, true)   # dedo 1: mantiene la guardia
		8:
			check(a.state == Fighter.State.BLOCKING, "tocar GUARDIA debería poner la guardia")
			print("Dedo 1 en GUARDIA → estado %s" % Fighter.State.keys()[a.state])
			touch(1, tc._jab, true)     # dedo 2: jab sin soltar la guardia
		9:
			touch(1, tc._jab, false)
		11:
			print("Dedo 2 en JAB (con la guardia apretada) → estado %s" % Fighter.State.keys()[a.state])
			check(a.state == Fighter.State.ATTACKING and a.current_move.id == &"jab", "el jab debería salir con multitouch")
		40:
			check(a.state == Fighter.State.BLOCKING, "al terminar el jab, si sigue apretada, vuelve a la guardia")
			touch(0, tc._guard, false)
			touch(2, tc._power, true)
		41:
			touch(2, tc._power, false)
		43:
			check(a.state == Fighter.State.ATTACKING and a.current_move.id == &"fuerte", "FUERTE debería tirar el golpe fuerte")
		90:
			var x0: float = a.position.x
			touch(3, tc._left, true)
			set_meta("x0", x0)
		120:
			touch(3, tc._left, false)
			var moved: float = a.position.x - float(get_meta("x0"))
			print("◀ durante 30 ticks → se movió %.1f" % moved)
			check(moved < -50.0, "◀ debería mover hacia la izquierda")
		125:
			touch(5, tc._jab, true)      # JAB…
		126:
			drag(5, tc._jab, Vector2(0, 60))  # …y deslizar hacia abajo = jab al cuerpo
		129:
			touch(5, tc._jab, false)
			var id: StringName = a.current_move.id if a.current_move != null else &"-"
			print("JAB deslizando hacia abajo → golpe %s" % id)
			check(id == &"jab_cuerpo", "deslizar hacia abajo sobre JAB debería pegar al cuerpo")
			print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
			quit()
	return false


func check_layout(tc: TouchControls, view: Vector2) -> void:
	# Recalcula la distribución para ese tamaño de pantalla y verifica que nada se pise ni se salga.
	var buttons: Array[TouchScreenButton] = [tc._left, tc._right, tc._jab, tc._power, tc._guard, tc._dodge]
	var old_size: Vector2i = root.size
	root.size = Vector2i(view)
	tc._layout()
	var actual: Vector2 = root.get_visible_rect().size
	for i in buttons.size():
		var bi := buttons[i]
		var ri: float = (bi.shape as CircleShape2D).radius
		var ci: Vector2 = bi.position + Vector2.ONE * ri
		check(ci.x - ri >= 0.0 and ci.x + ri <= actual.x and ci.y + ri <= actual.y, "botón %s fuera de pantalla en %s" % [bi.action, actual])
		for j in range(i + 1, buttons.size()):
			var bj := buttons[j]
			var rj: float = (bj.shape as CircleShape2D).radius
			var cj: Vector2 = bj.position + Vector2.ONE * rj
			check(ci.distance_to(cj) >= ri + rj, "%s y %s se superponen en %s" % [bi.action, bj.action, actual])
	print("Distribución en %s (zurdo=%s): sin superposiciones ni botones afuera" % [actual, tc.left_handed])
	root.size = old_size
	tc._layout()
