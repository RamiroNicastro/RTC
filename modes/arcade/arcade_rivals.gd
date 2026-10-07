class_name ArcadeRivals
extends RefCounted
## Escalera del Modo Arcade: los rivales en orden, de más fácil a más difícil.
##
## Es CONTENIDO de prueba (Fase 1): sirve para la puerta del MVP ("¿quieren jugar otra vez?").
## Los rivales de la carrera (Fase 2) van a ser FighterData hechos a mano + RivalGenerator.

const PRESSURE := preload("res://data/ai_profiles/pressure.tres")
const OUTBOXER := preload("res://data/ai_profiles/outboxer.tres")
const COUNTER := preload("res://data/ai_profiles/counter.tres")


class Rival:
	var full_name: String
	var nickname: String
	var profile: AIProfile
	var difficulty: AIInput.Difficulty
	var color: Color
	var rounds: int
	## Multiplicador de puntos por ganarle.
	var score_mult: float


static func ladder() -> Array[Rival]:
	return [
		_rival("Nacho Gómez", "El Pibe", OUTBOXER, AIInput.Difficulty.EASY, Color(0.85, 0.6, 0.2), 2, 1.0),
		_rival("Rubén Medina", "El Toro", PRESSURE, AIInput.Difficulty.EASY, Color(0.75, 0.25, 0.2), 2, 1.2),
		_rival("Lucho Paz", "Sombra", COUNTER, AIInput.Difficulty.NORMAL, Color(0.35, 0.35, 0.45), 3, 1.5),
		_rival("Kevin Ruiz", "Martillo", PRESSURE, AIInput.Difficulty.NORMAL, Color(0.55, 0.3, 0.6), 3, 1.8),
		_rival("Fede Lima", "El Profesor", OUTBOXER, AIInput.Difficulty.HARD, Color(0.2, 0.55, 0.45), 3, 2.2),
		_rival("Darío Ibarra", "El Fantasma", COUNTER, AIInput.Difficulty.HARD, Color(0.9, 0.9, 0.95), 3, 3.0),
	]


static func _rival(full_name: String, nickname: String, profile: AIProfile, difficulty: AIInput.Difficulty,
		color: Color, rounds: int, score_mult: float) -> Rival:
	var r := Rival.new()
	r.full_name = full_name
	r.nickname = nickname
	r.profile = profile
	r.difficulty = difficulty
	r.color = color
	r.rounds = rounds
	r.score_mult = score_mult
	return r
