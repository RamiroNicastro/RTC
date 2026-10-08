extends SceneTree
# Prueba automática del Hito C: stamina, cansancio, guardia, golpe fuerte y ruptura de guardia.

class Scripted extends FighterController:
	var move: int = 0
	var guard: bool = false
	var jab_next: bool = false
	var power_next: bool = false

	func get_command(_me: Fighter, _op: Fighter) -> FighterCommand:
		var c := FighterCommand.new()
		c.move = move
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
	test_spam_drains_stamina()
	test_regen()
	test_guard_stops_jab()
	test_power_breaks_guard()
	test_power_hit()
	test_jab_interrupts_power()
	test_exhausted_guard_breaks()
	test_fatigue()
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
	s.fighter_a.max_health = 100  # las cuentas de esta prueba están hechas sobre 100
	s.fighter_a.cut_susceptibility = 0.0  # sin cortes al azar: esta prueba mide otra cosa
	s.fighter_b = FighterSetup.new()
	s.fighter_b.max_health = 100  # las cuentas de esta prueba están hechas sobre 100
	s.fighter_b.cut_susceptibility = 0.0  # sin cortes al azar: esta prueba mide otra cosa
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


func test_spam_drains_stamina() -> void:
	var r := new_combat(330.0)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var a := combat.fighter_a
	var jabs := 0
	while not a.is_tired() and jabs < 30:
		sa.jab_next = true
		step(combat, 1)
		while a.state == Fighter.State.ATTACKING:
			step(combat)
		jabs += 1
	print("Spam de jabs al aire: cansado después de %d jabs (stamina %.1f)" % [jabs, a.stamina])
	check(a.is_tired() and jabs >= 8 and jabs <= 12, "spamear jabs al aire debería cansar, pero no tan rápido (entre 8 y 12 jabs)")
	sa.jab_next = true
	var startup := 0
	for i in 15:
		step(combat)
		if a.attack_phase == Fighter.AttackPhase.STARTUP:
			startup += 1
	print("Arranque del jab cansado: %d ticks (normal 6)" % startup)
	check(startup == 10, "cansado, el jab debería arrancar en 10 ticks")
	dispose(combat)


func test_regen() -> void:
	var r := new_combat(330.0)
	var combat: CombatScene = r[0]
	var a := combat.fighter_a
	a.spend_stamina(50.0)
	step(combat, Fighter.REGEN_DELAY_TICKS)
	var after_delay: float = a.stamina
	step(combat, 60)
	print("Regeneración: %.1f tras la pausa, %.1f un segundo después (esperado 50 → 68)" % [after_delay, a.stamina])
	check(is_equal_approx(after_delay, 50.0), "no debería regenerar durante la pausa")
	check(absf(a.stamina - 68.0) < 0.5, "debería regenerar 18 por segundo quieto")
	dispose(combat)


func test_guard_stops_jab() -> void:
	var r := new_combat(50.0)
	var combat: CombatScene = r[0]
	var sb: Scripted = r[2]
	var b := combat.fighter_b
	var infos: Array[HitInfo] = []
	combat.hit_resolved.connect(func(i: HitInfo) -> void: infos.append(i))
	sb.guard = true
	step(combat, 2)
	r[1].jab_next = true
	step(combat, 8)
	check(infos.size() == 1, "el jab debería llegar 1 vez")
	if infos.size() == 1:
		print("Jab contra guardia: %s, daño %d, stamina del rival %.0f, estado %s" % [
			HitInfo.Result.keys()[infos[0].result], infos[0].damage, b.stamina, Fighter.State.keys()[b.state]])
		check(infos[0].result == HitInfo.Result.BLOCKED, "la guardia debería bloquear el jab")
		check(infos[0].damage == 1, "por la guardia debería pasar 1 de daño")
		check(b.state == Fighter.State.BLOCKSTUN, "el rival debería quedar en blockstun")
		check(is_equal_approx(b.stamina, 99.0), "un jab bloqueado debería sacar solo 1 de stamina")
		check(b.fatigue == 0.0, "bloquear no debería generar fatiga")
	step(combat, 10)
	check(b.state == Fighter.State.BLOCKING, "después del blockstun vuelve a la guardia")
	dispose(combat)


func test_power_breaks_guard() -> void:
	var r := new_combat(50.0)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var sb: Scripted = r[2]
	var a := combat.fighter_a
	var b := combat.fighter_b
	var infos: Array[HitInfo] = []
	combat.hit_resolved.connect(func(i: HitInfo) -> void: infos.append(i))
	sb.guard = true
	step(combat, 2)
	sa.power_next = true
	step(combat, 2)
	while a.state == Fighter.State.ATTACKING:
		step(combat)
	check(b.state == Fighter.State.GUARD_BROKEN, "el fuerte debería romper la guardia")
	var broken_left: int = b.stun_left
	sa.jab_next = true  # castigo inmediato apenas el atacante se libera
	step(combat, 10)
	var last: HitInfo = infos.back()
	print("Fuerte contra guardia: guardia rota=%s, al atacante le sobran %d ticks; jab de castigo: %s" % [
		infos[0].guard_broken, broken_left, HitInfo.Result.keys()[last.result]])
	check(infos[0].result == HitInfo.Result.BLOCKED and infos[0].guard_broken, "debería figurar como guardia rota")
	check(last.move.id == &"jab" and last.result == HitInfo.Result.HIT, "el jab tras romper la guardia debería entrar")
	dispose(combat)


func test_power_hit() -> void:
	var r := new_combat(50.0)
	var combat: CombatScene = r[0]
	r[1].power_next = true
	step(combat, 25)
	print("Fuerte sin guardia: salud del rival %d (esperado 86)" % combat.fighter_b.health)
	check(combat.fighter_b.health == 86, "el fuerte debería hacer 14")
	dispose(combat)


func test_jab_interrupts_power() -> void:
	var r := new_combat(50.0)
	var combat: CombatScene = r[0]
	r[2].power_next = true  # el rival arranca un fuerte (16 ticks de arranque)
	step(combat, 2)
	r[1].jab_next = true    # el jugador responde con un jab (6 de arranque)
	step(combat, 40)
	print("Jab vs arranque del fuerte: salud jugador %d, salud rival %d" % [
		combat.fighter_a.health, combat.fighter_b.health])
	check(combat.fighter_a.health == 100, "el jab debería interrumpir el fuerte antes de que pegue")
	check(combat.fighter_b.health == 96, "el jab debería conectar")
	dispose(combat)


func test_exhausted_guard_breaks() -> void:
	var r := new_combat(50.0)
	var combat: CombatScene = r[0]
	var b := combat.fighter_b
	r[2].guard = true
	step(combat, 2)
	b.spend_stamina(b.stamina - 1.0)
	r[1].jab_next = true
	step(combat, 8)
	print("Guardia sin stamina contra un jab: estado %s, stamina %.0f" % [Fighter.State.keys()[b.state], b.stamina])
	check(b.state == Fighter.State.GUARD_BROKEN, "sin stamina, un jab bloqueado debería romper la guardia")
	dispose(combat)


func test_fatigue() -> void:
	var r := new_combat(330.0)
	var combat: CombatScene = r[0]
	var a := combat.fighter_a
	a.spend_stamina(40.0)
	print("Fatiga: gastar 40 → fatiga %.1f, máximo %.1f (esperado 4 y 96)" % [a.fatigue, a.max_stamina])
	check(is_equal_approx(a.fatigue, 4.0) and is_equal_approx(a.max_stamina, 96.0), "el 10 % del gasto debería ser fatiga")
	step(combat, 600)
	check(is_equal_approx(a.stamina, 96.0), "la stamina se recupera solo hasta el máximo con fatiga")
	for i in 20:
		a.spend_stamina(50.0)
	print("Fatiga con tope: %.1f (tope 25), máximo %.1f" % [a.fatigue, a.max_stamina])
	check(is_equal_approx(a.fatigue, 25.0), "la fatiga debería tener tope en el 25 %")
	a.recover_fatigue(0.5)
	print("Tras recuperar la mitad: fatiga %.1f, máximo %.1f" % [a.fatigue, a.max_stamina])
	check(is_equal_approx(a.fatigue, 12.5), "recover_fatigue(0.5) debería recuperar la mitad")
	dispose(combat)
