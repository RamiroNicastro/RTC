extends SceneTree
# Prueba automática del Hito F: la IA pelea peleas completas, gana a veces, varía y no tiene reflejos sobrehumanos.

## Atacante guionado: se acerca y tira jabs o fuertes a intervalos irregulares (para medir la defensa de la IA).
class Prodder extends FighterController:
	var use_power: bool = false
	var rng := RandomNumberGenerator.new()
	var _next: int = 30
	var _t: int = 0

	func get_command(me: Fighter, op: Fighter) -> FighterCommand:
		_t += 1
		var c := FighterCommand.new()
		var gap: float = absf(op.position.x - me.position.x) - me.half_width() - op.half_width()
		if gap > 60.0:
			c.move = 1
		if _t >= _next and gap <= 100.0:
			_next = _t + rng.randi_range(40, 80)
			if use_power:
				c.power = true
			else:
				c.jab = true
		return c


var failures: PackedStringArray = []
var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	test_ai_vs_ai_full_fights()
	test_ai_beats_passive_dummy()
	test_human_like_reactions()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func new_combat(type_a: FighterSetup.ControllerType, type_b: FighterSetup.ControllerType, seed_a: int, seed_b: int) -> CombatScene:
	var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.set_physics_process(false)
	var s := FightSetup.new()
	s.start_with_intro = false
	s.game_feel = false
	s.fighter_a = FighterSetup.new()
	s.fighter_a.controller_type = type_a
	s.fighter_a.ai_seed = seed_a
	s.fighter_b = FighterSetup.new()
	s.fighter_b.controller_type = type_b
	s.fighter_b.ai_seed = seed_b
	combat.start(s)
	return combat


## Corre hasta que termina la pelea (o un tope de seguridad).
func run_fight(combat: CombatScene) -> FightResult:
	var limit: int = 60 * 60 * 6
	while combat.result == null and limit > 0:
		combat._physics_process(0.0)
		limit -= 1
	return combat.result


func dispose(combat: CombatScene) -> void:
	root.remove_child(combat)
	combat.free()


func test_ai_vs_ai_full_fights() -> void:
	var winners := {}
	var methods := {}
	var all_ended := true
	var min_thrown := 999999
	var min_landed := 999999
	var used := {"jab": 0, "fuerte": 0, "cuerpo": 0, "bloqueos": 0, "esquives": 0}
	for i in 8:
		var combat := new_combat(FighterSetup.ControllerType.AI, FighterSetup.ControllerType.AI, 100 + i, 200 + i)
		var res := run_fight(combat)
		if res == null:
			all_ended = false
			dispose(combat)
			continue
		winners[res.winner_index] = winners.get(res.winner_index, 0) + 1
		var m: String = FightResult.Method.keys()[res.method]
		methods[m] = methods.get(m, 0) + 1
		for idx in 2:
			var t: FightStats.FighterRoundStats = res.stats.totals(idx)
			min_thrown = mini(min_thrown, t.thrown)
			min_landed = mini(min_landed, t.landed)
			used["fuerte"] += t.landed_power
			used["cuerpo"] += t.landed_body
			used["jab"] += t.landed - t.landed_power
			used["bloqueos"] += t.blocks_made
			used["esquives"] += t.dodges_made
		print("  IA vs IA #%d: %s, gana %s, round %d" % [i + 1, m, ["A", "B"][res.winner_index] if res.winner_index >= 0 else "nadie", res.end_round])
		dispose(combat)
	print("IA vs IA: ganadores %s, métodos %s" % [winners, methods])
	print("IA vs IA: mínimo por peleador %d tirados / %d conectados; uso total %s" % [min_thrown, min_landed, used])
	check(all_ended, "todas las peleas IA vs IA deberían terminar")
	check(winners.get(0, 0) > 0 and winners.get(1, 0) > 0, "cada lado debería ganar alguna vez (no hay ventaja fija)")
	check(min_thrown >= 30 and min_landed >= 8, "las dos IAs deberían pelear de verdad (tirar y conectar)")
	for k in used:
		check(used[k] > 0, "la IA debería usar %s" % k)


func test_ai_beats_passive_dummy() -> void:
	var wins := 0
	for i in 3:
		var combat := new_combat(FighterSetup.ControllerType.AI, FighterSetup.ControllerType.DUMMY, 300 + i, 0)
		var res := run_fight(combat)
		if res != null and res.winner_index == 0:
			wins += 1
		dispose(combat)
	print("IA vs dummy quieto: ganó %d de 3" % wins)
	check(wins == 3, "la IA debería ganarle siempre a un dummy que no hace nada")


## Con 12 ticks de reacción, la IA no llega a defender un jab (6 de arranque) tan seguido como un fuerte (16).
func test_human_like_reactions() -> void:
	var rates: Array[float] = []
	for use_power in [false, true]:
		var counts := [0, 0]  # [defendidos, total] (array: las lambdas no pueden modificar ints sueltos)
		for i in 3:
			var combat := new_combat(FighterSetup.ControllerType.DUMMY, FighterSetup.ControllerType.AI, 0, 400 + i)
			var prodder := Prodder.new()
			prodder.use_power = use_power
			prodder.rng.seed = 500 + i
			combat.controller_a = prodder
			combat.hit_resolved.connect(func(info: HitInfo) -> void:
				if info.attacker == combat.fighter_a:
					counts[1] += 1
					if info.result != HitInfo.Result.HIT:
						counts[0] += 1)
			for t in 60 * 40:
				if combat.result != null:
					break
				combat._physics_process(0.0)
			dispose(combat)
		rates.append(float(counts[0]) / maxf(1.0, float(counts[1])))
	print("Defensa de la IA: %d%% de los jabs, %d%% de los fuertes" % [roundi(rates[0] * 100.0), roundi(rates[1] * 100.0)])
	check(rates[0] < 0.45, "la IA no debería frenar casi todos los jabs (reflejos humanos)")
	check(rates[1] > rates[0] + 0.15, "la IA debería defender mejor los fuertes, que se ven venir")
