extends SceneTree
# Prueba automática de la ronda 3: golpe estrella (medidor) y combo 1-2.

class Scripted extends FighterController:
	var guard: bool = false
	var jab_next: bool = false
	var power_next: bool = false

	func get_command(_me: Fighter, _op: Fighter) -> FighterCommand:
		var c := FighterCommand.new()
		c.guard = guard
		c.jab = jab_next
		c.power = power_next
		jab_next = false
		power_next = false
		return c


var failures: PackedStringArray = []
var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	test_star_punch()
	test_star_breaks_guard_from_the_tip()
	test_one_two()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func new_combat(gap: float) -> Array:
	var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.set_physics_process(false)
	var s := FightSetup.new()
	s.start_with_intro = false
	s.game_feel = false
	s.fighter_a = FighterSetup.new()
	s.fighter_b = FighterSetup.new()
	s.start_distance = gap + 90.0
	combat.start(s)
	var sa := Scripted.new()
	var sb := Scripted.new()
	combat.controller_a = sa
	combat.controller_b = sb
	var infos: Array[HitInfo] = []
	combat.hit_resolved.connect(func(i: HitInfo) -> void: infos.append(i))
	return [combat, sa, sb, infos]


func step(combat: CombatScene, n: int = 1) -> void:
	for i in n:
		combat._physics_process(0.0)


func dispose(combat: CombatScene) -> void:
	root.remove_child(combat)
	combat.free()


func test_star_punch() -> void:
	var r := new_combat(40.0)
	var combat: CombatScene = r[0]
	var a := combat.fighter_a
	# Simula lo que llena el medidor: dos counters y un esquive (0.4 + 0.4 + 0.15 → lleno con un poco más).
	var fake := HitInfo.new()
	fake.result = HitInfo.Result.HIT
	fake.counter = true
	fake.move = a.setup.jab
	a.notify_attack_result(fake)
	a.notify_attack_result(fake)
	check(is_equal_approx(a.star_meter, 0.8), "dos counters deberían llenar 0.8 del medidor")
	a.notify_attack_result(fake)
	check(a.star_ready(), "con el medidor lleno, el golpe estrella está listo")
	r[1].power_next = true
	step(combat, 30)
	var infos: Array[HitInfo] = r[3]
	var hit: HitInfo = infos.back() if infos.size() > 0 else null
	print("Golpe estrella: star=%s, daño %d (normal 14), empuje %.0f, medidor después %.1f" % [
		hit.star if hit else false, hit.damage if hit else 0, hit.knockback if hit else 0.0, a.star_meter])
	check(hit != null and hit.star and hit.damage == 22, "el golpe estrella debería pegar 14 × 1,6 ≈ 22")
	check(a.star_meter == 0.0, "el golpe estrella consume el medidor")
	dispose(combat)


func test_star_breaks_guard_from_the_tip() -> void:
	# Un fuerte normal desde la punta NO rompe la guardia; el golpe estrella sí.
	var results := []
	for star in [false, true]:
		var r := new_combat(92.0)
		var combat: CombatScene = r[0]
		r[2].guard = true
		step(combat, 2)
		if star:
			combat.fighter_a.star_meter = 1.0
		r[1].power_next = true
		step(combat, 30)
		var infos: Array[HitInfo] = r[3]
		results.append(infos[0].guard_broken if infos.size() > 0 else false)
		dispose(combat)
	print("Fuerte desde la punta contra la guardia: normal rompe=%s, estrella rompe=%s" % results)
	check(results == [false, true], "solo el golpe estrella rompe la guardia desde la punta")


func test_one_two() -> void:
	var r := new_combat(50.0)
	var combat: CombatScene = r[0]
	var a := combat.fighter_a
	r[1].jab_next = true
	step(combat, 1)
	while a.state == Fighter.State.ATTACKING:
		step(combat)
	check(a.combo_window_left > 0, "un jab que conecta abre la ventana del 1-2")
	r[1].power_next = true
	step(combat, 1)
	var fast_startup: int = a.startup_ticks_effective()
	step(combat, 30)
	var infos: Array[HitInfo] = r[3]
	var combo_hit: HitInfo = infos.back()
	# Sin jab previo (o fuera de la ventana), el fuerte arranca normal.
	combat.fighter_b.position.x = a.position.x + 140.0
	step(combat, Fighter.COMBO_WINDOW_TICKS + 10)
	r[1].power_next = true
	step(combat, 1)
	var normal_startup: int = a.startup_ticks_effective()
	print("1-2: arranque del fuerte después del jab %d ticks (normal %d), combo=%s" % [fast_startup, normal_startup, combo_hit.combo])
	check(fast_startup == normal_startup - Fighter.COMBO_STARTUP_CUT_TICKS, "el fuerte del 1-2 debería arrancar 6 ticks antes")
	check(combo_hit.combo, "el HitInfo debería marcar el 1-2")
	dispose(combat)
