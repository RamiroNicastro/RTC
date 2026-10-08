class_name FightResult
extends RefCounted
## Salida única del combate (regla R2). Es SOLO datos: no guarda nodos ni referencias a la escena.
##
## La carrera (Fase 2) lo va a leer para pagar la bolsa, sumar fama, registrar el récord, etc.
## Índices: 0 = fighter_a (izquierda), 1 = fighter_b (derecha), -1 = empate.

enum Method { KO, TKO, UNANIMOUS_DECISION, SPLIT_DECISION, MAJORITY_DECISION, DRAW, DOCTOR_STOPPAGE }

var winner_index: int = -1
var method: Method = Method.DRAW
var fighter_names: PackedStringArray = ["", ""]

## Round en que terminó y segundos transcurridos de ese round.
var end_round: int = 1
var end_round_elapsed_seconds: int = 0
var scheduled_rounds: int = 3

## Tarjetas: un elemento por juez, cada uno con un Vector2i (A, B) por round puntuado.
var judge_name_keys: PackedStringArray = []
var judge_cards: Array = []
var judge_totals: Array[Vector2i] = []

## Estadísticas de toda la pelea y por round (las mismas que vieron los jueces).
var stats: FightStats
var knockdowns: Vector2i = Vector2i.ZERO
## Salud al terminar, salud máxima al terminar (daño profundo) y salud base.
var final_health: Vector2i = Vector2i.ZERO
var final_max_health: Vector2i = Vector2i.ZERO
var base_health: Vector2i = Vector2i.ZERO
## Lesiones producidas en la pelea. Hoy: cortes, como {"type": "cut", "fighter": 0|1, "spot": "brow"|"cheek", "severity": float}.
var injuries: Array = []


## true si terminó antes del límite (KO, KO técnico o parada médica).
func is_stoppage() -> bool:
	return method in [Method.KO, Method.TKO, Method.DOCTOR_STOPPAGE]


func is_draw() -> bool:
	return winner_index < 0


func is_decision() -> bool:
	return method in [Method.UNANIMOUS_DECISION, Method.SPLIT_DECISION, Method.MAJORITY_DECISION, Method.DRAW]


func winner_name() -> String:
	return "" if is_draw() else fighter_names[winner_index]


## Calcula ganador y tipo de decisión a partir de los totales de cada juez.
## Devuelve [winner_index, Method].
static func decide(totals: Array[Vector2i]) -> Array:
	var votes_a: int = 0
	var votes_b: int = 0
	for t in totals:
		if t.x > t.y:
			votes_a += 1
		elif t.y > t.x:
			votes_b += 1
	var draws: int = totals.size() - votes_a - votes_b
	if votes_a == votes_b or (draws >= 2):
		return [-1, Method.DRAW]
	var winner: int = 0 if votes_a > votes_b else 1
	var winner_votes: int = maxi(votes_a, votes_b)
	if winner_votes == totals.size():
		return [winner, Method.UNANIMOUS_DECISION]
	if mini(votes_a, votes_b) > 0:
		return [winner, Method.SPLIT_DECISION]
	return [winner, Method.MAJORITY_DECISION]
