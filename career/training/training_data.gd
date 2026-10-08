class_name TrainingData
extends Resource
## Un ejercicio del gimnasio: qué estadística sube (principal y secundaria) y cuánto cansa.
## Es contenido: se edita en el inspector (data/trainings/). Las cuentas están en WeekActions.

@export var id: StringName = &"training"
@export var name_key: String = "TRAINING_X"
## Estadística que más sube (power, speed, cardio, chin, technique, defense).
@export var main_stat: StringName = &"power"
## Estadística que sube un poco. Vacía = ninguna.
@export var side_stat: StringName = &""
## true = sube un poco TODAS las estadísticas (sparring). Ignora main y side.
@export var all_stats: bool = false
## Energía que gasta (sobre 100).
@export_range(0, 100) var energy_cost: int = 25
