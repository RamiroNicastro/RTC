extends SceneTree
# Prueba automática del Hito B: timing del jab, rango, daño una sola vez, castigo, buffer e intercambio.

class Scripted extends FighterController:
	var move: int = 0
	var jab_next: bool = false

	func get_command(_me: Fighter, _op: Fighter) -> FighterCommand:
		var c := FighterCommand.new()
		c.move = move
		c.jab = jab_next
		jab_next = false
		return c


var failures: PackedStringArray = []
var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	test_timing_and_whiff()
	test_hit_once_and_advantage()
	test_punish_recovery()
	test_buffer()
	test_trade()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func new_combat(gap: float, b_reach: float = 110.0) -> Array:
	var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.set_physics_process(false)  # avanzamos los ticks a mano
	var s := FightSetup.new()
	s.start_with_intro = false
	s.fighter_a = FighterSetup.new()
	s.fighter_b = FighterSetup.new()
	if b_reach != 110.0:
		var long_jab: MoveData = s.fighter_b.jab.duplicate()
		long_jab.reach = b_reach
		s.fighter_b.jab = long_jab
	s.start_distance = gap + 90.0  # gap = espacio borde a borde
	combat.start(s)
	var sa := Scripted.new()
	var sb := Scripted.new()
	combat.controller_a = sa
	combat.controller_b = sb
	return [combat, sa, sb]


func step(combat: CombatScene, n: int = 1) -> void:
	for i in n:
		combat._physics_process(0.0)


func test_timing_and_whiff() -> void:
	var r := new_combat(330.0)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var a := combat.fighter_a
	var whiffs := [0]
	a.attack_whiffed.connect(func(_m: MoveData) -> void: whiffs[0] += 1)
	sa.jab_next = true
	var phases: PackedStringArray = []
	for i in 20:
		step(combat)
		phases.append(Fighter.AttackPhase.keys()[a.attack_phase][0])
	var seq := "".join(phases)
	print("Fases del jab por tick: ", seq, "  (S=arranque A=activo R=recuperación N=nada)")
	check(seq == "SSSSSSAARRRRRRRRRRNN", "timing del jab incorrecto: " + seq)
	check(whiffs[0] == 1, "fuera de rango debería contar 1 fallo")
	check(combat.fighter_b.health == 100, "fuera de rango no debería hacer daño")
	root.remove_child(combat)
	combat.free()


func test_hit_once_and_advantage() -> void:
	var r := new_combat(50.0)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var a := combat.fighter_a
	var b := combat.fighter_b
	var hits := [0]
	combat.hit_resolved.connect(func(_i: HitInfo) -> void: hits[0] += 1)
	sa.jab_next = true
	var hitstun_ticks := 0
	var a_free_at := -1
	var b_free_at := -1
	for t in range(1, 30):
		step(combat)
		if b.state == Fighter.State.HITSTUN:
			hitstun_ticks += 1
		if a_free_at < 0 and t > 1 and a.state != Fighter.State.ATTACKING:
			a_free_at = t
		if b_free_at < 0 and hitstun_ticks > 0 and b.state != Fighter.State.HITSTUN:
			b_free_at = t
	print("En rango: golpes=%d  salud rival=%d  hitstun=%d ticks  ventaja al conectar=%+d" % [
		hits[0], b.health, hitstun_ticks, b_free_at - a_free_at])
	check(hits[0] == 1, "el jab debería conectar exactamente 1 vez (2 ticks activos)")
	check(b.health == 96, "el daño debería ser 4 una sola vez")
	check(hitstun_ticks == 12, "hitstun debería durar 12 ticks")
	root.remove_child(combat)
	combat.free()


func test_punish_recovery() -> void:
	# A falla un jab desde lejos; B tiene más alcance y pega al empezar la recuperación de A.
	var r := new_combat(150.0, 200.0)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var sb: Scripted = r[2]
	var a := combat.fighter_a
	sa.jab_next = true
	step(combat, 8)  # A: arranque + activo
	check(a.attack_phase == Fighter.AttackPhase.ACTIVE, "A debería estar en su último tick activo")
	sb.jab_next = true  # B arranca en el primer tick de recuperación de A
	var punished := false
	for i in 12:
		step(combat)
		if a.state == Fighter.State.HITSTUN:
			punished = true
			break
	print("Castigo de recuperación: A golpeado=%s  salud A=%d" % [punished, a.health])
	check(punished, "un jab fallado debería poder castigarse durante la recuperación")
	root.remove_child(combat)
	combat.free()


func test_buffer() -> void:
	var r := new_combat(330.0)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var starts: Array[int] = []
	combat.fighter_a.attack_started.connect(func(_m: MoveData) -> void: starts.append(combat.clock.tick))
	sa.jab_next = true
	step(combat, 15)
	sa.jab_next = true  # 3 ticks antes de que termine la recuperación
	step(combat, 10)
	print("Buffer: jabs empezaron en los ticks ", starts, " (esperado [1, 19])")
	check(starts == [1, 19], "el buffer debería encadenar el segundo jab sin tick muerto")
	root.remove_child(combat)
	combat.free()


func test_trade() -> void:
	var r := new_combat(50.0)
	var combat: CombatScene = r[0]
	r[1].jab_next = true
	r[2].jab_next = true
	step(combat, 10)
	print("Intercambio: salud A=%d  salud B=%d" % [combat.fighter_a.health, combat.fighter_b.health])
	check(combat.fighter_a.health == 96 and combat.fighter_b.health == 96, "golpes simultáneos deberían intercambiarse")
	root.remove_child(combat)
	combat.free()
