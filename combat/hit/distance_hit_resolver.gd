class_name DistanceHitResolver
extends HitResolver
## Detección por distancia (prototipo): el golpe conecta si el espacio entre los bordes
## de los dos cuerpos es menor o igual que el alcance del golpe.
## Si el defensor está en guardia, el golpe queda BLOCKED (la guardia del MVP cubre cabeza y cuerpo).


func resolve(attacker: Fighter, defender: Fighter, move: MoveData) -> HitInfo:
	var info: HitInfo = super.resolve(attacker, defender, move)
	if edge_gap(attacker, defender) > move.reach:
		return info  # WHIFF
	var base_damage: float = move.damage * attacker.damage_multiplier()
	if defender.is_guarding():
		info.result = HitInfo.Result.BLOCKED
		info.damage = roundi(base_damage * (1.0 - defender.guard_damage_reduction()))
		info.guard_broken = move.breaks_guard
	else:
		info.result = HitInfo.Result.HIT
		info.damage = roundi(base_damage)
	return info


## Espacio libre entre los bordes de los dos cuerpos (0 = se tocan).
static func edge_gap(a: Fighter, b: Fighter) -> float:
	return absf(b.position.x - a.position.x) - a.half_width() - b.half_width()
