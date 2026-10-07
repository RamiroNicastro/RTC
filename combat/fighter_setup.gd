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

@export_group("Stamina")
@export var max_stamina: float = 100.0
## Stamina por segundo que se recupera quieto o retrocediendo.
@export var stamina_regen: float = 14.0
## Fracción de la stamina gastada que se vuelve FATIGA (baja el máximo hasta el fin del round).
@export var fatigue_ratio: float = 0.15
## La fatiga nunca baja el máximo más que esta fracción del máximo base.
@export var max_fatigue_ratio: float = 0.25

@export_group("Guardia")
## Fracción del daño que absorbe la guardia (0.85 = pasa el 15 %).
@export var guard_damage_reduction: float = 0.85
## Lo mismo, pero con poca stamina (la guardia se vuelve más débil).
@export var tired_guard_damage_reduction: float = 0.6

@export_group("Golpes")
@export var jab: MoveData = preload("res://data/moves/jab.tres")
@export var power_punch: MoveData = preload("res://data/moves/power.tres")

@export_group("Movimiento")
## Unidades de mundo por segundo al avanzar hacia el rival.
@export var forward_speed: float = 260.0
## Unidades de mundo por segundo al retroceder (un poco más lento que avanzar).
@export var backward_speed: float = 220.0
