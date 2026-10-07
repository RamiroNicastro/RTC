class_name FightStats
extends RefCounted
## Registro de lo que PASÓ en la pelea, round por round. Lo consumen los jueces y el FightResult.
##
## Solo cuenta eventos reales del combate. Nunca mira las estadísticas del peleador (Potencia, Técnica…).
## Índices: 0 = fighter_a (izquierda), 1 = fighter_b (derecha).


## Lo que hizo UN peleador en UN round (o en toda la pelea, con totals()).
class FighterRoundStats:
	extends RefCounted
	## Golpes tirados.
	var thrown: int = 0
	## Golpes que conectaron limpios (HIT).
	var landed: int = 0
	var landed_power: int = 0
	var landed_body: int = 0
	var counters: int = 0
	## Golpes propios que el rival bloqueó o esquivó.
	var blocked_by_opponent: int = 0
	var dodged_by_opponent: int = 0
	## Golpes del rival que este peleador bloqueó o esquivó.
	var blocks_made: int = 0
	var dodges_made: int = 0
	var damage_dealt: int = 0
	var knockdowns_suffered: int = 0
	## Ticks avanzando hacia el rival (agresividad).
	var forward_ticks: int = 0

	func accuracy() -> float:
		return float(landed) / float(thrown) if thrown > 0 else 0.0

	func add(o: FighterRoundStats) -> void:
		thrown += o.thrown
		landed += o.landed
		landed_power += o.landed_power
		landed_body += o.landed_body
		counters += o.counters
		blocked_by_opponent += o.blocked_by_opponent
		dodged_by_opponent += o.dodged_by_opponent
		blocks_made += o.blocks_made
		dodges_made += o.dodges_made
		damage_dealt += o.damage_dealt
		knockdowns_suffered += o.knockdowns_suffered
		forward_ticks += o.forward_ticks


## Un elemento por round: [FighterRoundStats de A, FighterRoundStats de B].
var rounds: Array = []


func start_round() -> void:
	rounds.append([FighterRoundStats.new(), FighterRoundStats.new()])


func current(index: int) -> FighterRoundStats:
	if rounds.is_empty():
		start_round()
	return rounds.back()[index]


func round_stats(round_index: int, index: int) -> FighterRoundStats:
	return rounds[round_index][index]


## Suma de todos los rounds de un peleador.
func totals(index: int) -> FighterRoundStats:
	var t := FighterRoundStats.new()
	for r in rounds:
		t.add(r[index])
	return t


func record_attack_started(index: int) -> void:
	current(index).thrown += 1


func record_hit(info: HitInfo, attacker_index: int) -> void:
	var attacker: FighterRoundStats = current(attacker_index)
	var defender: FighterRoundStats = current(1 - attacker_index)
	match info.result:
		HitInfo.Result.HIT:
			attacker.landed += 1
			if info.move.is_power_punch:
				attacker.landed_power += 1
			if info.zone == MoveData.Zone.BODY:
				attacker.landed_body += 1
			if info.counter:
				attacker.counters += 1
			attacker.damage_dealt += info.damage
		HitInfo.Result.BLOCKED:
			attacker.blocked_by_opponent += 1
			attacker.damage_dealt += info.damage
			defender.blocks_made += 1
		HitInfo.Result.DODGED:
			attacker.dodged_by_opponent += 1
			defender.dodges_made += 1


func record_knockdown(index: int) -> void:
	current(index).knockdowns_suffered += 1


func record_forward_tick(index: int) -> void:
	current(index).forward_ticks += 1
