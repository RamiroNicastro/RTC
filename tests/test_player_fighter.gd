extends SceneTree
# Prueba automática del peleador del jugador: estilos parejos, guardar y cargar, nombres prolijos,
# la ficha toma las estadísticas del estilo y las pantallas (crear peleador y título) arman sin errores.

var failures: PackedStringArray = []
var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	PlayerFighter.path = "user://test_player_fighter.json"
	_remove_save()
	test_styles_are_fair()
	test_save_and_load()
	test_names()
	test_fighter_data_uses_style()
	test_screens()
	_remove_save()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _remove_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerFighter.path))


func test_styles_are_fair() -> void:
	var ids := {}
	var spreads := {}
	for s in PlayerFighter.STYLES:
		check(s.total() == FighterStyle.TOTAL_POINTS, "el estilo %s suma %d (debería sumar %d)" % [s.id, s.total(), FighterStyle.TOTAL_POINTS])
		check(not ids.has(s.id), "id de estilo repetido: %s" % s.id)
		ids[s.id] = true
		spreads[[s.power, s.speed, s.cardio, s.chin, s.technique, s.defense]] = true
		check(TranslationServer.translate(s.name_key) != s.name_key, "falta el texto %s" % s.name_key)
		check(TranslationServer.translate(s.desc_key) != s.desc_key, "falta el texto %s" % s.desc_key)
	check(spreads.size() == PlayerFighter.STYLES.size(), "cada estilo reparte los puntos distinto")
	check(PlayerFighter.STYLES[0].id == &"balanced", "el primer estilo (y el de por defecto) es Equilibrado")


func test_save_and_load() -> void:
	check(not PlayerFighter.exists(), "sin archivo, el peleador todavía no existe")
	var fresh := PlayerFighter.load_fighter()
	check(fresh.style_id == &"balanced" and fresh.full_name.is_empty(), "sin archivo: Equilibrado y sin nombre")
	var p := PlayerFighter.new()
	p.full_name = "Ramiro"
	p.nickname = "La Pantera"
	p.style_id = &"puncher"
	p.save()
	check(PlayerFighter.exists(), "después de guardar, el peleador existe")
	var back := PlayerFighter.load_fighter()
	check(back.full_name == "Ramiro" and back.nickname == "La Pantera" and back.style_id == &"puncher", "guarda y carga nombre, apodo y estilo")
	# Un estilo que ya no existe vuelve a Equilibrado.
	var f := FileAccess.open(PlayerFighter.path, FileAccess.WRITE)
	f.store_string('{"full_name": "X", "style_id": "volador"}')
	f.close()
	check(PlayerFighter.load_fighter().style_id == &"balanced", "estilo desconocido → Equilibrado")


func test_names() -> void:
	check(PlayerFighter.clean_name("   Juan    Pérez  ") == "Juan Pérez", "saca espacios de más")
	check(PlayerFighter.clean_name("x".repeat(40)).length() == PlayerFighter.MAX_NAME_LENGTH, "corta los nombres largos")
	var p := PlayerFighter.new()
	check(p.display_name("VOS") == "VOS", "sin nombre ni apodo se usa el de reserva")
	p.full_name = "Ramiro"
	check(p.display_name("VOS") == "Ramiro", "solo nombre")
	p.nickname = "Pantera"
	check(p.display_name("VOS") == "\"Pantera\" Ramiro", "apodo y nombre")
	p.full_name = ""
	check(p.display_name("VOS") == "\"Pantera\"", "solo apodo")


func test_fighter_data_uses_style() -> void:
	var p := PlayerFighter.new()
	p.style_id = &"brawler"
	var d: FighterData = p.to_fighter_data()
	var s: FighterStyle = PlayerFighter.find_style(&"brawler")
	check(d.power == s.power and d.chin == s.chin and d.defense == s.defense, "la ficha toma las estadísticas del estilo")
	var brawler: FighterSetup = StatFormulas.build_setup(d)
	p.style_id = &"stylist"
	var stylist: FighterSetup = StatFormulas.build_setup(p.to_fighter_data())
	check(brawler.max_health > stylist.max_health, "el Fajador aguanta más que el Estilista")
	check(stylist.jab.startup_ticks <= brawler.jab.startup_ticks and stylist.forward_speed > brawler.forward_speed,
			"el Estilista es más rápido que el Fajador")


func test_screens() -> void:
	var create: Control = load("res://ui/create_fighter/create_fighter_screen.tscn").instantiate()
	root.add_child(create)
	create._select_style(&"counterpuncher")
	check(create._player.style_id == &"counterpuncher", "elegir un estilo lo cambia")
	var number: Label = create._bars[5][1]
	check(number.text == str(PlayerFighter.find_style(&"counterpuncher").defense), "las barras muestran el estilo elegido")
	create.queue_free()
	var title: Control = load("res://ui/title/title_screen.tscn").instantiate()
	root.add_child(title)
	title.queue_free()
