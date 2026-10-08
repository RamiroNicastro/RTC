extends SceneTree
# Prueba automática de la carrera, parte 2: entrenar (principal, secundaria, sparring, rendimientos
# decrecientes, cansancio y deuda), trabajar, descansar, pasar la semana y el hub con sus ventanas.

var failures: PackedStringArray = []
var done: bool = false
var gs: Node


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	gs = root.get_node("GameState")
	var sm: Node = root.get_node("SaveManager")
	sm.folder = "user://test_semana"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sm.folder))
	test_trainings_data()
	test_train_main_and_side()
	test_sparring()
	test_diminishing_returns()
	test_tired_and_debt()
	test_work_and_rest()
	test_week_passes()
	test_progress_reaches_target()
	test_save_keeps_week_state()
	test_hub_windows()
	sm.delete_slot()
	gs.clear()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func fresh(style: StringName = &"balanced") -> void:
	var p := PlayerFighter.new()
	p.full_name = "Test"
	p.style_id = style
	gs.new_career(p)


func test_trainings_data() -> void:
	var ids := {}
	for t in WeekActions.TRAININGS:
		check(not ids.has(t.id), "entrenamiento repetido: %s" % t.id)
		ids[t.id] = true
		check(TranslationServer.translate(t.name_key) != t.name_key, "falta el texto %s" % t.name_key)
		check(t.all_stats or gs.STAT_NAMES.has(t.main_stat), "%s: estadística principal inválida" % t.id)
		check(t.side_stat == &"" or gs.STAT_NAMES.has(t.side_stat), "%s: estadística secundaria inválida" % t.id)
		check(t.energy_cost > 0 and t.energy_cost <= gs.MAX_ENERGY, "%s: costo de energía razonable" % t.id)
	# Cada estadística se puede entrenar en algún ejercicio (Mentón solo como secundaria, a propósito).
	for stat in gs.STAT_NAMES:
		var found: bool = false
		for t in WeekActions.TRAININGS:
			found = found or (not t.all_stats and (t.main_stat == stat or t.side_stat == stat))
		check(found, "hay un ejercicio que entrena %s" % stat)


func test_train_main_and_side() -> void:
	fresh()
	var bag: TrainingData = WeekActions.find_training(&"heavy_bag")
	var power: int = gs.fighter.power
	var chin: int = gs.fighter.chin
	var speed: int = gs.fighter.speed
	var r: Dictionary = WeekActions.train(gs, bag)
	check(gs.fighter.power >= power + 2, "la bolsa sube Potencia (+2 o más con 30)")
	check(gs.fighter.speed == speed, "la bolsa no toca Velocidad")
	check(r["gains"].get(&"power", 0) == gs.fighter.power - power, "el resultado informa lo que subió")
	check(gs.energy == gs.MAX_ENERGY - bag.energy_cost and gs.actions_left == gs.ACTIONS_PER_WEEK - 1, "gasta energía y una acción")
	WeekActions.train(gs, bag)
	check(gs.fighter.chin > chin, "con dos sesiones la secundaria (Mentón) ya subió")


func test_sparring() -> void:
	fresh()
	gs.stat_progress = {}
	var before := {}
	for stat in gs.STAT_NAMES:
		before[stat] = gs.fighter.get(stat)
	var sparring: TrainingData = WeekActions.find_training(&"sparring")
	WeekActions.train(gs, sparring)
	gs.energy = gs.MAX_ENERGY
	WeekActions.train(gs, sparring)
	for stat in gs.STAT_NAMES:
		check(gs.fighter.get(stat) > before[stat], "dos sparrings suben %s" % stat)


func test_diminishing_returns() -> void:
	check(WeekActions.growth(30) > WeekActions.growth(60), "cuesta más subir con 60 que con 30")
	check(WeekActions.growth(99) >= WeekActions.MIN_GROWTH, "nunca deja de subir del todo")
	fresh()
	gs.fighter.power = 99
	gs.stat_progress = {"power": 0.9}
	for i in 3:
		gs.energy = gs.MAX_ENERGY
		WeekActions.train(gs, WeekActions.find_training(&"heavy_bag"))
	check(gs.fighter.power == 100, "llega a 100 y no se pasa")


func test_tired_and_debt() -> void:
	fresh()
	check(is_equal_approx(WeekActions.session_mult(gs), 1.0), "descansado y sin deudas rinde 100 %")
	gs.energy = 30
	var tired: float = WeekActions.session_mult(gs)
	check(tired < 1.0 and tired >= WeekActions.TIRED_MIN_MULT, "cansado rinde menos (%.2f)" % tired)
	gs.energy = gs.MAX_ENERGY
	gs.money = -50
	check(is_equal_approx(WeekActions.session_mult(gs), WeekActions.DEBT_MULT), "con deuda rinde menos")
	gs.energy = 10
	var bag: TrainingData = WeekActions.find_training(&"heavy_bag")
	check(not WeekActions.can_train(gs, bag), "sin energía no se puede entrenar")
	var power: int = gs.fighter.power
	var r: Dictionary = WeekActions.train(gs, bag)
	check(gs.fighter.power == power and gs.actions_left == gs.ACTIONS_PER_WEEK and r["gains"].is_empty(), "y si se intenta, no pasa nada")


func test_work_and_rest() -> void:
	fresh()
	WeekActions.work(gs)
	check(gs.money == gs.START_MONEY + WeekActions.WORK_PAY, "trabajar paga")
	check(gs.energy == gs.MAX_ENERGY - WeekActions.WORK_ENERGY, "trabajar cansa")
	WeekActions.rest(gs)
	check(gs.energy == gs.MAX_ENERGY, "descansar recupera (sin pasarse del máximo)")
	gs.energy = 10
	check(not WeekActions.can_work(gs), "muy cansado no se puede trabajar")


func test_week_passes() -> void:
	fresh()
	var money: int = gs.money
	WeekActions.rest(gs)
	WeekActions.rest(gs)
	check(gs.week == 0, "con acciones restantes la semana no pasa")
	var r: Dictionary = WeekActions.rest(gs)
	check(gs.week == 1 and gs.actions_left == gs.ACTIONS_PER_WEEK, "la tercera acción pasa la semana")
	check(gs.money == money - WeekActions.WEEKLY_EXPENSES and r["week"]["expenses"] == WeekActions.WEEKLY_EXPENSES, "se cobran los gastos")
	gs.week = 51
	gs.actions_left = 1
	r = WeekActions.rest(gs)
	check(r["week"]["birthday"] and gs.age() == 19, "al pasar la semana 52 hay cumpleaños")
	gs.money = 50
	gs.actions_left = 1
	r = WeekActions.rest(gs)
	check(r["week"]["in_debt"] and gs.money < 0, "si no alcanza, queda deuda con aviso")


## "Medio": de 30 a 50 en la estadística principal en unas 10 semanas entrenándola una vez por semana.
func test_progress_reaches_target() -> void:
	fresh()
	var sessions: int = 0
	while gs.fighter.power < 50 and sessions < 40:
		gs.energy = gs.MAX_ENERGY
		gs.money = 1000
		WeekActions.train(gs, WeekActions.find_training(&"heavy_bag"))
		sessions += 1
	check(sessions >= 7 and sessions <= 13, "de 30 a 50 en Potencia en %d sesiones (se buscaban unas 10)" % sessions)


func test_save_keeps_week_state() -> void:
	fresh()
	WeekActions.train(gs, WeekActions.find_training(&"shadow"))
	var d: Dictionary = JSON.parse_string(JSON.stringify(gs.to_dict()))
	var energy: int = gs.energy
	var progress: float = gs.stat_progress.get("speed", 0.0)
	gs.clear()
	gs.from_dict(d)
	check(gs.energy == energy and gs.actions_left == gs.ACTIONS_PER_WEEK - 1, "se guardan energía y acciones")
	check(is_equal_approx(gs.stat_progress.get("speed", 0.0), progress), "se guarda el progreso a medias")


func test_hub_windows() -> void:
	fresh()
	var hub: Control = load("res://career/hub/hub_screen.tscn").instantiate()
	root.add_child(hub)
	hub._on_place(&"gym")
	check(hub._overlay != null, "el gimnasio abre su ventana")
	var power: int = gs.fighter.power
	hub._do_train(WeekActions.find_training(&"heavy_bag"))
	check(gs.fighter.power > power and hub._overlay == null, "entrenar desde el hub sube y cierra la ventana")
	hub._on_place(&"work")
	hub._do_work()
	hub._on_place(&"home")
	hub._do_rest()
	check(gs.week == 1 and hub._overlay != null, "al terminar la semana aparece el resumen")
	check(root.get_node("SaveManager").has_save(), "cada acción guarda la partida")
	hub._close_overlay()
	hub.queue_free()
