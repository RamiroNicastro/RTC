class_name DistanceHitResolver
extends HitResolver
## Detección por distancia (prototipo): el golpe conecta si el espacio entre los bordes
## de los dos cuerpos es menor o igual que el alcance del golpe.
## Si el defensor está en guardia, el golpe queda BLOCKED (la guardia del MVP cubre cabeza y cuerpo).
## Si el defensor está esquivando, los golpes a la CABEZA quedan DODGED; los del cuerpo entran igual.


func resolve(attacker: Fighter, defender: Fighter, move: MoveData) -> HitInfo:
	var info: HitInfo = super.resolve(attacker, defender, move)
	if edge_gap(attacker, defender) > move.reach:
		return info  # WHIFF
	if move.zone == MoveData.Zone.HEAD and defender.is_dodging_head():
		info.result = HitInfo.Result.DODGED
		return info
	info.counter = attacker.is_counter_attack()
	# Daño = base × cansancio × distancia justa × impulso × carga (× counter).
	info.range_mult = move.range_damage_multiplier(edge_gap(attacker, defender))
	info.momentum_mult = attacker.momentum_damage_multiplier()
	info.charge_ratio = attacker.charge_ratio()
	var base_damage: float = move.damage * attacker.damage_multiplier() * info.range_mult \
			* info.momentum_mult * (1.0 + move.charge_damage_bonus * info.charge_ratio)
	if info.counter:
		base_damage *= attacker.setup.counter_damage_mult
	info.knockback = move.knockback * (1.0 + move.charge_knockback_bonus * info.charge_ratio) \
			* maxf(1.0, info.momentum_mult)
	if defender.is_guarding():
		info.result = HitInfo.Result.BLOCKED
		info.damage = roundi(base_damage * (1.0 - defender.guard_damage_reduction()))
		info.guard_broken = move.breaks_guard
		info.knockback *= 0.5
	else:
		info.result = HitInfo.Result.HIT
		info.damage = roundi(base_damage)
	return info


## Espacio libre entre los bordes de los dos cuerpos (0 = se tocan).
static func edge_gap(a: Fighter, b: Fighter) -> float:
	return absf(b.position.x - a.position.x) - a.half_width() - b.half_width()
