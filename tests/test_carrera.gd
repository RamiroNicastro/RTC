extends SceneTree
# Prueba automática de la carrera, parte 1: GameState (carrera nueva, edad, to_dict/from_dict),
# SaveManager (guardar, cargar, copia .bak, archivo roto) y que el hub y el título armen sin errores.

var failures: PackedStringArray = []
var done: bool = false
var game_state: Node
var save_manager: Node


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	game_state = root.get_node("GameState")
	save_manager = root.get_node("SaveManager")
	save_manager.folder = "user://test_carrera"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_manager.folder))
	save_manager.delete_slot()
	test_new_career()
	test_age_and_weeks()
	test_dict_round_trip()
	test_save_and_load()
	test_broken_save_uses_backup()
	test_screens()
	save_manager.delete_slot()
	game_state.clear()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func make_player(style: StringName) -> PlayerFighter:
	var p := PlayerFighter.new()
	p.full_name = "Ramiro"
	p.nickname = "La Pantera"
	p.style_id = style
	return p


func test_new_career() -> void:
	game_state.new_career(make_player(&"puncher"))
	var style: FighterStyle = PlayerFighter.find_style(&"puncher")
	check(game_state.active, "la carrera queda activa")
	check(game_state.fighter.full_name == "Ramiro" and game_state.fighter.nickname == "La Pantera", "nombre y apodo")
	check(game_state.fighter.power == roundi(style.power * game_state.START_STAT_RATIO), "arranca con el %d %% de la potencia del estilo" % roundi(game_state.START_STAT_RATIO * 100))
	check(game_state.fighter.power < style.power and game_state.fighter.power > game_state.fighter.speed,
			"un Pegador amateur pega más de lo que corre, pero menos que un Pegador formado")
	check(game_state.money == game_state.START_MONEY and game_state.week == 0, "plata inicial y semana 0")
	check(game_state.wins == 0 and game_state.losses == 0 and game_state.tier == 1, "récord limpio, tier 1")
	check(game_state.display_name() == "\"La Pantera\" Ramiro", "nombre para mostrar")


func test_age_and_weeks() -> void:
	game_state.week = 0
	check(game_state.age() == 18 and game_state.week_of_year() == 1, "arranca con 18 años, semana 1")
	game_state.week = 51
	check(game_state.age() == 18 and game_state.week_of_year() == 52, "semana 52 todavía con 18")
	game_state.week = 52
	check(game_state.age() == 19 and game_state.week_of_year() == 1, "al año cumple 19")
	game_state.week = 0


func test_dict_round_trip() -> void:
	game_state.new_career(make_player(&"stylist"))
	game_state.money = 1234
	game_state.week = 60
	game_state.wins = 3
	game_state.kos = 2
	game_state.fighter.speed = 77
	var d: Dictionary = game_state.to_dict()
	# Pasa por JSON como en el disco.
	d = JSON.parse_string(JSON.stringify(d))
	game_state.clear()
	check(not game_state.active, "clear() deja la carrera inactiva")
	game_state.from_dict(d)
	check(game_state.active and game_state.money == 1234 and game_state.week == 60, "vuelve plata y semana")
	check(game_state.wins == 3 and game_state.kos == 2, "vuelve el récord")
	check(game_state.fighter.speed == 77 and game_state.fighter.full_name == "Ramiro", "vuelven estadísticas y nombre")
	check(game_state.style_id == &"stylist", "vuelve el estilo")
	# Valores fuera de rango se corrigen.
	d["fighter"]["stats"]["power"] = 999
	d["tier"] = 42
	game_state.from_dict(d)
	check(game_state.fighter.power == 100 and game_state.tier == 6, "valores imposibles se recortan")


func test_save_and_load() -> void:
	game_state.clear()
	check(not save_manager.save(), "sin carrera activa no se guarda nada")
	game_state.new_career(make_player(&"brawler"))
	game_state.money = 777
	check(save_manager.save(), "guarda")
	check(save_manager.has_save(), "el slot existe")
	var text: String = FileAccess.get_file_as_string(save_manager.slot_path())
	check(text.contains("\"save_version\""), "el guardado tiene save_version")
	game_state.money = 778
	save_manager.save()
	check(FileAccess.file_exists(save_manager.slot_path() + ".bak"), "al guardar de nuevo queda una copia .bak")
	game_state.clear()
	check(save_manager.load_slot() and game_state.money == 778, "carga lo último guardado")


func test_broken_save_uses_backup() -> void:
	var f := FileAccess.open(save_manager.slot_path(), FileAccess.WRITE)
	f.store_string("{esto no es json")
	f.close()
	game_state.clear()
	check(save_manager.load_slot(), "con el archivo roto, carga la copia .bak")
	check(game_state.money == 777, "la copia .bak es el guardado anterior")
	save_manager.delete_slot()
	check(not save_manager.has_save() and not save_manager.load_slot(), "borrar el slot borra todo")


func test_screens() -> void:
	game_state.new_career(make_player(&"balanced"))
	var hub: Control = load("res://career/hub/hub_screen.tscn").instantiate()
	root.add_child(hub)
	check(hub._bars != null and hub._bars.numbers[0].text == str(game_state.fighter.power), "el hub muestra tus estadísticas")
	hub._on_place(&"shop")
	check(hub._toast.text != "", "tocar un lugar avisa que viene pronto")
	hub.queue_free()
	# Se nombra la pantalla por su script (no por class_name): este script se compila antes que los autoloads.
	var create_script: Script = load("res://ui/create_fighter/create_fighter_screen.gd")
	create_script.set("for_career", true)
	var create: Control = load("res://ui/create_fighter/create_fighter_screen.tscn").instantiate()
	root.add_child(create)
	create._name_edit.text = "   "
	create._nick_edit.text = ""
	create._confirm()
	check(create.is_inside_tree() and create._name_edit.placeholder_text != tr("CREATE_NAME"),
			"en la carrera no se puede empezar sin nombre")
	create_script.call("_reset_static")
	check(create_script.get("for_career") == false, "al salir se apaga el modo carrera")
	create.queue_free()
	var title: Control = load("res://ui/title/title_screen.tscn").instantiate()
	root.add_child(title)
	title.queue_free()
