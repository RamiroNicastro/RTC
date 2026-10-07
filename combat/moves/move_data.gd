class_name MoveData
extends Resource
## Datos de UN golpe (jab, fuerte, cuerpo...). Es contenido: se edita en el inspector, no en código.
##
## Los timings van en TICKS (1 tick = 1 frame a 60 FPS) y son la única fuente de verdad del timing.
## La animación (cuando exista) solo representa estos tiempos; nunca los decide.
## Fases: STARTUP (arranque, todavía no pega) → ACTIVE (puede conectar) → RECOVERY (expuesto).

enum Zone { HEAD, BODY }

@export var id: StringName = &"move"
## true para golpes de poder (los jueces los valoran aparte).
@export var is_power_punch: bool = false

@export_group("Timing (ticks)")
@export var startup_ticks: int = 6
@export var active_ticks: int = 2
@export var recovery_ticks: int = 10

@export_group("Alcance y zona")
## Distancia que cubre el golpe desde el borde delantero del cuerpo del atacante
## hasta el borde del cuerpo del rival, en unidades de mundo.
@export var reach: float = 110.0
@export var zone: Zone = Zone.HEAD

@export_group("Distancia justa")
## Zona (espacio borde a borde) donde el golpe pega completo.
@export var sweet_gap_min: float = 0.0
@export var sweet_gap_max: float = 110.0
## Multiplicador de daño si se tira pegado al rival (espacio 0) y en la punta del alcance.
@export var too_close_damage_mult: float = 1.0
@export var at_tip_damage_mult: float = 1.0

@export_group("Impulso, empuje y carga")
## Paso hacia adelante durante el arranque si se venía avanzando (unidades, con impulso completo).
@export var lunge: float = 0.0
## Empuje al rival si conecta (unidades). Si lo bloquean, empuja la mitad.
@export var knockback: float = 16.0
## true = se puede cargar manteniendo el botón (fuerte cargado).
@export var can_charge: bool = false
@export var max_charge_ticks: int = 45
## Con la carga completa: daño extra (0.6 = +60 %) y empuje extra (1.0 = el doble).
@export var charge_damage_bonus: float = 0.6
@export var charge_knockback_bonus: float = 1.0

@export_group("Si conecta")
@export var damage: int = 6
## Ticks que el rival queda aturdido si el golpe conecta.
@export var hitstun_ticks: int = 14
## Golpes al cuerpo: cuánto baja la stamina MÁXIMA del rival si conecta (con tope por pelea).
@export var max_stamina_drain: float = 0.0

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


## Multiplicador de daño según la distancia a la que se tiró (1.0 dentro de la zona ideal).
func range_damage_multiplier(gap: float) -> float:
	if gap < sweet_gap_min:
		return lerpf(too_close_damage_mult, 1.0, clampf(gap / sweet_gap_min, 0.0, 1.0))
	if gap > sweet_gap_max:
		var span: float = maxf(1.0, reach - sweet_gap_max)
		return lerpf(1.0, at_tip_damage_mult, clampf((gap - sweet_gap_max) / span, 0.0, 1.0))
	return 1.0


func total_ticks() -> int:
	return startup_ticks + active_ticks + recovery_ticks
