class_name FighterSetup
extends Resource
## Datos de UN peleador para UNA pelea.
##
## Lo arma quien lanza el combate (hoy la sandbox; en la Fase 2, la carrera a partir de FighterData).
## Llega con los valores ya calculados: el combate no sabe nada de estadísticas, edad ni compras.

enum ControllerType { PLAYER, DUMMY }

@export var display_name: String = "Peleador"
@export var controller_type: ControllerType = ControllerType.DUMMY
@export var color: Color = Color.WHITE

@export_group("Cuerpo")
@export var body_width: float = 90.0
@export var body_height: float = 250.0

@export_group("Salud")
@export var max_health: int = 100

@export_group("Golpes")
@export var jab: MoveData = preload("res://data/moves/jab.tres")

@export_group("Movimiento")
## Unidades de mundo por segundo al avanzar hacia el rival.
@export var forward_speed: float = 260.0
## Unidades de mundo por segundo al retroceder (un poco más lento que avanzar).
@export var backward_speed: float = 220.0
