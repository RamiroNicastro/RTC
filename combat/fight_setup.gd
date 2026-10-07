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

@export_group("Rounds")
@export var rounds: int = 3
## Duración de cada round en segundos (arcade: más corto que los 3 minutos reales).
@export var round_seconds: float = 60.0
## true = la pelea arranca con el cartel "ROUND 1 — ¡BOXEEN!". Las pruebas lo apagan.
@export var start_with_intro: bool = true

@export_group("Ring")
## Distancia entre las cuerdas, en unidades de mundo. Es igual en todos los celulares.
@export var ring_width: float = 1500.0
## Distancia inicial entre los centros de los peleadores.
@export var start_distance: float = 420.0
