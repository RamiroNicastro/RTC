class_name ArcadeRivals
extends RefCounted
## Escalera del Modo Arcade: los rivales en orden, de más fácil a más difícil.
##
## Es CONTENIDO de prueba (Fase 1): sirve para la puerta del MVP ("¿quieren jugar otra vez?").
## Los rivales de la carrera (Fase 2) van a ser FighterData hechos a mano + RivalGenerator.
## Cada rival tiene su golpe característico (un fuerte propio que se ve venir: arranque de 20 a 24 ticks),
## una frase para la pantalla VS y desafíos opcionales que dan puntos extra.

const PRESSURE := preload("res://data/ai_profiles/pressure.tres")
const OUTBOXER := preload("res://data/ai_profiles/outboxer.tres")
const COUNTER := preload("res://data/ai_profiles/counter.tres")

enum Challenge { NO_KNOCKDOWNS, BY_KO, COUNTERS_3, ACCURACY_50, POWER_5, BODY_6 }

## Puntos extra por cumplir cada desafío.
const CHALLENGE_BONUS: int = 1200


class Rival:
	var full_name: String
	var nickname: String
	var quote_key: String
	var profile: AIProfile
	var difficulty: AIInput.Difficulty
	var color: Color
	var rounds: int
	## Su fuerte característico (reemplaza al fuerte común).
	var signature: MoveData
	var challenges: Array[Challenge] = []
	## Multiplicador de puntos por ganarle.
	var score_mult: float


static func ladder() -> Array[Rival]:
	return [
		_rival("Rubén Medina", "El Toro", "QUOTE_TORO", PRESSURE, AIInput.Difficulty.EASY, Color(0.75, 0.25, 0.2), 1,
				"res://data/moves/rivals/toro_embestida.tres", [Challenge.NO_KNOCKDOWNS], 1.0),
		_rival("Nacho Gómez", "El Pibe", "QUOTE_PIBE", OUTBOXER, AIInput.Difficulty.EASY, Color(0.85, 0.6, 0.2), 1,
				"res://data/moves/rivals/pibe_recto.tres", [Challenge.BY_KO], 1.2),
		_rival("Lucho Paz", "Sombra", "QUOTE_SOMBRA", COUNTER, AIInput.Difficulty.NORMAL, Color(0.35, 0.35, 0.45), 2,
				"res://data/moves/rivals/sombra_gancho.tres", [Challenge.BODY_6, Challenge.NO_KNOCKDOWNS], 1.5),
		_rival("Kevin Ruiz", "Martillo", "QUOTE_MARTILLO", PRESSURE, AIInput.Difficulty.NORMAL, Color(0.55, 0.3, 0.6), 2,
				"res://data/moves/rivals/martillo.tres", [Challenge.COUNTERS_3, Challenge.BY_KO], 1.8),
		_rival("Fede Lima", "El Profesor", "QUOTE_PROFESOR", OUTBOXER, AIInput.Difficulty.HARD, Color(0.2, 0.55, 0.45), 3,
				"res://data/moves/rivals/profesor_cruzado.tres", [Challenge.ACCURACY_50, Challenge.POWER_5], 2.2),
		_rival("Darío Ibarra", "El Fantasma", "QUOTE_FANTASMA", COUNTER, AIInput.Difficulty.HARD, Color(0.9, 0.9, 0.95), 3,
				"res://data/moves/rivals/fantasma_contra.tres", [Challenge.NO_KNOCKDOWNS, Challenge.BODY_6], 3.0),
	]


## Texto de un desafío (para la pantalla VS y el conteo).
static func challenge_key(c: Challenge) -> String:
	return "CHALLENGE_" + Challenge.keys()[c]


## ¿Se cumplió el desafío en esta pelea? (El jugador es el índice `me`.)
static func challenge_done(c: Challenge, r: FightResult, me: int) -> bool:
	var s: FightStats.FighterRoundStats = r.stats.totals(me)
	var my_kd: int = r.knockdowns.x if me == 0 else r.knockdowns.y
	match c:
		Challenge.NO_KNOCKDOWNS:
			return my_kd == 0
		Challenge.BY_KO:
			return r.winner_index == me and r.method in [FightResult.Method.KO, FightResult.Method.TKO]
		Challenge.COUNTERS_3:
			return s.counters >= 3
		Challenge.ACCURACY_50:
			return s.accuracy() >= 0.5
		Challenge.POWER_5:
			return s.landed_power >= 5
		Challenge.BODY_6:
			return s.landed_body >= 6
	return false


static func _rival(full_name: String, nickname: String, quote_key: String, profile: AIProfile,
		difficulty: AIInput.Difficulty, color: Color, rounds: int, signature_path: String,
		challenges: Array, score_mult: float) -> Rival:
	var r := Rival.new()
	r.full_name = full_name
	r.nickname = nickname
	r.quote_key = quote_key
	r.profile = profile
	r.difficulty = difficulty
	r.color = color
	r.rounds = rounds
	r.signature = load(signature_path)
	r.challenges.assign(challenges)
	r.score_mult = score_mult
	return r
