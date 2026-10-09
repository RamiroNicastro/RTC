extends SceneTree
# Prueba automática de los eventos de la historia: que los datos estén bien escritos (personajes,
# situaciones y textos que existen), condiciones, eventos de una sola vez y con espera, historia
# antes que los secundarios, eventos encadenados y agendados, opciones que cuestan plata,
# moral (deriva, entrenamiento, peleas), relaciones, situaciones (de novio: efectos por semana,
# en el gimnasio y en la pelea), guardado y migración, y la ventana del evento en el hub y la Arena.

var failures: PackedStringArray = []
var done: bool = false
var gs: Node
var sm: Node
var rng := RandomNumberGenerator.new()


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	gs = root.get_node("GameState")
	sm = root.get_node("SaveManager")
	sm.folder = "user://test_eventos"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sm.folder))
	sm.delete_slot()
	rng.seed = 42
	TranslationServer.set_locale("es")
	test_data_is_valid()
	test_first_event_and_chain()
	test_conditions()
	test_story_before_side()
	test_once_and_cooldown()
	test_option_requires_money()
	test_schedule()
	test_fight_events()
	test_morale()
	test_status_novia()
	test_save_and_migration()
	test_hub_shows_event()
	test_arena_event_after_fight()
	sm.delete_slot()
	gs.clear()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func new_career() -> void:
	var p := PlayerFighter.new()
	p.full_name = "Ramiro"
	p.style_id = &"balanced"
	gs.new_career(p)


func index_of(ev: Dictionary, option_text_part: String) -> int:
	for i in ev["options"].size():
		if TranslationServer.translate(EventRunner.option_key(ev, i)).contains(option_text_part):
			return i
	return -1


func test_data_is_valid() -> void:
	var has_text := func(k: String) -> bool: return TranslationServer.translate(k) != k
	var errors: PackedStringArray = EventRunner.validate(has_text)
	check(errors.is_empty(), "los eventos están bien escritos:\n    " + "\n    ".join(errors))
	check(EventRunner.events().size() >= 20, "hay al menos 20 eventos (hay %d)" % EventRunner.events().size())
	var story: int = 0
	for ev in EventRunner.events():
		if String(ev["id"]).begins_with("a1_"):
			story += 1
	check(story >= 5 and story <= 10, "el Acto 1 tiene entre 5 y 10 eventos (plan: 5 a 8 + continuaciones)")


func test_first_event_and_chain() -> void:
	new_career()
	var ev: Dictionary = EventRunner.pick(gs, "hub", {}, rng)
	check(ev.get("id", "") == "a1_club", "al abrir el hub por primera vez sale la llegada al club")
	var s: Dictionary = EventRunner.choose(gs, ev, 1, rng)
	check(gs.relations.get("tito", 0) == 10, "aprender: Tito +10")
	check(gs.flags.has("en_el_club") and gs.flags.has("humilde"), "quedan las marcas de la decisión")
	check(s["next"] == "a1_bruno_intro", "después de Tito aparece Bruno (evento encadenado)")
	check(EventRunner.pick(gs, "hub", {}, rng).is_empty(), "la llegada al club sale una sola vez")
	var bruno: Dictionary = EventRunner.find_event(s["next"])
	EventRunner.choose(gs, bruno, 0, rng)
	check(gs.relations.has("bruno"), "conocer a Bruno lo suma a tu gente")


func test_conditions() -> void:
	new_career()
	var w := {"min_week": 2, "flags": ["x"], "relation_min": {"tito": 10}}
	check(not EventRunner.conditions_met(gs, w), "sin la semana, la marca ni la relación, no se cumple")
	gs.week = 2
	gs.flags.append("x")
	check(not EventRunner.conditions_met(gs, w), "sin conocer a Tito, la relación no alcanza")
	gs.relations["tito"] = 10
	check(EventRunner.conditions_met(gs, w), "con todo, se cumple")
	check(EventRunner.conditions_met(gs, {"outcome": ["win", "win_ko"]}, {"outcome": "win_ko"}), "resultado de pelea en una lista")
	check(not EventRunner.conditions_met(gs, {"outcome": "loss"}, {"outcome": "win"}), "resultado de pelea distinto")
	check(EventRunner.conditions_met(gs, {"min_stat": {"power": 1}}) and not EventRunner.conditions_met(gs, {"min_stat": {"power": 100}}),
			"estadística mínima")
	check(not EventRunner.conditions_met(gs, {"chance": 0.0}, {}, rng) and EventRunner.conditions_met(gs, {"chance": 1.0}, {}, rng),
			"probabilidad 0 nunca, 1 siempre")


func test_story_before_side() -> void:
	new_career()
	gs.flags.append("en_el_club")
	gs.week = 5
	gs.events_seen["a1_club"] = 0
	# En la semana 5 hay eventos secundarios posibles (Sofi, el Chino), pero el guanteo es historia.
	for i in 5:
		var ev: Dictionary = EventRunner.pick(gs, "week", {}, rng)
		check(ev.get("id", "") == "a1_guanteo", "la historia sale antes que los secundarios (salió '%s')" % ev.get("id", ""))
	EventRunner.choose(gs, EventRunner.find_event("a1_guanteo"), 1, rng)
	var ids := {}
	for i in 60:
		var ev: Dictionary = EventRunner.pick(gs, "week", {}, rng)
		ids[ev.get("id", "")] = true
	check(ids.has(""), "a veces no sale nada (los secundarios dependen del azar)")
	check(ids.has("v_chino_negocio") and ids.has("v_sofi_conoce"), "salen secundarios distintos: " + str(ids.keys()))


func test_once_and_cooldown() -> void:
	new_career()
	var ev: Dictionary = EventRunner.find_event("v_bajon")
	gs.morale = 10
	check(EventRunner.is_available(gs, ev), "con la moral por el piso, el Chino te viene a buscar")
	EventRunner.choose(gs, ev, 0, rng)
	gs.morale = 10
	check(not EventRunner.is_available(gs, ev), "pero no la semana siguiente (espera de %d)" % ev["cooldown"])
	gs.week += int(ev["cooldown"])
	check(EventRunner.is_available(gs, ev), "pasada la espera, puede volver a salir")


func test_option_requires_money() -> void:
	new_career()
	var ev: Dictionary = EventRunner.find_event("v_chino_negocio")
	var invest: int = index_of(ev, "200")
	gs.money = 100
	check(not EventRunner.option_available(gs, ev["options"][invest]), "sin $200 no podés invertir")
	gs.money = 300
	check(EventRunner.option_available(gs, ev["options"][invest]), "con $300 sí")


func test_schedule() -> void:
	new_career()
	gs.money = 300
	var ev: Dictionary = EventRunner.find_event("v_chino_negocio")
	EventRunner.choose(gs, ev, index_of(ev, "200"), rng)
	check(gs.money == 100 and gs.scheduled.size() == 1, "invertir cobra y agenda el resultado")
	var due: String = gs.scheduled[0]["id"]
	check(due in ["v_chino_bien", "v_chino_mal"], "el resultado es bueno o malo al azar")
	gs.week += 2
	var got: Dictionary = EventRunner.pick(gs, "week", {}, rng)
	check(got.get("id", "") != due, "antes de tiempo no sale")
	gs.week += 1
	got = EventRunner.pick(gs, "week", {}, rng)
	check(got.get("id", "") == due and gs.scheduled.is_empty(), "a las 3 semanas sale el resultado agendado")


func test_fight_events() -> void:
	new_career()
	gs.wins = 1
	var ev: Dictionary = EventRunner.pick(gs, "fight", {"outcome": "win"}, rng)
	check(ev.get("id", "") == "a1_debut_gano", "ganar el debut tiene su evento")
	gs.wins = 0
	gs.losses = 1
	ev = EventRunner.pick(gs, "fight", {"outcome": "loss_ko"}, rng)
	check(ev.get("id", "") == "a1_debut_perdio", "perder el debut tiene el suyo")
	gs.events_seen["a1_debut_perdio"] = 0
	gs.losses = 3
	var seen := {}
	for i in 30:
		seen[EventRunner.pick(gs, "fight", {"outcome": "loss_ko"}, rng).get("id", "")] = true
	check(seen.has("f_derrota_dura") and not seen.has("f_asado_ko"), "después de un KO en contra, el evento de la derrota (no el asado)")


func test_morale() -> void:
	new_career()
	check(gs.morale == gs.START_MORALE, "la moral arranca en %d" % gs.START_MORALE)
	gs.morale = 80
	WeekActions.end_week(gs)
	check(gs.morale == 80 - EventRunner.MORALE_DRIFT, "la moral alta baja sola un poco cada semana")
	gs.morale = 49
	WeekActions.end_week(gs)
	check(gs.morale == 50, "y la baja sube, sin pasarse de 50")
	gs.energy = 100
	gs.morale = 50
	var normal: float = WeekActions.session_mult(gs)
	gs.morale = 90
	var high: float = WeekActions.session_mult(gs)
	gs.morale = 10
	var low: float = WeekActions.session_mult(gs)
	check(high > normal and low < normal, "con moral alta se entrena mejor y con baja, peor")
	check(high <= 1.15 and low >= 0.8, "pero el efecto es chico")
	EventRunner.add_morale(gs, 500)
	check(gs.morale == gs.MAX_MORALE, "la moral no pasa del máximo")
	check(EventRunner.add_morale(gs, -500) < 0 and gs.morale == 0, "ni baja de 0")
	check(ArenaRules._morale_change(true, false, true, false) > ArenaRules._morale_change(true, false, false, false), "ganar por KO sube más que ganar")
	check(ArenaRules._morale_change(false, false, false, true) < ArenaRules._morale_change(false, false, false, false), "perder por KO duele más")


func test_status_novia() -> void:
	new_career()
	gs.flags.append("sofi_conocida")
	gs.relations["sofi"] = 30
	var ev: Dictionary = EventRunner.pick(gs, "week", {}, rng)
	check(ev.get("id", "") == "v_sofi_novios", "con buena relación con Sofi llega la pregunta")
	gs.relations["tito"] = 0
	EventRunner.choose(gs, ev, 0, rng)
	check(gs.statuses.has("novia") and gs.statuses["novia"] == -1, "de novio, sin fecha de fin")
	check(gs.relations["tito"] < 0, "a Tito no le gusta nada")
	var novia: StatusData = EventRunner.status(&"novia")
	gs.morale = 50
	gs.energy = 50
	var w: Dictionary = WeekActions.end_week(gs)
	check(gs.morale == 50 + novia.weekly_morale, "estar de novio da moral cada semana")
	check(gs.energy == 50 + WeekActions.WEEKEND_ENERGY + novia.weekly_energy, "pero cansa las piernas (menos energía por semana)")
	check(not w["status_lines"].is_empty(), "el resumen de la semana lo cuenta")
	var offer := FightOffer.new()
	offer.rival = FighterData.new()
	offer.rounds = 3
	gs.energy = 100
	var with_novia: float = ArenaRules.build_fight_setup(gs, offer).fighter_a.max_stamina
	gs.statuses.erase("novia")
	var without: float = ArenaRules.build_fight_setup(gs, offer).fighter_a.max_stamina
	check(with_novia < without, "de novio, un poco menos de stamina en la pelea (%.1f contra %.1f)" % [with_novia, without])
	# Si la relación se cae, Sofi corta (es un evento de historia: sale sí o sí).
	gs.statuses["novia"] = -1
	gs.relations["sofi"] = -5
	ev = EventRunner.pick(gs, "week", {}, rng)
	check(ev.get("id", "") == "v_sofi_corte", "con la relación en el piso, Sofi corta")
	EventRunner.choose(gs, ev, 0, rng)
	check(not gs.statuses.has("novia") and gs.flags.has("sofi_ex"), "se termina el noviazgo")
	# Situación con duración: el amuleto dura 6 semanas.
	gs.statuses["amuleto"] = 2
	var r: Dictionary = EventRunner.apply_week(gs)
	check(gs.statuses["amuleto"] == 1 and r["expired"].is_empty(), "a la situación le queda una semana menos")
	r = EventRunner.apply_week(gs)
	check(not gs.statuses.has("amuleto") and r["expired"] == ["amuleto"], "y al llegar a 0 se termina")


func test_save_and_migration() -> void:
	new_career()
	gs.morale = 77
	gs.flags.append("leal_tito")
	gs.relations["tito"] = 33
	gs.statuses["novia"] = -1
	gs.events_seen["a1_club"] = 0
	gs.scheduled.append({"id": "v_chino_bien", "week": 5})
	check(sm.save(), "guarda")
	gs.clear()
	check(gs.flags.is_empty() and gs.relations.is_empty(), "clear() borra la historia")
	check(sm.load_slot(), "carga")
	check(gs.morale == 77 and gs.flags.has("leal_tito") and gs.relations["tito"] == 33, "vuelven la moral, las marcas y las relaciones")
	check(gs.statuses.get("novia", 0) == -1 and gs.events_seen.has("a1_club"), "vuelven las situaciones y los eventos vistos")
	check(gs.scheduled.size() == 1 and gs.scheduled[0]["week"] == 5 and gs.scheduled[0]["week"] is int, "vuelve lo agendado (con números enteros)")
	# Un guardado de la versión 1 (antes de los eventos) arranca la historia de cero.
	var old: Dictionary = gs.to_dict()
	for k in ["morale", "flags", "relations", "statuses", "events_seen", "scheduled"]:
		old.erase(k)
	old["save_version"] = 1
	var f := FileAccess.open(sm.slot_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	check(sm.load_slot(), "carga un guardado viejo")
	check(gs.morale == gs.START_MORALE and gs.flags.is_empty() and gs.events_seen.is_empty(), "el guardado viejo arranca con la historia de cero")


func test_hub_shows_event() -> void:
	new_career()
	sm.save()
	var hub: Control = load("res://career/hub/hub_screen.tscn").instantiate()
	root.add_child(hub)
	var box: EventBox = hub._overlay as EventBox
	check(box != null and box._event["id"] == "a1_club", "al abrir el hub por primera vez aparece Tito")
	if box == null:
		hub.queue_free()
		return
	check(box.option_buttons.size() == 3, "con 3 opciones")
	hub._unhandled_input(esc())
	check(hub._overlay == box, "Esc no saltea el evento")
	var buttons: Array[Button] = box.option_buttons.duplicate()
	buttons[0].pressed.emit()
	buttons[1].pressed.emit()
	check(gs.flags.has("ambicioso") and not gs.flags.has("humilde"), "un doble toque no aplica dos opciones")
	check(box.continue_button != null and gs.flags.has("ambicioso"), "elegir aplica la opción y muestra SEGUIR")
	box.continue_button.pressed.emit()
	var next: EventBox = hub._overlay as EventBox
	check(next != null and next._event["id"] == "a1_bruno_intro", "SEGUIR lleva al evento encadenado (Bruno)")
	if next != null:
		next.option_buttons[1].pressed.emit()
		next.continue_button.pressed.emit()
	check(hub._overlay == null, "al terminar se cierra")
	sm.load_slot()
	check(gs.events_seen.has("a1_bruno_intro"), "y quedó guardado")
	hub._open_people()
	check(hub._overlay != null, "Mi gente abre su ventana")
	hub._close_overlay()
	hub.queue_free()


func test_arena_event_after_fight() -> void:
	new_career()
	gs.wins = 1
	var arena: Node = load("res://career/arena/arena_screen.tscn").instantiate()
	root.add_child(arena)
	arena._last_summary = {"outcome": "win"}
	arena._after_result()
	var box: EventBox = null
	for c in arena._ui.get_children():
		if c is EventBox and not c.is_queued_for_deletion():
			box = c
	check(box != null and box._event["id"] == "a1_debut_gano", "después del debut ganado, Tito en el vestuario")
	arena._unhandled_input(esc())
	check(arena._event_box == box and arena.is_inside_tree(), "Esc no saltea el evento de la Arena")
	arena.queue_free()


func esc() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	return ev
