class_name DistanceHitResolver
extends HitResolver
## Detección por distancia (prototipo): el golpe conecta si el espacio entre los bordes
## de los dos cuerpos es menor o igual que el alcance del golpe.


func resolve(attacker: Fighter, defender: Fighter, move: MoveData) -> HitInfo:
	var info: HitInfo = super.resolve(attacker, defender, move)
	if edge_gap(attacker, defender) > move.reach:
		return info  # WHIFF
	info.result = HitInfo.Result.HIT
	info.damage = move.damage
	return info


## Espacio libre entre los bordes de los dos cuerpos (0 = se tocan).
static func edge_gap(a: Fighter, b: Fighter) -> float:
	return absf(b.position.x - a.position.x) - a.half_width() - b.half_width()
