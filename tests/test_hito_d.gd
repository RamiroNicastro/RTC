extends SceneTree
# Prueba automática del Hito D: esquive (solo cabeza), counter, golpes al cuerpo y su tope.

class Scripted extends FighterController:
	var move: int = 0
	var guard: bool = false
	var body: bool = false
	var jab_next: bool = false
	var power_next: bool = false
	var dodge_next: bool = false

	func get_command(_me: Fighter, _op: Fighter) -> FighterCommand:
		var c := FighterCommand.new()
		c.move = move
		c.guard = guard
		c.body = body
		c.jab = jab_next
		c.power = power_next
		c.dodge = dodge_next
		jab_next = false
		power_next = false
		dodge_next = false
		return c


var failures: PackedStringArray = []
var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	test_dodge_beats_power_and_counter()
	test_body_beats_dodge()
	test_whiffed_dodge_is_punishable()
	test_body_drain_cap_and_guard()
	test_dummy_dodge_mode()
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
	s.fighter_a = FighterSetup.new()
	s.fighter_b = FighterSetup.new()
	s.start_distance = gap + 90.0
	combat.start(s)
	var sa := Scripted.new()
	var sb := Scripted.new()
	combat.controller_a = sa
	combat.controller_b = sb
	return [combat, sa, sb]


func step(combat: CombatScene, n: int = 1) -> void:
	for i in n:
		combat._physics_process(0.0)


func dispose(combat: CombatScene) -> void:
	root.remove_child(combat)
	combat.free()


func collect(combat: CombatScene) -> Array[HitInfo]:
	var infos: Array[HitInfo] = []
	combat.hit_resolved.connect(func(i: HitInfo) -> void: infos.append(i))
	return infos


func test_dodge_beats_power_and_counter() -> void:
	var r := new_combat(50.0)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var sb: Scripted = r[2]
	var a := combat.fighter_a
	var infos := collect(combat)
	sb.power_next = true          # el rival arranca un fuerte (16 de arranque)
	step(combat, 7)
	sa.dodge_next = true          # el jugador esquiva: invulnerable de la cabeza en sus ticks 3..12
	step(combat, 14)
	check(infos.size() >= 1 and infos[0].result == HitInfo.Result.DODGED, "el esquive debería evitar el fuerte")
	check(a.health == 100, "esquivar no debería costar salud")
	check(a.state != Fighter.State.DODGING, "un esquive exitoso cancela la recuperación")
	check(a.counter_ready_left > 0, "después de esquivar debería haber un counter listo")
	print("Esquive vs fuerte: %s, salud jugador %d, counter listo %d ticks" % [
		HitInfo.Result.keys()[infos[0].result] if infos.size() > 0 else "-", a.health, a.counter_ready_left])
	sa.jab_next = true            # counter: el rival está en la recuperación de su fuerte
	step(combat, 8)
	var last: HitInfo = infos.back()
	print("Counter: %s, counter=%s, daño %d (normal 4)" % [HitInfo.Result.keys()[last.result], last.counter, last.damage])
	check(last.result == HitInfo.Result.HIT and last.counter and last.damage == 6, "el jab de counter debería hacer 6 (4 × 1,5)")
	dispose(combat)


func test_body_beats_dodge() -> void:
	var r := new_combat(40.0)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var sb: Scripted = r[2]
	var a := combat.fighter_a
	var infos := collect(combat)
	sb.body = true
	sb.jab_next = true            # el rival tira un jab al cuerpo (7 de arranque)
	step(combat, 3)
	sa.dodge_next = true
	step(combat, 10)
	print("Jab al cuerpo vs esquive: %s, salud %d, desgaste del cuerpo %.0f, stamina máx %.0f" % [
		HitInfo.Result.keys()[infos[0].result] if infos.size() > 0 else "-", a.health, a.body_drain, a.max_stamina])
	check(infos.size() == 1 and infos[0].result == HitInfo.Result.HIT, "el golpe al cuerpo debería atravesar el esquive")
	check(is_equal_approx(a.body_drain, 5.0), "el jab al cuerpo debería bajar 5 de stamina máxima")
	dispose(combat)


func test_whiffed_dodge_is_punishable() -> void:
	var r := new_combat(50.0)
	var combat: CombatScene = r[0]
	var a := combat.fighter_a
	r[1].dodge_next = true        # esquiva al aire
	step(combat, 9)               # invulnerable hasta su tick 12
	r[2].jab_next = true          # el jab del rival llega en su tick 7 → tick 16 del esquive (recuperación)
	step(combat, 8)
	print("Esquive al aire castigado: estado %s, salud %d" % [Fighter.State.keys()[a.state], a.health])
	check(a.state == Fighter.State.HITSTUN and a.health == 96, "un esquive al aire debería poder castigarse en su recuperación")
	dispose(combat)


func test_body_drain_cap_and_guard() -> void:
	var r := new_combat(40.0)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var sb: Scripted = r[2]
	var b := combat.fighter_b
	sa.body = true
	for i in 6:
		sa.power_next = true      # fuerte al cuerpo: 12 de desgaste cada uno
		step(combat, 70)
	print("Seis fuertes al cuerpo: desgaste %.0f (tope 30), stamina máx %.0f" % [b.body_drain, b.max_stamina])
	check(is_equal_approx(b.body_drain, 30.0), "el desgaste del cuerpo debería tener tope en 30")
	b.recover_body_drain(0.5)
	check(is_equal_approx(b.body_drain, 15.0), "recover_body_drain(0.5) debería recuperar la mitad")
	dispose(combat)

	r = new_combat(40.0)
	combat = r[0]
	r[2].guard = true
	step(combat, 2)
	r[1].body = true
	r[1].jab_next = true
	step(combat, 10)
	print("Jab al cuerpo contra guardia: desgaste %.0f (esperado 0)" % combat.fighter_b.body_drain)
	check(combat.fighter_b.body_drain == 0.0, "un golpe al cuerpo bloqueado no desgasta")
	dispose(combat)


func test_dummy_dodge_mode() -> void:
	# El dummy en modo ESQUIVA evita jab y fuerte a la cabeza, pero no el jab al cuerpo.
	for case in [["jab", false, HitInfo.Result.DODGED], ["fuerte", false, HitInfo.Result.DODGED], ["jab al cuerpo", true, HitInfo.Result.HIT]]:
		var r := new_combat(50.0)
		var combat: CombatScene = r[0]
		var dummy := DummyInput.new()
		dummy.mode = DummyInput.Mode.ESQUIVA
		dummy.interval_ticks = 100000
		combat.controller_b = dummy
		var infos := collect(combat)
		r[1].body = case[1]
		if case[0] == "fuerte":
			r[1].power_next = true
		else:
			r[1].jab_next = true
		step(combat, 25)
		var got: String = HitInfo.Result.keys()[infos[0].result] if infos.size() > 0 else "nada"
		print("Dummy ESQUIVA contra %s: %s" % [case[0], got])
		check(infos.size() > 0 and infos[0].result == case[2], "dummy ESQUIVA contra %s debería dar %s" % [case[0], HitInfo.Result.keys()[case[2]]])
		dispose(combat)
