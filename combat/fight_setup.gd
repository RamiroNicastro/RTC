class_name FightSetup
extends Resource
## Entrada única del combate (regla R2).
##
## Todo lo que el combate necesita saber llega acá. El combate nunca lee la carrera ni los autoloads.
## Más adelante se agregan los rounds, el tipo de pelea (oficial o sparring), el AIProfile y el equipamiento visual.

## Peleador del lado izquierdo (mira a la derecha).
@export var fighter_a: FighterSetup
## Peleador del lado derecho (mira a la izquierda).
@export var fighter_b: FighterSetup

@export_group("Ring")
## Distancia entre las cuerdas, en unidades de mundo. Es igual en todos los celulares.
@export var ring_width: float = 1500.0
## Distancia inicial entre los centros de los peleadores.
@export var start_distance: float = 420.0
