extends SceneTree
# Prueba automática del Hito E3: FightStats, jueces, decisiones y FightResult.

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
	test_stats_count_real_events()
	test_decision_matches_fight()
	test_knockdown_round_scores_10_8()
	test_decision_types()
	test_ko_result()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func new_combat(round_seconds: float = 60.0, rounds: int = 3, gap: float = 50.0) -> Array:
	var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.set_physics_process(false)
	var s := FightSetup.new()
	s.start_with_intro = false
	s.game_feel = false
	s.fighter_a = FighterSetup.new()
	s.fighter_a.max_health = 100  # las cuentas de esta prueba están hechas sobre 100
	s.fighter_a.cut_susceptibility = 0.0  # sin cortes al azar: esta prueba mide otra cosa
	s.fighter_a.display_name = "A"
	s.fighter_b = FighterSetup.new()
	s.fighter_b.max_health = 100  # las cuentas de esta prueba están hechas sobre 100
	s.fighter_b.cut_susceptibility = 0.0  # sin cortes al azar: esta prueba mide otra cosa
	s.fighter_b.display_name = "B"
	s.start_distance = gap + 90.0
	s.rounds = rounds
	s.round_seconds = round_seconds
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


func until_fighting(combat: CombatScene) -> void:
	while combat.fight.phase != FightManager.Phase.FIGHTING and combat.fight.phase != FightManager.Phase.ENDED:
		step(combat)


func test_stats_count_real_events() -> void:
	var r := new_combat()
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	# Antes de cada golpe se acomoda la distancia (cada golpe empuja al rival).
	for i in 3:
		combat.fighter_b.position.x = combat.fighter_a.position.x + 140.0
		sa.jab_next = true
		step(combat, 25)
	combat.fighter_b.position.x = combat.fighter_a.position.x + 140.0
	sa.power_next = true
	step(combat, 45)
	combat.fighter_b.position.x = combat.fighter_a.position.x + 600.0   # lo alejo: el próximo jab falla
	sa.jab_next = true
	step(combat, 25)
	var a: FightStats.FighterRoundStats = combat.stats.current(0)
	print("Registro: tirados %d, conectados %d, de poder %d, daño %d" % [a.thrown, a.landed, a.landed_power, a.damage_dealt])
	check(a.thrown == 5 and a.landed == 4 and a.landed_power == 1, "debería registrar 5 tirados, 4 conectados, 1 de poder")
	check(a.damage_dealt == 3 * 4 + 14, "el daño registrado debería ser 26 (jab a distancia 50 ≈ 4, fuerte 14)")
	dispose(combat)


func test_decision_matches_fight() -> void:
	var r := new_combat(3.0, 2)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var results: Array = []
	combat.fight_finished.connect(func(res: FightResult) -> void: results.append(res))
	# Round 1: A conecta 3 jabs, B no hace nada → 10-9 para A en las tres tarjetas.
	for i in 3:
		sa.jab_next = true
		step(combat, 25)
	while combat.fight.round_number == 1:
		step(combat)
	until_fighting(combat)
	# Round 2: nadie hace nada → 10-10.
	while combat.fight.phase != FightManager.Phase.ENDED:
		step(combat)
	check(results.size() == 1, "fight_finished debería emitirse una vez")
	if results.size() == 1:
		var res: FightResult = results[0]
		print("Decisión: %s para %s, tarjetas %s" % [
			FightResult.Method.keys()[res.method], res.winner_name(), res.judge_totals])
		check(res.winner_index == 0 and res.method == FightResult.Method.UNANIMOUS_DECISION, "A debería ganar por decisión unánime")
		check(res.judge_totals == [Vector2i(20, 19), Vector2i(20, 19), Vector2i(20, 19)], "las tarjetas deberían ser 20-19")
		check(res.judge_cards[0] == [Vector2i(10, 9), Vector2i(10, 10)], "round 1 10-9 y round 2 10-10")
	dispose(combat)


func test_knockdown_round_scores_10_8() -> void:
	var judge: Judge = Judge.make_panel()[0]
	var a := FightStats.FighterRoundStats.new()
	var b := FightStats.FighterRoundStats.new()
	b.landed = 12          # B conectó mucho más…
	a.landed = 2
	b.knockdowns_suffered = 1   # …pero cayó una vez
	var score: Vector2i = judge.score_round(a, b)
	print("Round con caída del que pegó más: %d-%d" % [score.x, score.y])
	check(score == Vector2i(10, 8), "una caída da 10-8 aunque el caído haya conectado más")


func test_decision_types() -> void:
	var cases := [
		[[Vector2i(30, 27), Vector2i(29, 28), Vector2i(28, 29)], 0, FightResult.Method.SPLIT_DECISION],
		[[Vector2i(29, 28), Vector2i(29, 28), Vector2i(28, 28)], 0, FightResult.Method.MAJORITY_DECISION],
		[[Vector2i(27, 30), Vector2i(28, 29), Vector2i(28, 29)], 1, FightResult.Method.UNANIMOUS_DECISION],
		[[Vector2i(29, 28), Vector2i(28, 29), Vector2i(28, 28)], -1, FightResult.Method.DRAW],
		[[Vector2i(29, 28), Vector2i(28, 28), Vector2i(28, 28)], -1, FightResult.Method.DRAW],
	]
	for c in cases:
		var totals: Array[Vector2i] = []
		totals.assign(c[0])
		var d: Array = FightResult.decide(totals)
		check(d[0] == c[1] and d[1] == c[2], "tarjetas %s deberían dar %s" % [c[0], FightResult.Method.keys()[c[2]]])
	print("Tipos de decisión: unánime, dividida, mayoritaria y empates verificados")


func test_ko_result() -> void:
	var r := new_combat()
	var combat: CombatScene = r[0]
	var results: Array = []
	combat.fight_finished.connect(func(res: FightResult) -> void: results.append(res))
	(r[1] as Scripted).jab_next = true
	combat.fighter_b.health = 3
	step(combat, 8)
	step(combat, FightManager.COUNT_TICKS_PER_NUMBER * FightManager.COUNT_OUT + 5)
	check(results.size() == 1, "debería haber un resultado")
	if results.size() == 1:
		var res: FightResult = results[0]
		print("KO: método %s, gana %s, round %d en %d s, caídas %s" % [
			FightResult.Method.keys()[res.method], res.winner_name(), res.end_round, res.end_round_elapsed_seconds, res.knockdowns])
		check(res.method == FightResult.Method.KO and res.winner_index == 0 and res.end_round == 1, "KO del jugador en el round 1")
		check(res.knockdowns == Vector2i(0, 1), "1 caída del rival")
		# R2: el resultado no guarda nodos.
		for p in res.get_property_list():
			var v: Variant = res.get(p.name)
			check(not (v is Node), "FightResult no debería guardar nodos (%s)" % p.name)
	dispose(combat)
