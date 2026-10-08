extends SceneTree
# Prueba automática de los cortes (pasada de realismo, parte 1): se abren, crecen, suman daño,
# empeoran la visión de la IA, el cutman los reduce y el médico para la pelea.

class Scripted extends FighterController:
	var jab_next: bool = false
	var power_next: bool = false

	func get_command(_me: Fighter, _op: Fighter) -> FighterCommand:
		var c := FighterCommand.new()
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
	test_cut_opens_and_grows()
	test_cut_adds_damage()
	test_vision_penalty()
	test_cutman_and_doctor_at_break()
	test_doctor_immediate()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func new_combat(susceptibility: float, round_seconds: float = 60.0, rounds: int = 3) -> Array:
	var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.set_physics_process(false)
	var s := FightSetup.new()
	s.start_with_intro = false
	s.game_feel = false
	s.rounds = rounds
	s.round_seconds = round_seconds
	s.fighter_a = FighterSetup.new()
	s.fighter_a.max_health = 100
	s.fighter_b = FighterSetup.new()
	s.fighter_b.max_health = 100
	s.fighter_b.cut_susceptibility = susceptibility
	s.fighter_b.ai_seed = 42
	s.start_distance = 140.0
	combat.start(s)
	var sa := Scripted.new()
	combat.controller_a = sa
	combat.controller_b = Scripted.new()
	var infos: Array[HitInfo] = []
	combat.hit_resolved.connect(func(i: HitInfo) -> void: infos.append(i))
	return [combat, sa, infos]


func step(combat: CombatScene, n: int = 1) -> void:
	for i in n:
		combat._physics_process(0.0)


func power_hit(combat: CombatScene, sa: Scripted) -> void:
	combat.fighter_b.position.x = combat.fighter_a.position.x + 130.0
	sa.power_next = true
	step(combat, 45)


func dispose(combat: CombatScene) -> void:
	root.remove_child(combat)
	combat.free()


func test_cut_opens_and_grows() -> void:
	var r := new_combat(100.0)   # piel de papel: el primer fuerte a la cabeza corta seguro
	var combat: CombatScene = r[0]
	var b := combat.fighter_b
	power_hit(combat, r[1])
	check(b.cuts.size() == 1, "un fuerte a la cabeza con piel frágil debería abrir un corte")
	var first: float = b.worst_cut_severity()
	combat.fighter_b.setup.cut_susceptibility = 0.0   # que no se abran más: ver solo cómo crece
	power_hit(combat, r[1])
	print("Corte: abierto con gravedad %.2f → %.2f después de otro fuerte" % [first, b.worst_cut_severity()])
	check(b.worst_cut_severity() > first, "otro golpe a la cabeza debería agrandar el corte")
	dispose(combat)


func test_cut_adds_damage() -> void:
	var damages := []
	for cut in [false, true]:
		var r := new_combat(0.0)
		var combat: CombatScene = r[0]
		if cut:
			combat.fighter_b.open_cut()
		power_hit(combat, r[1])
		var infos: Array[HitInfo] = r[2]
		damages.append(infos[0].damage)
		dispose(combat)
	print("Fuerte sin corte %d, con corte %d (×1,18)" % damages)
	check(damages[1] == roundi(damages[0] * 1.18), "pegar sobre un corte debería hacer un 18 % más")


func test_vision_penalty() -> void:
	var r := new_combat(0.0)
	var combat: CombatScene = r[0]
	var b := combat.fighter_b
	var ai := AIInput.new()
	ai.configure(null, 1)
	combat.controller_b = ai
	step(combat, 2)
	var base: int = ai.reaction_ticks
	b.open_cut()
	b.cuts[0].severity = 1.0
	step(combat, 2)
	print("IA: reacción %d ticks sin corte, %d con un corte grave" % [base, ai.reaction_ticks])
	check(ai.reaction_ticks == base + Fighter.CUT_VISION_MAX_TICKS, "con un corte grave la IA debería ver peor")
	dispose(combat)


func test_cutman_and_doctor_at_break() -> void:
	# Corte moderado: el cutman lo reduce en el descanso.
	var r := new_combat(0.0, 1.0, 3)
	var combat: CombatScene = r[0]
	var b := combat.fighter_b
	b.open_cut()
	b.cuts[0].severity = 0.8
	while combat.fight.phase != FightManager.Phase.ROUND_BREAK:
		step(combat)
	print("Cutman: corte 0.80 → %.2f en el descanso" % b.worst_cut_severity())
	check(absf(b.worst_cut_severity() - 0.8 * (1.0 - Fighter.CUTMAN_REDUCTION)) < 0.01, "el cutman debería reducir el corte un 35 %")
	dispose(combat)
	# Corte muy grave: el médico para la pelea en el descanso.
	r = new_combat(0.0, 1.0, 3)
	combat = r[0]
	var results: Array = []
	combat.fight_finished.connect(func(res: FightResult) -> void: results.append(res))
	combat.fighter_b.open_cut()
	combat.fighter_b.cuts[0].severity = 1.1
	for i in 200:
		step(combat)
		if not results.is_empty():
			break
	var res: FightResult = results[0] if results.size() > 0 else null
	print("Médico en el descanso: %s, gana %s, lesiones %s" % [
		FightResult.Method.keys()[res.method] if res else "-", res.winner_index if res else "-", res.injuries if res else []])
	check(res != null and res.method == FightResult.Method.DOCTOR_STOPPAGE and res.winner_index == 0,
			"con un corte muy grave el médico debería parar la pelea (gana el otro)")
	check(res != null and res.injuries.size() == 1 and res.injuries[0]["type"] == "cut", "el resultado debería registrar el corte como lesión")
	dispose(combat)


func test_doctor_immediate() -> void:
	var r := new_combat(0.0)
	var combat: CombatScene = r[0]
	var results: Array = []
	combat.fight_finished.connect(func(res: FightResult) -> void: results.append(res))
	combat.fighter_b.open_cut()
	combat.fighter_b.cuts[0].severity = Fighter.DOCTOR_IMMEDIATE_SEVERITY - 0.05
	power_hit(combat, r[1])   # el golpe lo agranda por encima del límite
	print("Médico en el momento: %s" % (FightResult.Method.keys()[results[0].method] if results.size() > 0 else "no paró"))
	check(results.size() == 1 and results[0].method == FightResult.Method.DOCTOR_STOPPAGE,
			"un corte gravísimo debería hacer parar la pelea en el momento")
	dispose(combat)
