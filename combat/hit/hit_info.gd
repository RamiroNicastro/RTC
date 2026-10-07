class_name HitInfo
extends RefCounted
## Resultado de un intento de golpe. Es lo ÚNICO que ven el daño, el HUD, las estadísticas y los efectos.
##
## Nadie que lea un HitInfo sabe si se detectó por distancia o por hitboxes.
## BLOCKED y DODGED se usan a partir de los Hitos C y D.

enum Result { HIT, BLOCKED, DODGED, WHIFF }

var result: Result = Result.WHIFF
var zone: MoveData.Zone = MoveData.Zone.HEAD
var counter: bool = false
var damage: int = 0
var move: MoveData
var attacker: Fighter
var defender: Fighter
