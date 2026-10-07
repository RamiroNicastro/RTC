class_name HitResolver
extends RefCounted
## Interfaz de detección de impactos: decide si un golpe en fase ACTIVE conecta.
##
## Implementaciones:
##   - DistanceHitResolver (prototipo): compara distancias.
##   - HitboxHitResolver (futuro): hitboxes y hurtboxes encendidas por los ticks del MoveData, nunca por la animación.
## Solo DECIDE. No aplica daño ni cambia estados (eso lo hace CombatScene con el HitInfo).


func resolve(attacker: Fighter, defender: Fighter, move: MoveData) -> HitInfo:
	var info := HitInfo.new()
	info.attacker = attacker
	info.defender = defender
	info.move = move
	info.zone = move.zone
	info.result = HitInfo.Result.WHIFF
	return info
