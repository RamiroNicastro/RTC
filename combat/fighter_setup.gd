class_name FighterSetup
extends Resource
## Datos de UN peleador para UNA pelea.
##
## Lo arma quien lanza el combate (hoy la sandbox; en la Fase 2, la carrera a partir de FighterData).
## Llega con los valores ya calculados: el combate no sabe nada de estadísticas, edad ni compras.

enum ControllerType { PLAYER, DUMMY, AI }

@export var display_name: String = "Peleador"
@export var controller_type: ControllerType = ControllerType.DUMMY
@export var color: Color = Color.WHITE
@export_group("IA")
## Estilo de la IA (data/ai_profiles/). Vacío = estilo equilibrado por defecto.
@export var ai_profile: AIProfile
@export var ai_difficulty: AIInput.Difficulty = AIInput.Difficulty.NORMAL
## Semilla del azar de la IA (0 = distinta cada pelea). Las pruebas usan semillas fijas.
@export var ai_seed: int = 0

@export_group("Cuerpo")
@export var body_width: float = 90.0
@export var body_height: float = 250.0

@export_group("Salud")
@export var max_health: int = 160
## Qué tan fácil se corta (0 = nunca, 1 = normal, 2 = piel frágil). En la carrera puede depender del peleador.
@export var cut_susceptibility: float = 1.0

@export_group("Stamina")
@export var max_stamina: float = 100.0
## Stamina por segundo que se recupera quieto o retrocediendo.
@export var stamina_regen: float = 18.0
## Fracción de la stamina gastada que se vuelve FATIGA (baja el máximo hasta el fin del round).
@export var fatigue_ratio: float = 0.1
## La fatiga nunca baja el máximo más que esta fracción del máximo base.
@export var max_fatigue_ratio: float = 0.25
## Los golpes al cuerpo nunca bajan el máximo más que esta fracción del máximo base.
@export var body_drain_cap_ratio: float = 0.3

@export_group("Guardia")
## Fracción del daño que absorbe la guardia (0.85 = pasa el 15 %).
@export var guard_damage_reduction: float = 0.85
## Lo mismo, pero con poca stamina (la guardia se vuelve más débil).
@export var tired_guard_damage_reduction: float = 0.6

@export_group("Esquive")
@export var dodge_startup_ticks: int = 2
## Ticks en los que la CABEZA es invulnerable (el cuerpo nunca lo es).
@export var dodge_invuln_ticks: int = 10
## Ticks expuesto si el esquive no esquivó nada.
@export var dodge_recovery_ticks: int = 12
@export var dodge_stamina_cost: float = 6.0
## Después de un esquive exitoso, ticks en los que el siguiente golpe es un COUNTER.
@export var counter_window_ticks: int = 30
@export var counter_damage_mult: float = 1.5

@export_group("Golpes")
@export var jab: MoveData = preload("res://data/moves/jab.tres")
@export var power_punch: MoveData = preload("res://data/moves/power.tres")
@export var jab_body: MoveData = preload("res://data/moves/jab_body.tres")
@export var power_body: MoveData = preload("res://data/moves/power_body.tres")

@export_group("Movimiento")
## Unidades de mundo por segundo al avanzar hacia el rival.
@export var forward_speed: float = 260.0
## Unidades de mundo por segundo al retroceder (un poco más lento que avanzar).
@export var backward_speed: float = 220.0
