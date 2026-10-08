extends SceneTree
# Prueba automática de FighterData + StatFormulas (Fase 2, etapa 1):
# 50 en todo da el peleador de hoy, subir una estadística siempre mejora, los efectos están acotados
# y los MoveData compartidos no se modifican.

var failures: PackedStringArray = []
var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	test_fifty_is_baseline()
	test_curve()
	test_each_stat_improves()
	test_bounded()
	test_shared_moves_untouched()
	test_signature_and_identity()
	test_fight_runs_with_stats()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func data_with(stat: StringName, value: int) -> FighterData:
	var d := FighterData.new()
	d.set(stat, value)
	return d


func test_fifty_is_baseline() -> void:
	var base := FighterSetup.new()
	var s: FighterSetup = StatFormulas.build_setup(FighterData.new())
	check(s.max_health == base.max_health, "50 en Mentón = salud de hoy")
	check(is_equal_approx(s.max_stamina, base.max_stamina), "50 en Cardio = stamina de hoy")
	check(is_equal_approx(s.stamina_regen, base.stamina_regen), "50 en Cardio = regeneración de hoy")
	check(is_equal_approx(s.forward_speed, base.forward_speed), "50 en Velocidad = movimiento de hoy")
	check(is_equal_approx(s.guard_damage_reduction, base.guard_damage_reduction), "50 en Defensa = guardia de hoy")
	check(s.dodge_invuln_ticks == base.dodge_invuln_ticks, "50 en Defensa = esquive de hoy")
	check(s.counter_window_ticks == base.counter_window_ticks, "50 en Técnica = ventana de counter de hoy")
	for pair in [[s.jab, base.jab], [s.power_punch, base.power_punch], [s.jab_body, base.jab_body], [s.power_body, base.power_body]]:
		var m: MoveData = pair[0]
		var b: MoveData = pair[1]
		check(m.damage == b.damage and m.startup_ticks == b.startup_ticks and m.recovery_ticks == b.recovery_ticks,
				"50 en todo = %s igual que hoy" % b.id)
		check(is_equal_approx(m.stamina_cost, b.stamina_cost) and is_equal_approx(m.reach, b.reach),
				"50 en todo = costo y alcance de %s iguales" % b.id)


func test_curve() -> void:
	check(is_equal_approx(StatFormulas.curve(50), 0.0), "curva: 50 → 0")
	check(StatFormulas.curve(100) > 0.99 and StatFormulas.curve(1) < -0.99, "curva: 100 → +1 y 1 → -1")
	check(StatFormulas.curve(75) - StatFormulas.curve(50) > StatFormulas.curve(100) - StatFormulas.curve(75),
			"rendimientos decrecientes: de 50 a 75 se gana más que de 75 a 100")
	var prev: float = -2.0
	for v in range(1, 101):
		check(StatFormulas.curve(v) >= prev, "la curva nunca baja (%d)" % v)
		prev = StatFormulas.curve(v)


func test_each_stat_improves() -> void:
	var lo: FighterSetup
	var hi: FighterSetup
	lo = StatFormulas.build_setup(data_with(&"power", 1))
	hi = StatFormulas.build_setup(data_with(&"power", 100))
	check(hi.power_punch.damage > lo.power_punch.damage, "Potencia: más daño")
	check(hi.jab.block_stamina_damage > lo.jab.block_stamina_damage, "Potencia: más desgaste a la guardia")
	lo = StatFormulas.build_setup(data_with(&"speed", 1))
	hi = StatFormulas.build_setup(data_with(&"speed", 100))
	check(hi.power_punch.startup_ticks < lo.power_punch.startup_ticks, "Velocidad: arranque más corto")
	check(hi.forward_speed > lo.forward_speed, "Velocidad: se mueve más rápido")
	lo = StatFormulas.build_setup(data_with(&"cardio", 1))
	hi = StatFormulas.build_setup(data_with(&"cardio", 100))
	check(hi.max_stamina > lo.max_stamina and hi.stamina_regen > lo.stamina_regen, "Cardio: más stamina y regeneración")
	lo = StatFormulas.build_setup(data_with(&"chin", 1))
	hi = StatFormulas.build_setup(data_with(&"chin", 100))
	check(hi.max_health > lo.max_health, "Mentón: más salud")
	lo = StatFormulas.build_setup(data_with(&"technique", 1))
	hi = StatFormulas.build_setup(data_with(&"technique", 100))
	check(hi.power_punch.recovery_ticks < lo.power_punch.recovery_ticks, "Técnica: menos recuperación")
	check(hi.jab.stamina_cost < lo.jab.stamina_cost, "Técnica: gasta menos")
	check(hi.jab.whiff_stamina_penalty < lo.jab.whiff_stamina_penalty, "Técnica: fallar castiga menos")
	check(hi.counter_window_ticks > lo.counter_window_ticks, "Técnica: ventana de counter más larga")
	check(is_equal_approx(hi.jab.reach, lo.jab.reach), "Técnica: NO cambia el alcance")
	lo = StatFormulas.build_setup(data_with(&"defense", 1))
	hi = StatFormulas.build_setup(data_with(&"defense", 100))
	check(hi.guard_damage_reduction > lo.guard_damage_reduction, "Defensa: la guardia absorbe más")
	check(hi.dodge_invuln_ticks > lo.dodge_invuln_ticks, "Defensa: esquive más largo")
	var short := FighterData.new()
	short.wingspan = -1.0
	var long := FighterData.new()
	long.wingspan = 1.0
	check(StatFormulas.build_setup(long).jab.reach > StatFormulas.build_setup(short).jab.reach, "Envergadura: más alcance")


func test_bounded() -> void:
	var weak := FighterData.new()
	var strong := FighterData.new()
	for stat in [&"power", &"speed", &"cardio", &"chin", &"technique", &"defense"]:
		weak.set(stat, 1)
		strong.set(stat, 100)
	var w: FighterSetup = StatFormulas.build_setup(weak)
	var s: FighterSetup = StatFormulas.build_setup(strong)
	# 100 contra 1: se nota (más de 20 %) pero nunca es ×3 (menos de 50 %).
	for pair in [[s.max_health, w.max_health, "salud"], [s.max_stamina, w.max_stamina, "stamina"],
			[s.power_punch.damage, w.power_punch.damage, "daño"], [s.forward_speed, w.forward_speed, "movimiento"]]:
		var ratio: float = float(pair[0]) / float(pair[1])
		check(ratio > 1.2 and ratio < 1.5, "100 contra 1 en %s: %.2f (debería estar entre 1.2 y 1.5)" % [pair[2], ratio])
	check(s.guard_damage_reduction < 1.0 and w.guard_damage_reduction > 0.5, "la guardia sigue siendo una guardia")
	check(w.jab.startup_ticks >= 1 and s.jab.startup_ticks >= 1, "ningún golpe arranca en 0 ticks")
	check(s.jab.startup_ticks >= 5, "ni con 100 de Velocidad el jab es instantáneo")
	# Valores fuera de rango se recortan.
	check(is_equal_approx(StatFormulas.curve(500), StatFormulas.curve(100)), "más de 100 cuenta como 100")


func test_shared_moves_untouched() -> void:
	var jab: MoveData = preload("res://data/moves/jab.tres")
	var dmg: int = jab.damage
	var startup: int = jab.startup_ticks
	var s: FighterSetup = StatFormulas.build_setup(data_with(&"power", 100))
	StatFormulas.build_setup(data_with(&"speed", 100))
	check(jab.damage == dmg and jab.startup_ticks == startup, "los .tres compartidos no se modifican")
	check(s.jab != jab, "cada peleador recibe su propia copia del golpe")


func test_signature_and_identity() -> void:
	var d := FighterData.new()
	d.full_name = "Rubén Medina"
	d.color = Color.RED
	d.ai_profile = preload("res://data/ai_profiles/pressure.tres")
	d.cut_susceptibility = 1.5
	d.signature_move = preload("res://data/moves/rivals/toro_embestida.tres")
	var s: FighterSetup = StatFormulas.build_setup(d)
	check(s.display_name == "Rubén Medina" and s.color == Color.RED, "nombre y color pasan al setup")
	check(s.ai_profile == d.ai_profile and is_equal_approx(s.cut_susceptibility, 1.5), "estilo y piel pasan al setup")
	check(s.power_punch.id == d.signature_move.id, "el fuerte característico reemplaza al común")


func test_fight_runs_with_stats() -> void:
	var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.set_physics_process(false)
	var fs := FightSetup.new()
	fs.start_with_intro = false
	fs.game_feel = false
	fs.fighter_a = StatFormulas.build_setup(load("res://data/rivals/arcade/toro.tres"))
	fs.fighter_a.controller_type = FighterSetup.ControllerType.AI
	fs.fighter_a.ai_seed = 1
	fs.fighter_b = StatFormulas.build_setup(load("res://data/rivals/arcade/fantasma.tres"))
	fs.fighter_b.controller_type = FighterSetup.ControllerType.AI
	fs.fighter_b.ai_seed = 2
	combat.start(fs)
	for i in 600:
		combat._physics_process(0.0)
	check(combat.fighter_a.health < combat.fighter_a.setup.max_health or combat.fighter_b.health < combat.fighter_b.setup.max_health,
			"dos rivales con fichas pelean 10 segundos y alguien recibe daño")
	combat.queue_free()
