class_name FighterStyle
extends Resource
## Estilo de pelea que elige el jugador al crear su peleador: un reparto de las 6 estadísticas.
##
## Todos los estilos suman los mismos puntos (TOTAL_POINTS): ninguno es mejor, solo distinto.
## NO es el estilo de la IA (eso es AIProfile): esto solo define estadísticas.

## 50 en cada una de las 6 estadísticas.
const TOTAL_POINTS: int = 300

@export var id: StringName = &"balanced"
@export var name_key: String = "STYLE_BALANCED"
@export var desc_key: String = "STYLE_BALANCED_DESC"

@export_group("Estadísticas (1 a 100)")
@export_range(1, 100) var power: int = 50
@export_range(1, 100) var speed: int = 50
@export_range(1, 100) var cardio: int = 50
@export_range(1, 100) var chin: int = 50
@export_range(1, 100) var technique: int = 50
@export_range(1, 100) var defense: int = 50


func total() -> int:
	return power + speed + cardio + chin + technique + defense


## Copia las estadísticas del estilo en una ficha.
func apply_to(data: FighterData) -> void:
	data.power = power
	data.speed = speed
	data.cardio = cardio
	data.chin = chin
	data.technique = technique
	data.defense = defense
