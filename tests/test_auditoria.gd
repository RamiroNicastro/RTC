extends SceneTree
# Prueba de los arreglos de la auditoría de código: intercambio justo, cámara lenta que no se pisa,
# pausa que no deja golpes guardados y game feel (hitstop) que congela la lógica.

class Scripted extends FighterController:
	var jab_next: bool = false

	func get_command(_me: Fighter, _op: Fighter) -> FighterCommand:
		var c := FighterCommand.new()
		c.jab = jab_next
		jab_next = false
		return c


var failures: PackedStringArray = []
var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	test_fair_double_knockdown()
	test_slow_motion_keeps_longest()
	test_hitstop_freezes_logic()
	test_pause_clears_pending()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func new_combat(feel: bool = false) -> CombatScene:
	var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.set_physics_process(false)
	var s := FightSetup.new()
	s.start_with_intro = false
	s.game_feel = feel
	s.fighter_a = FighterSetup.new()
	s.fighter_a.max_health = 100
	s.fighter_a.cut_susceptibility = 0.0
	s.fighter_b = FighterSetup.new()
	s.fighter_b.max_health = 100
	s.fighter_b.cut_susceptibility = 0.0
	s.start_distance = 140.0
	combat.start(s)
	combat.controller_a = Scripted.new()
	combat.controller_b = Scripted.new()
	return combat


func step(combat: CombatScene, n: int = 1) -> void:
	for i in n:
		combat._physics_process(0.0)


func dispose(combat: CombatScene) -> void:
	root.remove_child(combat)
	combat.free()


func test_fair_double_knockdown() -> void:
	var combat := new_combat()
	combat.fighter_a.health = 2
	combat.fighter_b.health = 2
	(combat.controller_a as Scripted).jab_next = true
	(combat.controller_b as Scripted).jab_next = true
	step(combat, 10)
	print("Intercambio que tumbaría a los dos: salud %d / %d, fase %s" % [
		combat.fighter_a.health, combat.fighter_b.health, FightManager.Phase.keys()[combat.fight.phase]])
	check(combat.fighter_a.health == 1 and combat.fighter_b.health == 1, "ninguno debería caer por el orden de proceso")
	check(combat.fight.phase == FightManager.Phase.FIGHTING, "la pelea sigue")
	dispose(combat)


func test_slow_motion_keeps_longest() -> void:
	var clock := CombatClock.new()
	clock.slow_motion(150, 4)
	clock.slow_motion(70, 3)
	var advanced: int = 0
	for i in 150:
		if clock.advance():
			advanced += 1
	print("Cámara lenta 150 (1 de 4) y después 70 (1 de 3): avanzó %d de 150 ticks" % advanced)
	check(advanced == 150 / 4, "la cámara lenta más larga no debería pisarse con una más corta")


func test_hitstop_freezes_logic() -> void:
	var combat := new_combat(true)
	(combat.controller_a as Scripted).jab_next = true
	var before: int = -1
	for i in 20:
		step(combat)
		if combat.clock.is_frozen() and before < 0:
			before = combat.clock.tick
	print("Hitstop: la lógica se congeló en el tick %d" % before)
	check(before > 0, "con game feel, un golpe que conecta debería congelar la lógica unos ticks")
	dispose(combat)


func test_pause_clears_pending() -> void:
	var p := PlayerInput.new()
	p._pending_jab = true
	p.clear_pending()
	check(not p._pending_jab, "al reanudar se descartan los toques guardados durante la pausa")
	var combat := new_combat()
	combat.set_paused(true)
	var t: int = combat.clock.tick
	step(combat, 10)
	check(combat.clock.tick == t, "en pausa la lógica no avanza")
	combat.set_paused(false)
	step(combat, 1)
	check(combat.clock.tick == t + 1, "al reanudar sigue")
	dispose(combat)
	print("Pausa: no avanza, al reanudar sigue y descarta lo apretado")
