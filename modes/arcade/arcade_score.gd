class_name ArcadeScore
extends RefCounted
## Puntos del Modo Arcade por una pelea ganada. Lee SOLO el FightResult (datos), como hará la carrera.
##
## Premia lo espectacular y lo bien hecho: terminar rápido por KO, precisión, counters, golpes de poder
## y salir entero. Devuelve el desglose para mostrarlo línea por línea (eso es lo que engancha).

const WIN: int = 1000
const KO_BONUS: int = 1500
const TKO_BONUS: int = 1000
## Por cada round que sobró al ganar antes del límite.
const EARLY_FINISH_PER_ROUND: int = 600
const PER_ACCURACY_POINT: int = 15
const PER_COUNTER: int = 150
const PER_POWER_LANDED: int = 25
const PER_HEALTH_LEFT: int = 6
const PER_KNOCKDOWN_SUFFERED: int = -400
const FLAWLESS_BONUS: int = 2000


## Devuelve [[clave_de_texto, puntos], ...] y al final el total con el multiplicador del rival.
static func breakdown(r: FightResult, player_index: int, score_mult: float) -> Array:
	var lines: Array = []
	var me: FightStats.FighterRoundStats = r.stats.totals(player_index)
	lines.append(["SCORE_WIN", WIN])
	match r.method:
		FightResult.Method.KO:
			lines.append(["SCORE_KO", KO_BONUS])
		FightResult.Method.TKO:
			lines.append(["SCORE_TKO", TKO_BONUS])
	if r.method in [FightResult.Method.KO, FightResult.Method.TKO] and r.end_round < r.scheduled_rounds:
		lines.append(["SCORE_EARLY", (r.scheduled_rounds - r.end_round) * EARLY_FINISH_PER_ROUND])
	lines.append(["SCORE_ACCURACY", roundi(me.accuracy() * 100.0) * PER_ACCURACY_POINT])
	if me.counters > 0:
		lines.append(["SCORE_COUNTERS", me.counters * PER_COUNTER])
	if me.landed_power > 0:
		lines.append(["SCORE_POWER", me.landed_power * PER_POWER_LANDED])
	var health_left: int = r.final_health.x if player_index == 0 else r.final_health.y
	lines.append(["SCORE_HEALTH", health_left * PER_HEALTH_LEFT])
	var my_knockdowns: int = r.knockdowns.x if player_index == 0 else r.knockdowns.y
	if my_knockdowns > 0:
		lines.append(["SCORE_KNOCKDOWNS", my_knockdowns * PER_KNOCKDOWN_SUFFERED])
	var opponent: FightStats.FighterRoundStats = r.stats.totals(1 - player_index)
	if my_knockdowns == 0 and opponent.landed == 0:
		lines.append(["SCORE_FLAWLESS", FLAWLESS_BONUS])
	return lines


static func total(lines: Array, score_mult: float) -> int:
	var sum: int = 0
	for l in lines:
		sum += int(l[1])
	return maxi(0, roundi(sum * score_mult))
