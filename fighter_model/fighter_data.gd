class_name FighterData
extends Resource
## Ficha de UN peleador: quién es y qué tan bueno es (estadísticas de 1 a 100).
##
## La comparten el combate (a través de StatFormulas) y la carrera (que la guarda y la hace crecer).
## NO tiene números del combate: StatFormulas.build_setup() la convierte en un FighterSetup.
## Con 50 en todo, el peleador queda igual que el FighterSetup por defecto.

@export var full_name: String = "Peleador"
@export var nickname: String = ""
@export var color: Color = Color.WHITE
## Estilo de la IA cuando lo maneja la computadora (vacío = equilibrado).
@export var ai_profile: AIProfile
## Fuerte característico (reemplaza al fuerte común). Vacío = el fuerte común.
@export var signature_move: MoveData

@export_group("Estadísticas (1 a 100)")
## Daño de los golpes y desgaste a la guardia rival.
@export_range(1, 100) var power: int = 50
## Arranque de los golpes y velocidad para moverse.
@export_range(1, 100) var speed: int = 50
## Stamina máxima y qué tan rápido se recupera.
@export_range(1, 100) var cardio: int = 50
## Salud máxima. (Más adelante: umbral de knockdown y levantarse más rápido.)
@export_range(1, 100) var chin: int = 50
## Menos recuperación y menos gasto por golpe; ventana de counter más larga. No cambia el alcance.
@export_range(1, 100) var technique: int = 50
## Guardia que absorbe más y esquive más largo.
@export_range(1, 100) var defense: int = 50

@export_group("Físico (no se entrena)")
## Envergadura: -1 = brazos cortos, 0 = normal, +1 = brazos largos. Cambia un poco el alcance.
@export_range(-1.0, 1.0) var wingspan: float = 0.0
## Qué tan fácil se corta (0 = nunca, 1 = normal, 2 = piel frágil).
@export var cut_susceptibility: float = 1.0
