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

@export_group("Si conecta")
@export var damage: int = 6
## Ticks que el rival queda aturdido si el golpe conecta.
@export var hitstun_ticks: int = 14

@export_group("Stamina")
## Lo que cuesta tirarlo.
@export var stamina_cost: float = 5.0
## Costo extra si falla (pegarle al aire cansa más).
@export var whiff_stamina_penalty: float = 2.0

@export_group("Si lo bloquean")
## Stamina que pierde el defensor al bloquearlo.
@export var block_stamina_damage: float = 4.0
## Ticks que el defensor queda trabado en la guardia.
@export var blockstun_ticks: int = 8
## Si es true, al ser bloqueado ROMPE la guardia del defensor.
@export var breaks_guard: bool = false
## Ticks que el defensor queda con la guardia rota y expuesto.
@export var guard_break_ticks: int = 0


func total_ticks() -> int:
	return startup_ticks + active_ticks + recovery_ticks
