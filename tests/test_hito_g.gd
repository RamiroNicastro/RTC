extends SceneTree
# Prueba automática del Hito G: los tres estilos de IA se reconocen por cómo pelean, y la dificultad importa.
# Cada estilo pelea contra el mismo rival neutral (IA equilibrada) y se miden sus hábitos.

const PROFILES := {
	"presionador": "res://data/ai_profiles/pressure.tres",
	"técnico": "res://data/ai_profiles/outboxer.tres",
	"contragolpeador": "res://data/ai_profiles/counter.tres",
}
const FIGHTS_PER_STYLE: int = 4

var failures: PackedStringArray = []
var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	test_styles_are_recognizable()
	test_difficulty_matters()
	print("RESULTADO: ", "OK" if failures.is_empty() else "FALLÓ:\n  " + "\n  ".join(failures))
	quit()
	return true


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## Pelea: A = rival neutral (IA equilibrada), B = el estilo a medir.
## Devuelve [FightResult, distancia media, ticks avanzando, ticks retrocediendo] (de B).
func fight(profile_b: AIProfile, seed: int, difficulty_b: AIInput.Difficulty = AIInput.Difficulty.NORMAL,
		profile_a: AIProfile = null) -> Array:
	var combat: CombatScene = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.set_physics_process(false)
	var s := FightSetup.new()
	s.start_with_intro = false
	s.game_feel = false
	s.fighter_a = FighterSetup.new()
	s.fighter_a.controller_type = FighterSetup.ControllerType.AI
	s.fighter_a.ai_profile = profile_a
	s.fighter_a.ai_seed = 7000 + seed
	s.fighter_b = FighterSetup.new()
	s.fighter_b.controller_type = FighterSetup.ControllerType.AI
	s.fighter_b.ai_profile = profile_b
	s.fighter_b.ai_difficulty = difficulty_b
	s.fighter_b.ai_seed = 9000 + seed
	combat.start(s)
	var gap_sum: float = 0.0
	var gap_n: int = 0
	var fwd: int = 0
	var back: int = 0
	var limit: int = 60 * 60 * 6
	while combat.result == null and limit > 0:
		combat._physics_process(0.0)
		if combat.fight.is_fighting():
			gap_sum += DistanceHitResolver.edge_gap(combat.fighter_a, combat.fighter_b)
			gap_n += 1
			var b: Fighter = combat.fighter_b
			var dx: float = (b.position.x - b.previous_x) * b.facing
			if dx > 0.01:
				fwd += 1
			elif dx < -0.01:
				back += 1
		limit -= 1
	var res: FightResult = combat.result
	root.remove_child(combat)
	combat.free()
	return [res, gap_sum / maxf(1.0, gap_n), fwd, back]


func test_styles_are_recognizable() -> void:
	var m := {}
	for style in PROFILES:
		var profile: AIProfile = load(PROFILES[style])
		var t := FightStats.FighterRoundStats.new()
		var gap: float = 0.0
		var seconds: float = 0.0
		var fwd: int = 0
		var back: int = 0
		for i in FIGHTS_PER_STYLE:
			var r: Array = fight(profile, i)
			var res: FightResult = r[0]
			t.add(res.stats.totals(1))
			gap += r[1]
			fwd += r[2]
			back += r[3]
			seconds += res.stats.rounds.size() * 60.0
		var landed: float = maxf(1.0, t.landed)
		m[style] = {
			"distancia": gap / FIGHTS_PER_STYLE,
			"avance": float(fwd) / maxf(1.0, fwd + back),
			"tirados/min": t.thrown / seconds * 60.0,
			"poder+cuerpo": float(t.landed_power + t.landed_body) / landed,
			"jab": float(t.landed - t.landed_power - t.landed_body) / landed,
			"esquives/min": t.dodges_made / seconds * 60.0,
			"counters/min": t.counters / seconds * 60.0,
		}
		print("%-16s distancia %5.1f  avanza %3d%% de lo que se mueve  tira %4.1f/min  poder+cuerpo %3d%%  jab %3d%%  esquiva %4.1f/min  counters %4.1f/min" % [
			style, m[style]["distancia"], roundi(m[style]["avance"] * 100.0), m[style]["tirados/min"],
			roundi(m[style]["poder+cuerpo"] * 100.0), roundi(m[style]["jab"] * 100.0),
			m[style]["esquives/min"], m[style]["counters/min"]])
	var p: Dictionary = m["presionador"]
	var o: Dictionary = m["técnico"]
	var c: Dictionary = m["contragolpeador"]
	# Presionador: el que más tira, el que más avanza y el que más poder/cuerpo mete.
	# (No necesariamente el más cercano: sus golpes de poder empujan al rival hacia atrás.)
	check(p["tirados/min"] > o["tirados/min"] and p["tirados/min"] > c["tirados/min"], "el presionador debería ser el que más tira")
	check(p["avance"] > o["avance"], "el presionador debería avanzar más que el técnico")
	check(p["poder+cuerpo"] > o["poder+cuerpo"] and p["poder+cuerpo"] > c["poder+cuerpo"], "el presionador debería meter más poder y cuerpo")
	check(p["distancia"] < o["distancia"], "el presionador debería pelear más cerca que el técnico")
	# Técnico: el que pelea más lejos y vive del jab.
	check(o["distancia"] > p["distancia"] and o["distancia"] > c["distancia"], "el técnico debería pelear más lejos que los otros")
	check(o["jab"] > p["jab"] and o["jab"] > c["jab"], "el técnico debería vivir del jab")
	# Contragolpeador: inicia menos que el presionador; esquiva y contragolpea mucho más.
	check(c["tirados/min"] < p["tirados/min"], "el contragolpeador debería iniciar menos que el presionador")
	check(c["esquives/min"] > p["esquives/min"] and c["esquives/min"] > o["esquives/min"], "el contragolpeador debería esquivar más")
	check(c["counters/min"] > p["counters/min"] and c["counters/min"] > o["counters/min"], "el contragolpeador debería meter más counters")


func test_difficulty_matters() -> void:
	var profile: AIProfile = load(PROFILES["presionador"])
	var score := {}
	for diff in [AIInput.Difficulty.EASY, AIInput.Difficulty.HARD]:
		var points: float = 0.0
		for i in 6:
			var res: FightResult = fight(profile, 50 + i, diff)[0]
			points += 1.0 if res.winner_index == 1 else (0.5 if res.is_draw() else 0.0)
		score[diff] = points
	print("Presionador contra el rival neutral: fácil ganó %.1f de 6, difícil ganó %.1f de 6" % [
		score[AIInput.Difficulty.EASY], score[AIInput.Difficulty.HARD]])
	check(score[AIInput.Difficulty.HARD] > score[AIInput.Difficulty.EASY], "la dificultad difícil debería ganar más que la fácil")
