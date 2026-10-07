class_name Judge
extends RefCounted
## Un juez: puntúa cada round mirando SOLO los eventos registrados en FightStats.
##
## Reglas (sistema de 10 puntos):
##   - Si alguien cayó más veces en el round, el otro gana 10 y el caído recibe 9 menos una por cada caída de diferencia (10-8, 10-7…).
##   - Si no, gana 10-9 el que suma más puntos según los pesos de este juez; si la diferencia es mínima, 10-10.
## Cada juez pesa distinto lo que ve, así puede haber decisiones divididas creíbles.

## Si la diferencia de puntos es menor que esto, el round es parejo (10-10).
const EVEN_ROUND_MARGIN: float = 1.0

var judge_name_key: String = "JUDGE_BALANCED"
## Pesos: cuánto vale para este juez cada cosa.
var w_landed: float = 1.0       ## por golpe limpio
var w_power: float = 1.0        ## extra por golpe de poder limpio
var w_counter: float = 0.5      ## extra por counter
var w_damage: float = 0.05      ## por punto de daño hecho
var w_aggression: float = 0.2   ## por segundo avanzando hacia el rival
var w_block: float = 0.2        ## por golpe del rival bloqueado
var w_dodge: float = 0.5        ## por golpe del rival esquivado


## Los tres jueces de una pelea.
static func make_panel() -> Array[Judge]:
	var balanced := Judge.new()

	var aggressive := Judge.new()
	aggressive.judge_name_key = "JUDGE_AGGRESSIVE"
	aggressive.w_power = 1.6
	aggressive.w_damage = 0.08
	aggressive.w_aggression = 0.45
	aggressive.w_block = 0.1
	aggressive.w_dodge = 0.25

	var technical := Judge.new()
	technical.judge_name_key = "JUDGE_TECHNICAL"
	technical.w_landed = 1.2
	technical.w_power = 0.6
	technical.w_counter = 1.0
	technical.w_aggression = 0.08
	technical.w_block = 0.35
	technical.w_dodge = 0.9

	return [balanced, aggressive, technical]


func points(s: FightStats.FighterRoundStats) -> float:
	return s.landed * w_landed \
			+ s.landed_power * w_power \
			+ s.counters * w_counter \
			+ s.damage_dealt * w_damage \
			+ CombatTime.ticks_to_seconds(s.forward_ticks) * w_aggression \
			+ s.blocks_made * w_block \
			+ s.dodges_made * w_dodge


## Devuelve (puntos de A, puntos de B) para un round.
func score_round(a: FightStats.FighterRoundStats, b: FightStats.FighterRoundStats) -> Vector2i:
	var kd_diff: int = a.knockdowns_suffered - b.knockdowns_suffered
	if kd_diff > 0:
		return Vector2i(9 - kd_diff, 10)
	if kd_diff < 0:
		return Vector2i(10, 9 + kd_diff)
	var pa: float = points(a)
	var pb: float = points(b)
	if absf(pa - pb) < EVEN_ROUND_MARGIN:
		return Vector2i(10, 10)
	return Vector2i(10, 9) if pa > pb else Vector2i(9, 10)
