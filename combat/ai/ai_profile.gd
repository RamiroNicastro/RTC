class_name AIProfile
extends Resource
## Estilo de pelea de una IA. Es contenido: cada estilo es un .tres en data/ai_profiles/.
##
## Solo son números y probabilidades: AIInput es el mismo para todos los estilos.
## La dificultad (FighterSetup.ai_difficulty) se aplica encima, cambiando sobre todo el tiempo de reacción.

## Clave de texto del estilo (i18n/textos.csv), para mostrarlo en pantalla.
@export var style_name_key: String = "AI_STYLE_BALANCED"

@export_group("Reflejos")
## Ticks de retraso con los que ve al rival (12 = 0,2 s).
@export var reaction_ticks: int = 12
## Cada cuántos ticks re-piensa qué hacer.
@export var decision_interval_ticks: int = 7

@export_group("Distancia y ataque")
## 0–1: ganas de avanzar y de atacar cuando está en rango.
@export_range(0.0, 1.0) var aggression: float = 0.55
## Espacio borde a borde que intenta mantener (el jab llega a 110).
@export var preferred_gap: float = 80.0
## Si está más lejos que su distancia: probabilidad de acercarse (en cada decisión).
@export_range(0.0, 1.0) var approach_chance: float = 0.68
## Si está más cerca que su distancia: probabilidad de alejarse.
@export_range(0.0, 1.0) var retreat_chance: float = 0.55
## Al atacar: probabilidad de usar fuerte o cuerpo en vez de jab.
@export_range(0.0, 1.0) var power_chance: float = 0.22
@export_range(0.0, 1.0) var body_chance: float = 0.2
## Al tirar un fuerte: probabilidad de cargarlo (es un aviso grande: invita a esquivar y contragolpear).
@export_range(0.0, 1.0) var charge_chance: float = 0.08
## Después de atacar: probabilidad de salir hacia atrás ("pegar y salir").
@export_range(0.0, 1.0) var step_back_after_attack: float = 0.0

@export_group("Defensa")
## Al ver venir un golpe a tiempo: probabilidad de cubrirse o de esquivar.
@export_range(0.0, 1.0) var block_chance: float = 0.45
@export_range(0.0, 1.0) var dodge_chance: float = 0.25
## Cerca del rival y sin atacar: probabilidad de mantener la guardia arriba mientras mide.
@export_range(0.0, 1.0) var guard_up_chance: float = 0.4

@export_group("Lectura")
## 0–1: qué tan bien aprende tus patrones. Si repetís un golpe, lo anticipa y se defiende mejor.
@export_range(0.0, 1.0) var read_skill: float = 0.6

@export_group("Castigo")
## Al ver al rival expuesto (recuperación, guardia rota, esquive fallado): probabilidad de castigar.
@export_range(0.0, 1.0) var punish_chance: float = 0.65
## Con un counter listo (después de esquivar): probabilidad de tirar un fuerte en vez de un jab.
@export_range(0.0, 1.0) var counter_with_power_chance: float = 0.2

@export_group("Cansancio y lona")
## Con poca stamina: probabilidad de priorizar retroceder y cubrirse.
@export_range(0.0, 1.0) var tired_caution: float = 0.75
@export var getup_taps_per_second: float = 6.0
