extends SceneTree
# Prueba automática del Modo Arcade: puntaje por pelea, récords en JSON y la escalera de rivales.

var failures: PackedStringArray = []
var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	test_score()
	test_records()
	test_ladder()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func fake_result(method: FightResult.Method, end_round: int, landed: int, thrown: int, counters: int, kd_player: int) -> FightResult:
	var r := FightResult.new()
	r.method = method
	r.winner_index = 0
	r.end_round = end_round
	r.scheduled_rounds = 3
	r.stats = FightStats.new()
	r.stats.start_round()
	var me: FightStats.FighterRoundStats = r.stats.current(0)
	me.landed = landed
	me.thrown = thrown
	me.counters = counters
	me.landed_power = 4
	r.stats.current(1).landed = 10
	r.knockdowns = Vector2i(kd_player, 1)
	r.final_health = Vector2i(60, 0)
	return r


func test_score() -> void:
	var ko_fast := ArcadeScore.total(ArcadeScore.breakdown(fake_result(FightResult.Method.KO, 1, 20, 40, 2, 0), 0, 1.0), 1.0)
	var decision := ArcadeScore.total(ArcadeScore.breakdown(fake_result(FightResult.Method.UNANIMOUS_DECISION, 3, 20, 40, 2, 0), 0, 1.0), 1.0)
	var sloppy := ArcadeScore.total(ArcadeScore.breakdown(fake_result(FightResult.Method.UNANIMOUS_DECISION, 3, 10, 60, 0, 2), 0, 1.0), 1.0)
	var hard := ArcadeScore.total(ArcadeScore.breakdown(fake_result(FightResult.Method.KO, 1, 20, 40, 2, 0), 0, 3.0), 3.0)
	print("Puntos: KO en el round 1 %d · decisión %d · decisión desprolija %d · KO contra el jefe (x3) %d" % [ko_fast, decision, sloppy, hard])
	check(ko_fast > decision, "un KO rápido debería valer más que una decisión")
	check(decision > sloppy, "pelear prolijo (precisión, sin caídas) debería valer más")
	check(hard == ko_fast * 3, "el multiplicador del rival debería aplicarse")


func test_records() -> void:
	ArcadeRecords.path = "user://test_arcade_records.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ArcadeRecords.path))
	var rec := ArcadeRecords.load_records()
	check(rec.best_score == 0, "sin archivo, los récords arrancan en 0")
	check(rec.register_run(5000, 3, false), "5000 debería ser récord")
	check(not rec.register_run(3000, 2, false), "3000 no supera 5000")
	rec.register_run(9000, 7, true)
	var again := ArcadeRecords.load_records()
	print("Récords guardados y releídos: mejor %d, etapa %d, partidas %d, títulos %d" % [
		again.best_score, again.best_stage, again.runs_played, again.championships])
	check(again.best_score == 9000 and again.best_stage == 7 and again.runs_played == 3 and again.championships == 1,
			"los récords deberían guardarse y leerse del JSON")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ArcadeRecords.path))


func test_ladder() -> void:
	var ladder := ArcadeRivals.ladder()
	check(ladder.size() == 6, "la escalera tiene 6 rivales")
	var styles := {}
	for i in ladder.size():
		styles[ladder[i].profile.style_name_key] = true
		if i > 0:
			check(ladder[i].score_mult > ladder[i - 1].score_mult, "cada rival vale más que el anterior")
			check(ladder[i].difficulty >= ladder[i - 1].difficulty, "la dificultad no baja")
	check(styles.size() == 3, "aparecen los tres estilos")
