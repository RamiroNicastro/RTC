extends SceneTree
# Prueba automática del Hito A: simula input y verifica cuerdas, choque y velocidad por tick.

var combat: CombatScene
var step: int = 0
var failures: PackedStringArray = []


func _initialize() -> void:
	combat = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	var p := FighterSetup.new()
	p.controller_type = FighterSetup.ControllerType.PLAYER
	var d := FighterSetup.new()
	var s := FightSetup.new()
	s.start_with_intro = false
	s.fighter_a = p
	s.fighter_b = d
	set_meta("setup", s)


func _physics_process(_delta: float) -> bool:
	step += 1
	var a := combat.fighter_a
	var b := combat.fighter_b
	if step == 1:
		combat.start(get_meta("setup"))
		Input.action_press("move_right")
	elif step == 31:
		# 30 ticks avanzando: 260 u/s * 0.5 s = 130 u (aprox.)
		var moved := a.position.x - (-210.0)
		print("Avance en 30 ticks: %.2f (esperado ~130)" % moved)
		if absf(moved - 130.0) > 5.0:
			failures.append("velocidad incorrecta")
	elif step == 200:
		var gap := b.position.x - a.position.x
		print("Tras empujar contra el rival: gap=%.2f, rival x=%.2f" % [gap, b.position.x])
		if gap < 89.99:
			failures.append("atraviesa al rival")
		if absf(b.position.x - 210.0) > 0.01:
			failures.append("empuja al rival")
		Input.action_release("move_right")
		Input.action_press("move_left")
	elif step == 600:
		print("Contra la cuerda izquierda: x=%.2f (límite %.2f)" % [a.position.x, -750.0 + 45.0])
		if a.position.x < -705.01:
			failures.append("atraviesa la cuerda")
		Input.action_release("move_left")
		print("Estado final: ", Fighter.State.keys()[a.state], "  tick=", combat.clock.tick)
		print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ " + ", ".join(failures))
		quit()
	return false
