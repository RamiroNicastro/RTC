class_name HitInfo
extends RefCounted
## Resultado de un intento de golpe. Es lo ÚNICO que ven el daño, el HUD, las estadísticas y los efectos.
##
## Nadie que lea un HitInfo sabe si se detectó por distancia o por hitboxes.

enum Result { HIT, BLOCKED, DODGED, WHIFF }

var result: Result = Result.WHIFF
var zone: MoveData.Zone = MoveData.Zone.HEAD
## true si el golpe salió como counter después de un esquive exitoso (más daño).
var counter: bool = false
## Daño final (si fue BLOCKED, es lo que pasa la guardia).
var damage: int = 0
## true si este golpe bloqueado rompió la guardia.
var guard_broken: bool = false
var move: MoveData
var attacker: Fighter
var defender: Fighter
