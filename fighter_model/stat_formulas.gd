class_name StatFormulas
extends RefCounted
## ÚNICO lugar donde las estadísticas (FighterData) se convierten en números del combate (FighterSetup).
##
## Reglas del plan (sección 5):
## - 50 = el valor base de hoy (el balance ya ajustado no cambia);
## - efectos acotados: cada estadística mueve su parámetro como mucho ±SPREAD (100 contra 1 ≈ 35-40 %, nunca ×3);
## - rendimientos decrecientes: de 50 a 75 se gana más que de 75 a 100.
## NO toca los MoveData compartidos: trabaja sobre copias.

## Cuánto puede mover cada estadística su parámetro (0.15 = de -15 % a +15 %).
const POWER_DAMAGE_SPREAD: float = 0.15
const POWER_GUARD_SPREAD: float = 0.2
const SPEED_STARTUP_SPREAD: float = 0.15
const SPEED_MOVE_SPREAD: float = 0.12
const CARDIO_STAMINA_SPREAD: float = 0.15
const CARDIO_REGEN_SPREAD: float = 0.2
const CHIN_HEALTH_SPREAD: float = 0.15
const TECH_RECOVERY_SPREAD: float = 0.15
const TECH_COST_SPREAD: float = 0.15
const TECH_WHIFF_SPREAD: float = 0.25
const TECH_COUNTER_WINDOW_SPREAD: float = 0.2
## Defensa: cuánto cambia el daño que PASA la guardia (no lo que absorbe).
const DEF_GUARD_LEAK_SPREAD: float = 0.25
const DEF_DODGE_SPREAD: float = 0.2
## Envergadura: alcance de los golpes (±6 %).
const WINGSPAN_REACH_SPREAD: float = 0.06


## Curva de una estadística: 1 → -1, 50 → 0, 100 → +1, con rendimientos decrecientes.
static func curve(stat: int) -> float:
	var t: float = (clampi(stat, 1, 100) - 50) / 50.0
	return sin(t * PI * 0.5)


## Multiplicador: 1.0 con 50; entre (1 - spread) y (1 + spread).
static func mult(stat: int, spread: float) -> float:
	return 1.0 + spread * curve(stat)


## Arma el FighterSetup de una pelea a partir de la ficha. Quien lanza el combate
## completa después lo que no es del peleador (controlador, dificultad de la IA, semilla).
static func build_setup(data: FighterData) -> FighterSetup:
	var s := FighterSetup.new()
	s.display_name = data.full_name
	s.color = data.color
	s.ai_profile = data.ai_profile
	s.cut_susceptibility = data.cut_susceptibility
	if data.signature_move != null:
		s.power_punch = data.signature_move

	# Cardio y mentón.
	s.max_health = roundi(s.max_health * mult(data.chin, CHIN_HEALTH_SPREAD))
	s.max_stamina *= mult(data.cardio, CARDIO_STAMINA_SPREAD)
	s.stamina_regen *= mult(data.cardio, CARDIO_REGEN_SPREAD)

	# Velocidad de movimiento.
	var move_mult: float = mult(data.speed, SPEED_MOVE_SPREAD)
	s.forward_speed *= move_mult
	s.backward_speed *= move_mult

	# Técnica: ventana de counter.
	s.counter_window_ticks = roundi(s.counter_window_ticks * mult(data.technique, TECH_COUNTER_WINDOW_SPREAD))

	# Defensa: menos daño atraviesa la guardia; esquive más largo.
	var leak_mult: float = mult(data.defense, -DEF_GUARD_LEAK_SPREAD)
	s.guard_damage_reduction = 1.0 - (1.0 - s.guard_damage_reduction) * leak_mult
	s.tired_guard_damage_reduction = 1.0 - (1.0 - s.tired_guard_damage_reduction) * leak_mult
	s.dodge_invuln_ticks = roundi(s.dodge_invuln_ticks * mult(data.defense, DEF_DODGE_SPREAD))

	s.jab = _scale_move(s.jab, data)
	s.power_punch = _scale_move(s.power_punch, data)
	s.jab_body = _scale_move(s.jab_body, data)
	s.power_body = _scale_move(s.power_body, data)
	return s


## Copia de un golpe ajustada a las estadísticas del que lo tira.
static func _scale_move(base: MoveData, data: FighterData) -> MoveData:
	var m: MoveData = base.duplicate()
	# Potencia.
	m.damage = maxi(1, roundi(m.damage * mult(data.power, POWER_DAMAGE_SPREAD)))
	m.block_stamina_damage *= mult(data.power, POWER_GUARD_SPREAD)
	# Velocidad: menos arranque (mínimo 1 tick).
	m.startup_ticks = maxi(1, roundi(m.startup_ticks * mult(data.speed, -SPEED_STARTUP_SPREAD)))
	# Técnica: menos recuperación y menos gasto.
	m.recovery_ticks = maxi(1, roundi(m.recovery_ticks * mult(data.technique, -TECH_RECOVERY_SPREAD)))
	m.stamina_cost *= mult(data.technique, -TECH_COST_SPREAD)
	m.whiff_stamina_penalty *= mult(data.technique, -TECH_WHIFF_SPREAD)
	# Envergadura: alcance (la zona ideal se corre igual).
	var reach_mult: float = 1.0 + WINGSPAN_REACH_SPREAD * clampf(data.wingspan, -1.0, 1.0)
	m.reach *= reach_mult
	m.sweet_gap_min *= reach_mult
	m.sweet_gap_max *= reach_mult
	return m
