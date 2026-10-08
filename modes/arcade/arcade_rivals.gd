class_name ArcadeRivals
extends RefCounted
## Escalera del Modo Arcade: los rivales en orden, de más fácil a más difícil.
##
## Es CONTENIDO de prueba (Fase 1): sirve para la puerta del MVP ("¿quieren jugar otra vez?").
## Quién es cada rival (nombre, color, estilo, estadísticas y golpe característico) está en su ficha
## FighterData, en data/rivals/arcade/. Acá queda solo lo propio del arcade: frase para la pantalla VS,
## dificultad, rounds y desafíos opcionales que dan puntos extra.
## El golpe característico es un fuerte propio que se ve venir (arranque de 20 a 24 ticks).

enum Challenge { NO_KNOCKDOWNS, BY_KO, COUNTERS_3, ACCURACY_50, POWER_5, BODY_6 }

## Puntos extra por cumplir cada desafío.
const CHALLENGE_BONUS: int = 1200


class Rival:
	## Ficha: nombre, apodo, color, estilo de IA, estadísticas y fuerte característico.
	var data: FighterData
	var quote_key: String
	var difficulty: AIInput.Difficulty
	var rounds: int
	var challenges: Array[Challenge] = []
	## Multiplicador de puntos por ganarle.
	var score_mult: float


static func ladder() -> Array[Rival]:
	return [
		_rival("toro", "QUOTE_TORO", AIInput.Difficulty.EASY, 1, [Challenge.NO_KNOCKDOWNS], 1.0),
		_rival("pibe", "QUOTE_PIBE", AIInput.Difficulty.EASY, 1, [Challenge.BY_KO], 1.2),
		_rival("sombra", "QUOTE_SOMBRA", AIInput.Difficulty.NORMAL, 2, [Challenge.BODY_6, Challenge.NO_KNOCKDOWNS], 1.5),
		_rival("martillo", "QUOTE_MARTILLO", AIInput.Difficulty.NORMAL, 2, [Challenge.COUNTERS_3, Challenge.BY_KO], 1.8),
		_rival("profesor", "QUOTE_PROFESOR", AIInput.Difficulty.HARD, 3, [Challenge.ACCURACY_50, Challenge.POWER_5], 2.2),
		_rival("fantasma", "QUOTE_FANTASMA", AIInput.Difficulty.HARD, 3, [Challenge.NO_KNOCKDOWNS, Challenge.BODY_6], 3.0),
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
			return r.winner_index == me and r.is_stoppage()
		Challenge.COUNTERS_3:
			return s.counters >= 3
		Challenge.ACCURACY_50:
			return s.accuracy() >= 0.5
		Challenge.POWER_5:
			return s.landed_power >= 5
		Challenge.BODY_6:
			return s.landed_body >= 6
	return false


static func _rival(file: String, quote_key: String, difficulty: AIInput.Difficulty, rounds: int,
		challenges: Array, score_mult: float) -> Rival:
	var r := Rival.new()
	r.data = load("res://data/rivals/arcade/%s.tres" % file)
	r.quote_key = quote_key
	r.difficulty = difficulty
	r.rounds = rounds
	r.challenges.assign(challenges)
	r.score_mult = score_mult
	return r
