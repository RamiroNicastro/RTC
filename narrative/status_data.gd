class_name StatusData
extends Resource
## Una situación que dura varias semanas (de novio, un sponsor, un amuleto…): lo que cambia
## cada semana y unos multiplicadores chicos. Es contenido: data/statuses/.
##
## Los eventos la agregan o la sacan. Los efectos se aplican en EventRunner.apply_week(),
## el entrenamiento (WeekActions.session_mult) y la pelea (ArenaRules.build_fight_setup).
## NO decide cuándo empieza ni cuándo termina: eso lo dicen los eventos o su duración.

@export var id: StringName = &"status"
@export var name_key: String = "STATUS_X"
## Una línea de color para la pantalla "Mi gente" (los números se agregan solos).
@export var desc_key: String = "STATUS_X_DESC"
## true = se muestra en verde; false = en naranja (algo que conviene sacarse de encima).
@export var good: bool = true

@export_group("Cada semana")
@export var weekly_morale: int = 0
@export var weekly_energy: int = 0
@export var weekly_money: int = 0

@export_group("Multiplicadores (1 = sin efecto)")
## Lo que rinde cada sesión de gimnasio.
@export_range(0.5, 1.5) var training_mult: float = 1.0
## Stamina máxima en las peleas de la carrera ("las piernas").
@export_range(0.5, 1.5) var fight_stamina_mult: float = 1.0
