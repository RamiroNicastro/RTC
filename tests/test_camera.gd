extends SceneTree
# Prueba automática del encuadre: nadie se corta, zoom acotado, peleador entre ~45 y 55 % de la altura.

var combat: CombatScene
var vp: SubViewport
var step: int = 0
var failures: PackedStringArray = []
var min_zoom: float = 99.0
var max_zoom: float = 0.0
var max_zoom_jump: float = 0.0
var last_zoom: float = -1.0


func _initialize() -> void:
	var w: int = int(OS.get_environment("VIEW_W")) if OS.get_environment("VIEW_W") != "" else 1280
	vp = SubViewport.new()
	vp.size = Vector2i(w, 720)
	root.add_child(vp)
	combat = load("res://combat/combat_scene.tscn").instantiate()
	vp.add_child(combat)


func _physics_process(_delta: float) -> bool:
	step += 1
	if step == 1:
		var p := FighterSetup.new()
		p.controller_type = FighterSetup.ControllerType.PLAYER
		var s := FightSetup.new()
		s.fighter_a = p
		s.fighter_b = FighterSetup.new()
		combat.start(s)
		Input.action_press("move_right")
		print("Viewport visible: ", vp.get_visible_rect().size)
		return false
	var cam := combat.camera
	var a := combat.fighter_a
	var b := combat.fighter_b
	var z: float = cam.zoom.x
	min_zoom = minf(min_zoom, z)
	max_zoom = maxf(max_zoom, z)
	if last_zoom > 0.0:
		max_zoom_jump = maxf(max_zoom_jump, absf(z - last_zoom))
	last_zoom = z

	var view: Vector2 = vp.get_visible_rect().size / z
	var center: Vector2 = cam.get_screen_center_position()
	var left: float = center.x - view.x * 0.5
	var right: float = center.x + view.x * 0.5
	var top: float = center.y - view.y * 0.5
	if a.position.x - a.half_width() < left - 0.5 or b.position.x + b.half_width() > right + 0.5:
		failures.append("tick %d: peleador cortado a los costados" % step)
	if -a.setup.body_height < top:
		failures.append("tick %d: cabeza cortada" % step)

	if step == 200:
		print("Cerca (gap %.0f): zoom %.3f, peleador = %.0f%% de la altura" % [
			b.position.x - a.position.x, z, 100.0 * 250.0 / view.y])
		Input.action_release("move_right")
		Input.action_press("move_left")
	elif step == 260:
		print("Media (gap %.0f): zoom %.3f, peleador = %.0f%% de la altura" % [
			b.position.x - a.position.x, z, 100.0 * 250.0 / view.y])
	elif step == 700:
		print("Lejos, contra la cuerda (gap %.0f): zoom %.3f, peleador = %.0f%% de la altura" % [
			b.position.x - a.position.x, z, 100.0 * 250.0 / view.y])
		print("Zoom mín/máx: %.3f / %.3f   mayor salto por tick: %.4f" % [min_zoom, max_zoom, max_zoom_jump])
		print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ (%d) %s" % [failures.size(), failures[0]])
		quit()
	return false
