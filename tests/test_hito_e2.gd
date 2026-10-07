extends SceneTree
# Prueba automática del Hito E2: rounds, reloj, descanso, salud en dos capas y TKO por round.

class Scripted extends FighterController:
	var jab_next: bool = false
	var power_next: bool = false
	var mash_every: int = 0
	var _t: int = 0

	func get_command(me: Fighter, _op: Fighter) -> FighterCommand:
		var c := FighterCommand.new()
		if me.state == Fighter.State.KNOCKDOWN and mash_every > 0:
			_t += 1
			c.jab = _t % mash_every == 0
			return c
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
	test_two_layer_health()
	test_rounds_and_break()
	test_clock_stops_during_count()
	test_tko_counts_per_round()
	test_intro_blocks_actions()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func new_combat(round_seconds: float = 60.0, rounds: int = 3, intro: bool = false) -> Array:
	var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.set_physics_process(false)
	var s := FightSetup.new()
	s.start_with_intro = intro
	s.game_feel = false
	s.fighter_a = FighterSetup.new()
	s.fighter_b = FighterSetup.new()
	s.start_distance = 140.0
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


func test_two_layer_health() -> void:
	var r := new_combat()
	var combat: CombatScene = r[0]
	var b := combat.fighter_b
	r[1].power_next = true      # 14 de daño
	step(combat, 25)
	print("Fuerte de 14: salud %d, salud máxima %d (esperado 86 y 95)" % [b.health, b.max_health])
	check(b.health == 86 and b.max_health == 95, "el 35 % del daño debería bajar la salud máxima")
	dispose(combat)


func test_rounds_and_break() -> void:
	var r := new_combat(2.0, 2)
	var combat: CombatScene = r[0]
	var a := combat.fighter_a
	var b := combat.fighter_b
	var fight := combat.fight
	r[1].power_next = true
	step(combat, 25)
	b.fatigue = 20.0
	b.body_drain = 10.0
	b.recover_fatigue(0.0)      # recalcula el máximo de stamina
	var health_before: int = b.health
	var max_before: int = b.max_health
	a.position.x += 200.0
	while fight.phase == FightManager.Phase.FIGHTING:
		step(combat)
	print("Fin del round 1: fase %s, round %d" % [FightManager.Phase.keys()[fight.phase], fight.round_number])
	check(fight.phase == FightManager.Phase.ROUND_BREAK, "al terminar el tiempo debería venir el descanso")
	print("Descanso: salud %d → %d (máx %d), fatiga 20 → %.0f, cuerpo 10 → %.0f, stamina %.0f/%.0f" % [
		health_before, b.health, b.max_health, b.fatigue, b.body_drain, b.stamina, b.max_stamina])
	check(b.health == health_before + roundi((max_before - health_before) * 0.5), "recupera la mitad de la salud perdida")
	check(b.max_health == max_before, "la salud máxima perdida no se recupera")
	check(is_equal_approx(b.fatigue, 10.0) and is_equal_approx(b.body_drain, 5.0), "recupera la mitad de fatiga y cuerpo")
	check(is_equal_approx(b.stamina, b.max_stamina), "la stamina vuelve al máximo")
	check(is_equal_approx(a.position.x, -70.0), "los peleadores vuelven a su lugar")
	step(combat, FightManager.ROUND_BREAK_TICKS + 1)
	check(fight.phase == FightManager.Phase.ROUND_INTRO and fight.round_number == 2, "después del descanso viene el cartel del round 2")
	step(combat, FightManager.ROUND_INTRO_TICKS + 1)
	check(fight.phase == FightManager.Phase.FIGHTING, "después del cartel se pelea el round 2")
	var ended := []
	fight.fight_ended.connect(func(w: Fighter, m: FightManager.Method) -> void: ended.append(m))
	step(combat, CombatTime.seconds_to_ticks(2.0) + 2)
	print("Fin del último round: fase %s, método %s" % [
		FightManager.Phase.keys()[fight.phase], FightManager.Method.keys()[fight.method]])
	check(ended == [FightManager.Method.DECISION], "al terminar el último round la pelea termina por decisión")
	dispose(combat)


func test_clock_stops_during_count() -> void:
	var r := new_combat()
	var combat: CombatScene = r[0]
	combat.fighter_b.health = 3
	r[1].jab_next = true
	step(combat, 8)
	var left: int = combat.fight.round_ticks_left
	step(combat, 200)
	print("Reloj durante la cuenta: %d ticks antes, %d después" % [left, combat.fight.round_ticks_left])
	check(combat.fight.round_ticks_left == left, "el reloj se frena durante la cuenta")
	dispose(combat)


func test_tko_counts_per_round() -> void:
	var r := new_combat(30.0, 3)
	var combat: CombatScene = r[0]
	var sa: Scripted = r[1]
	var b := combat.fighter_b
	r[2].mash_every = 2
	var fight := combat.fight
	# Dos caídas en el round 1.
	for i in 2:
		b.health = 3
		sa.jab_next = true
		step(combat, 8)
		while fight.phase != FightManager.Phase.FIGHTING:
			step(combat)
	# Termina el round 1 y empieza el 2.
	fight.round_ticks_left = 1
	while not (fight.phase == FightManager.Phase.FIGHTING and fight.round_number == 2):
		step(combat)
	# Una caída en el round 2: no debería ser TKO (las del round 1 no cuentan).
	b.health = 3
	sa.jab_next = true
	step(combat, 8)
	print("Caídas: total %d, en este round %d → fase %s" % [b.knockdowns, b.round_knockdowns, FightManager.Phase.keys()[fight.phase]])
	check(fight.phase == FightManager.Phase.COUNT, "con 2 caídas en el round 1 y 1 en el round 2 no es TKO")
	check(b.getup_taps_required() >= 20.0, "levantarse cuesta más según las caídas de toda la pelea (8 + 6×2 + castigo)")
	dispose(combat)


func test_intro_blocks_actions() -> void:
	var r := new_combat(60.0, 3, true)
	var combat: CombatScene = r[0]
	r[1].jab_next = true
	step(combat, 5)
	check(combat.fight.phase == FightManager.Phase.ROUND_INTRO, "la pelea arranca con el cartel del round 1")
	check(combat.fighter_a.state == Fighter.State.IDLE, "durante el cartel no se puede pegar")
	step(combat, FightManager.ROUND_INTRO_TICKS)
	check(combat.fight.phase == FightManager.Phase.FIGHTING, "después del cartel se pelea")
	print("Cartel de inicio: bloquea las acciones y después arranca la pelea")
	dispose(combat)
