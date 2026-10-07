extends SceneTree
# Reporte de balance (no es una prueba que falla): corre N peleas IA vs IA y resume cómo terminan.
# Uso:  godot --headless --path . -s res://tests/balance_report.gd

const FIGHTS: int = 20

var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	run()
	quit()
	return true


func run() -> void:
	var methods := {}
	var end_rounds := {1: 0, 2: 0, 3: 0}
	var knockdowns := 0
	var landed := 0
	var thrown := 0
	var seconds := 0.0
	for i in FIGHTS:
		var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
		root.add_child(combat)
		combat.set_physics_process(false)
		var s := FightSetup.new()
		s.start_with_intro = false
		s.fighter_a = FighterSetup.new()
		s.fighter_a.controller_type = FighterSetup.ControllerType.AI
		s.fighter_a.ai_seed = 1000 + i
		s.fighter_b = FighterSetup.new()
		s.fighter_b.controller_type = FighterSetup.ControllerType.AI
		s.fighter_b.ai_seed = 2000 + i
		combat.start(s)
		var limit: int = 60 * 60 * 6
		var fighting_ticks: int = 0
		while combat.result == null and limit > 0:
			combat._physics_process(0.0)
			if combat.fight.is_fighting():
				fighting_ticks += 1
			limit -= 1
		var r: FightResult = combat.result
		var m: String = FightResult.Method.keys()[r.method]
		methods[m] = methods.get(m, 0) + 1
		end_rounds[r.end_round] = end_rounds.get(r.end_round, 0) + 1
		knockdowns += r.knockdowns.x + r.knockdowns.y
		for idx in 2:
			landed += r.stats.totals(idx).landed
			thrown += r.stats.totals(idx).thrown
		seconds += CombatTime.ticks_to_seconds(fighting_ticks)
		root.remove_child(combat)
		combat.free()
	print("=== Balance: %d peleas IA vs IA ===" % FIGHTS)
	print("Cómo terminan: %s" % methods)
	print("Round en que terminan: %s" % end_rounds)
	print("Caídas por pelea: %.1f   precisión: %d%%   duración media peleando: %.0f s" % [
		float(knockdowns) / FIGHTS, roundi(100.0 * landed / maxf(1, thrown)), seconds / FIGHTS])
