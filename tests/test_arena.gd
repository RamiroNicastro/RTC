extends SceneTree
# Prueba automática de la Arena (carrera, parte 3): rivales generados, ofertas de la semana
# (elegir o "te toca"), bolsas, resultado (plata, récord, ranking, energía, semana),
# energía mínima, stamina según energía, la pantalla y una pelea real IA contra IA.

var failures: PackedStringArray = []
var done: bool = false
var gs: Node
var sm: Node


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	gs = root.get_node("GameState")
	sm = root.get_node("SaveManager")
	sm.folder = "user://test_arena"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sm.folder))
	ArenaRules.rng.seed = 1234
	test_rival_generator()
	test_offers_persist_and_change()
	test_choice_and_assigned()
	test_purse()
	test_results()
	test_energy_rules()
	test_decline()
	test_save_round_trip()
	test_screen()
	test_real_fight()
	sm.delete_slot()
	gs.clear()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func fresh() -> void:
	var p := PlayerFighter.new()
	p.full_name = "Test"
	p.style_id = &"balanced"
	gs.new_career(p)


## Un FightResult armado a mano (sin pelear).
func fake_result(winner: int, method: FightResult.Method, my_health: int = 120, my_kd: int = 0) -> FightResult:
	var r := FightResult.new()
	r.winner_index = winner
	r.method = method
	r.final_health = Vector2i(my_health, 50)
	r.base_health = Vector2i(160, 160)
	r.knockdowns = Vector2i(my_kd, 0)
	return r


func test_rival_generator() -> void:
	fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var avg: float = RivalGenerator.average(gs.fighter)
	for level in [FightOffer.Level.EASY, FightOffer.Level.EVEN, FightOffer.Level.HARD]:
		var total: float = 0.0
		for i in 30:
			var o: FightOffer = RivalGenerator.generate(gs.fighter, level, 25, rng)
			total += RivalGenerator.average(o.rival)
			check(not o.rival.full_name.is_empty() and not o.rival.nickname.is_empty(), "el rival tiene nombre y apodo")
			check(o.wins + o.losses + o.draws >= 1 and o.kos <= o.wins, "récord creíble (%s)" % o.record_text())
			check(FightOffer.PROFILES.has(o.profile_id), "estilo de IA válido")
		var mean: float = total / 30.0
		var expected: float = avg + RivalGenerator.LEVEL_OFFSET[level]
		check(absf(mean - expected) < 1.5, "nivel %d: promedio %.1f (se esperaba ~%.1f)" % [level, mean, expected])
	var veteran: FightOffer = RivalGenerator.generate(gs.fighter, FightOffer.Level.EVEN, 3, rng)
	var rookie: FightOffer = RivalGenerator.generate(gs.fighter, FightOffer.Level.EVEN, 30, rng)
	check(veteran.wins + veteran.losses > rookie.wins + rookie.losses, "un rival top tiene más peleas que uno nuevo")


func test_offers_persist_and_change() -> void:
	fresh()
	var a: Array[FightOffer] = ArenaRules.weekly_offers(gs)
	var b: Array[FightOffer] = ArenaRules.weekly_offers(gs)
	check(not a.is_empty() and a[0].rival.full_name == b[0].rival.full_name, "en la misma semana las ofertas no cambian")
	var d: Dictionary = JSON.parse_string(JSON.stringify(gs.to_dict()))
	gs.clear()
	gs.from_dict(d)
	var c: Array[FightOffer] = ArenaRules.weekly_offers(gs)
	check(c[0].rival.full_name == a[0].rival.full_name and c[0].purse == a[0].purse, "recargar la partida no cambia las ofertas")
	WeekActions.end_week(gs)
	var e: Array[FightOffer] = ArenaRules.weekly_offers(gs)
	check(gs.offers_week == gs.week and e[0].rival.full_name != a[0].rival.full_name, "la semana siguiente hay ofertas nuevas")


func test_choice_and_assigned() -> void:
	fresh()
	var choices: int = 0
	var assigned: int = 0
	for i in 200:
		gs.offers_week = -1
		var offers: Array[FightOffer] = ArenaRules.weekly_offers(gs)
		if offers[0].kind == FightOffer.Kind.CHOICE:
			choices += 1
			check(offers.size() == 3, "eligiendo hay 3 cartas")
			check(offers[0].level == FightOffer.Level.EASY and offers[2].level == FightOffer.Level.HARD, "fácil, pareja y difícil")
			check(offers[0].rival.full_name != offers[1].rival.full_name, "las cartas no repiten rival")
		else:
			assigned += 1
			check(offers.size() == 1 and offers[0].level != FightOffer.Level.EASY, "\"te toca\" es una sola, pareja o difícil")
	check(choices > 80 and assigned > 50, "hay semanas de elegir (%d) y de \"te toca\" (%d)" % [choices, assigned])
	gs.rank = 1
	check(ArenaRules.choice_chance(gs) > ArenaRules.CHOICE_CHANCE, "mejor rankeado, elegís más seguido")
	for o in ArenaRules._generate(gs):
		check(o.rank >= 1, "ningún rival con puesto 0 o negativo")


func test_purse() -> void:
	check(ArenaRules.purse(30, FightOffer.Level.HARD) > ArenaRules.purse(30, FightOffer.Level.EVEN), "el difícil paga más")
	check(ArenaRules.purse(30, FightOffer.Level.EVEN) > ArenaRules.purse(30, FightOffer.Level.EASY), "el fácil paga menos")
	check(ArenaRules.purse(10, FightOffer.Level.EVEN) > ArenaRules.purse(30, FightOffer.Level.EVEN), "mejor rankeado, mejores bolsas")
	check(ArenaRules.purse(30, FightOffer.Level.EVEN) > WeekActions.WEEKLY_EXPENSES, "una bolsa pareja cubre los gastos de la semana")


func offer(level: FightOffer.Level, purse: int = 200) -> FightOffer:
	var o := FightOffer.new()
	o.level = level
	o.purse = purse
	return o


func test_results() -> void:
	fresh()
	var money: int = gs.money
	var s: Dictionary = ArenaRules.apply_result(gs, offer(FightOffer.Level.EVEN), fake_result(0, FightResult.Method.UNANIMOUS_DECISION))
	check(s["won"] and gs.wins == 1 and gs.kos == 0, "ganar por decisión suma una victoria")
	check(gs.money == money + 200 - WeekActions.WEEKLY_EXPENSES, "cobra la bolsa y pasa la semana (gastos)")
	check(gs.rank == 28 and gs.week == 1 and gs.actions_left == gs.ACTIONS_PER_WEEK, "sube 2 puestos y empieza otra semana")
	check(gs.energy == 75, "energía según la salud final (120 de 160 = 75)")

	money = gs.money
	s = ArenaRules.apply_result(gs, offer(FightOffer.Level.HARD), fake_result(0, FightResult.Method.KO))
	check(s["ko"] and gs.kos == 1 and s["pay"] == 250, "ganar por KO paga +25 %")
	check(gs.rank == 23, "un KO a un difícil sube 5 puestos")

	s = ArenaRules.apply_result(gs, offer(FightOffer.Level.EVEN), fake_result(1, FightResult.Method.KO, 0, 2))
	check(not s["won"] and gs.losses == 1 and s["pay"] == 60, "perder paga el 30 %")
	check(gs.rank == 25, "perder baja 2 puestos")
	check(gs.energy == ArenaRules.MIN_ENERGY_AFTER, "noqueado: arranca la semana casi sin energía")

	s = ArenaRules.apply_result(gs, offer(FightOffer.Level.EVEN), fake_result(-1, FightResult.Method.DRAW, 100))
	check(s["draw"] and gs.draws == 1 and s["pay"] == 120 and gs.rank == 25, "empate: 60 %, mismo puesto")

	gs.rank = 1
	ArenaRules.apply_result(gs, offer(FightOffer.Level.HARD), fake_result(0, FightResult.Method.KO))
	check(gs.rank == 1, "el ranking no pasa del #1")
	gs.rank = gs.WORST_RANK
	ArenaRules.apply_result(gs, offer(FightOffer.Level.EVEN), fake_result(1, FightResult.Method.UNANIMOUS_DECISION))
	check(gs.rank == gs.WORST_RANK, "ni baja del último puesto")

	var hurt: FightResult = fake_result(0, FightResult.Method.SPLIT_DECISION, 80, 1)
	check(ArenaRules.energy_after(hurt, false) == 35, "cada knockdown recibido resta energía (50 - 15)")
	check(ArenaRules.energy_after(fake_result(1, FightResult.Method.TKO, 100), true) == ArenaRules.KO_LOSS_MAX_ENERGY, "detenido: como mucho 25")


func test_energy_rules() -> void:
	fresh()
	gs.energy = ArenaRules.MIN_ENERGY - 1
	check(not ArenaRules.can_fight(gs), "sin energía suficiente no se pelea")
	gs.energy = ArenaRules.MIN_ENERGY
	check(ArenaRules.can_fight(gs), "con la mínima se pelea")
	var o: FightOffer = ArenaRules.weekly_offers(gs)[0]
	var tired: FightSetup = ArenaRules.build_fight_setup(gs, o)
	gs.energy = 100
	var rested: FightSetup = ArenaRules.build_fight_setup(gs, o)
	check(tired.fighter_a.max_stamina < rested.fighter_a.max_stamina, "cansado se pelea con menos stamina")
	check(is_equal_approx(tired.fighter_a.max_stamina / rested.fighter_a.max_stamina, ArenaRules.TIRED_STAMINA_MULT), "con 50 de energía, el 85 %")
	check(rested.fighter_a.controller_type == FighterSetup.ControllerType.PLAYER and rested.fighter_b.controller_type == FighterSetup.ControllerType.AI, "vos contra la IA")
	check(rested.fighter_b.ai_profile == o.profile() and rested.fighter_b.ai_difficulty == o.ai_difficulty, "el rival pelea con su estilo y dificultad")
	check(rested.fighter_a.display_name == gs.display_name(), "tu nombre en la pelea")


func test_decline() -> void:
	fresh()
	ArenaRules.weekly_offers(gs)
	ArenaRules.decline(gs)
	check(ArenaRules.weekly_offers(gs).is_empty(), "rechazar deja la semana sin peleas")
	WeekActions.end_week(gs)
	check(not ArenaRules.weekly_offers(gs).is_empty(), "la semana siguiente vuelve a haber")


func test_save_round_trip() -> void:
	var o: FightOffer = RivalGenerator.generate(gs.fighter, FightOffer.Level.HARD, 12, ArenaRules.rng)
	o.kind = FightOffer.Kind.ASSIGNED
	o.purse = 480
	o.ai_difficulty = AIInput.Difficulty.NORMAL
	var back: FightOffer = FightOffer.from_dict(JSON.parse_string(JSON.stringify(o.to_dict())))
	check(back.rival.full_name == o.rival.full_name and back.rival.power == o.rival.power, "la oferta guarda al rival")
	check(back.kind == o.kind and back.level == o.level and back.purse == 480 and back.rank == 12, "y sus datos")
	check(back.ai_difficulty == AIInput.Difficulty.NORMAL and back.profile_id == o.profile_id, "y su IA")


func test_screen() -> void:
	fresh()
	var arena: Node = load("res://career/arena/arena_screen.tscn").instantiate()
	root.add_child(arena)
	check(not arena._fight_buttons.is_empty(), "la Arena muestra ofertas")
	check(not arena._fight_buttons[0].disabled, "descansado, se puede pelear")
	arena.queue_free()
	gs.energy = 10
	arena = load("res://career/arena/arena_screen.tscn").instantiate()
	root.add_child(arena)
	check(arena._fight_buttons[0].disabled, "cansado, los botones están apagados")
	arena.queue_free()


## Pelea real (las dos con IA) armada por build_fight_setup; el resultado se aplica a la carrera.
func test_real_fight() -> void:
	fresh()
	var o: FightOffer = ArenaRules.weekly_offers(gs)[0]
	var fs: FightSetup = ArenaRules.build_fight_setup(gs, o)
	fs.start_with_intro = false
	fs.game_feel = false
	fs.rounds = 1
	fs.round_seconds = 20.0
	fs.fighter_a.controller_type = FighterSetup.ControllerType.AI
	fs.fighter_a.ai_seed = 3
	fs.fighter_b.ai_seed = 4
	var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.set_physics_process(false)
	var holder: Array = [null]
	combat.fight_finished.connect(func(r: FightResult) -> void: holder[0] = r)
	combat.start(fs)
	for i in 60 * 40:
		if holder[0] != null:
			break
		combat._physics_process(0.0)
	check(holder[0] != null, "la pelea termina")
	if holder[0] != null:
		var fights_before: int = gs.wins + gs.losses + gs.draws
		var s: Dictionary = ArenaRules.apply_result(gs, o, holder[0])
		check(gs.wins + gs.losses + gs.draws == fights_before + 1 and gs.week == 1, "el resultado real se anota en la carrera")
		check(s["energy"] >= ArenaRules.MIN_ENERGY_AFTER and s["energy"] <= 100, "energía después en rango")
	combat.queue_free()
