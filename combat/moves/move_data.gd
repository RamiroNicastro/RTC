class_name MoveData
extends Resource
## Datos de UN golpe (jab, fuerte, cuerpo...). Es contenido: se edita en el inspector, no en código.
##
## Los timings van en TICKS (1 tick = 1 frame a 60 FPS) y son la única fuente de verdad del timing.
## La animación (cuando exista) solo representa estos tiempos; nunca los decide.
## Fases: STARTUP (arranque, todavía no pega) → ACTIVE (puede conectar) → RECOVERY (expuesto).

enum Zone { HEAD, BODY }

@export var id: StringName = &"move"

@export_group("Timing (ticks)")
@export var startup_ticks: int = 6
@export var active_ticks: int = 2
@export var recovery_ticks: int = 10

@export_group("Alcance y zona")
## Distancia que cubre el golpe desde el borde delantero del cuerpo del atacante
## hasta el borde del cuerpo del rival, en unidades de mundo.
@export var reach: float = 110.0
@export var zone: Zone = Zone.HEAD

@export_group("Efecto")
@export var damage: int = 6
## Ticks que el rival queda aturdido si el golpe conecta.
@export var hitstun_ticks: int = 14


func total_ticks() -> int:
	return startup_ticks + active_ticks + recovery_ticks
