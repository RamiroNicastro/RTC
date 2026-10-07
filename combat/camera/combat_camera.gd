class_name CombatCamera
extends Camera2D
## Cámara del combate: sigue el punto medio entre los peleadores con un zoom suave según la distancia.
##
## - El zoom se calcula a partir de la ALTURA de la pantalla, para que los peleadores ocupen
##   siempre la misma proporción (43–47 %) en cualquier celular.
## - Excepción de seguridad: si los dos peleadores no entran a lo ancho, se abre lo necesario.
## - El piso queda siempre a la misma altura de la pantalla (FLOOR_SCREEN_FRACTION), así el zoom no "bambolea".
## - Se actualiza en follow(), una vez por tick fijo de lógica: se comporta igual a cualquier FPS.
## - Solo cambia lo que se VE. El ring, las cuerdas y las distancias reales no cambian.
##
## Efectos (game feel, solo visuales):
##   - shake(trauma): sacudida. Usa "trauma" (0–1) que decae solo; la sacudida es trauma² (los golpes chicos casi no mueven).
##   - kick_zoom(amount): golpecito de zoom hacia adentro que vuelve solo (impactos fuertes).
##   - focus(target, extra_zoom): durante el KO se cierra sobre el caído.

## Proporción de la altura de pantalla que ocupa el peleador cuando están cerca y cuando están lejos.
const FIGHTER_FRACTION_CLOSE: float = 0.47
const FIGHTER_FRACTION_FAR: float = 0.43
## Distancias entre centros en las que se aplica cada proporción (entre medio se interpola suave).
const GAP_CLOSE: float = 160.0
const GAP_FAR: float = 900.0
## Margen libre a los costados de los peleadores (en unidades de mundo) que nunca se corta.
const SIDE_MARGIN: float = 90.0
## Altura de la pantalla (0 = arriba, 1 = abajo) donde queda la línea del piso.
const FLOOR_SCREEN_FRACTION: float = 0.78
## Límites estrictos de zoom.
const ZOOM_MIN: float = 0.6
const ZOOM_MAX: float = 1.6
## Suavizado por tick (0–1). Más alto = más rápido. Como el tick es fijo, no depende de los FPS.
const POSITION_LERP: float = 0.12
const ZOOM_LERP: float = 0.015
## Si hace falta abrir el zoom para no cortar a nadie, se abre más rápido.
const ZOOM_LERP_SAFETY: float = 0.1

## Sacudida: desplazamiento máximo (unidades de pantalla) y cuánto trauma se pierde por segundo.
const SHAKE_MAX_OFFSET: float = 26.0
const SHAKE_MAX_ROTATION: float = 0.025
const TRAUMA_DECAY_PER_SECOND: float = 1.8
## Golpe de zoom: cuánto vuelve por segundo.
const KICK_DECAY_PER_SECOND: float = 4.0

var target_zoom: float = 1.0

var _a: Fighter
var _b: Fighter
var _trauma: float = 0.0
var _kick: float = 0.0
var _focus: Fighter
var _focus_extra_zoom: float = 0.0
var _noise := FastNoiseLite.new()
var _time: float = 0.0


func setup(a: Fighter, b: Fighter, stage_half_width: float) -> void:
	_a = a
	_b = b
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	limit_left = -int(stage_half_width)
	limit_right = int(stage_half_width)
	# El suavizado lo hacemos nosotros por tick (posición y zoom juntos).
	position_smoothing_enabled = false
	_noise.frequency = 2.5
	_update_targets()
	zoom = Vector2.ONE * target_zoom
	position = _target_position(target_zoom)
	reset_physics_interpolation()
	make_current()


## Sacudida: suma trauma (0–1). 0.2 = golpecito, 0.5 = fuerte, 0.9 = KO.
func shake(trauma: float) -> void:
	_trauma = clampf(_trauma + trauma, 0.0, 1.0)


## Golpecito de zoom hacia adentro (0.04 = sutil, 0.1 = fuerte).
func kick_zoom(amount: float) -> void:
	_kick = maxf(_kick, amount)


## Durante el KO: centra y cierra sobre un peleador. null = vuelve a lo normal.
func focus(target: Fighter, extra_zoom: float = 0.35) -> void:
	_focus = target
	_focus_extra_zoom = extra_zoom


## Se llama una vez por tick, desde CombatScene (también durante el hitstop, para que la cámara no se congele).
func follow() -> void:
	var fit_zoom: float = _update_targets()
	var current: float = zoom.x / (1.0 + _kick)
	var goal: float = target_zoom
	if _focus != null:
		goal = minf(ZOOM_MAX, target_zoom * (1.0 + _focus_extra_zoom))
	var lerp_weight: float = ZOOM_LERP_SAFETY if current > fit_zoom and _focus == null else ZOOM_LERP * (3.0 if _focus != null else 1.0)
	var new_zoom: float = lerpf(current, goal, lerp_weight)

	var target_pos: Vector2 = _target_position(new_zoom)
	if _focus != null:
		target_pos.x = _focus.position.x
	position = Vector2(lerpf(position.x, target_pos.x, POSITION_LERP), target_pos.y)

	# Efectos: decaen con el tiempo de física (fijo) → iguales a cualquier FPS.
	var dt: float = CombatTime.SECONDS_PER_TICK
	_time += dt
	_trauma = maxf(0.0, _trauma - TRAUMA_DECAY_PER_SECOND * dt)
	_kick = maxf(0.0, _kick - KICK_DECAY_PER_SECOND * dt * _kick - 0.02 * dt)
	zoom = Vector2.ONE * new_zoom * (1.0 + _kick)
	var shake_amount: float = _trauma * _trauma
	offset = Vector2(
		_noise.get_noise_2d(_time * 60.0, 0.0),
		_noise.get_noise_2d(0.0, _time * 60.0)) * SHAKE_MAX_OFFSET * shake_amount / zoom.x
	rotation = _noise.get_noise_2d(_time * 60.0, 100.0) * SHAKE_MAX_ROTATION * shake_amount


## Calcula target_zoom y devuelve el zoom máximo que permite ver a los dos sin cortar.
func _update_targets() -> float:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var gap: float = absf(_b.position.x - _a.position.x)
	var fighter_height: float = maxf(_a.setup.body_height, _b.setup.body_height)

	# Zoom estético: proporción del peleador según la distancia (curva suave).
	var t: float = smoothstep(GAP_CLOSE, GAP_FAR, gap)
	var fraction: float = lerpf(FIGHTER_FRACTION_CLOSE, FIGHTER_FRACTION_FAR, t)
	var aesthetic_zoom: float = view.y * fraction / fighter_height

	# Zoom de seguridad: que entren los dos cuerpos más el margen a lo ancho.
	var needed_width: float = gap + _a.half_width() + _b.half_width() + SIDE_MARGIN * 2.0
	var fit_zoom: float = view.x / needed_width

	target_zoom = clampf(minf(aesthetic_zoom, fit_zoom), ZOOM_MIN, ZOOM_MAX)
	return fit_zoom


## Centro de cámara para un zoom dado: X en el punto medio, Y con el piso anclado en pantalla.
func _target_position(z: float) -> Vector2:
	var visible_height: float = get_viewport().get_visible_rect().size.y / z
	var floor_y: float = 0.0
	var center_y: float = floor_y - (FLOOR_SCREEN_FRACTION - 0.5) * visible_height
	return Vector2((_a.position.x + _b.position.x) * 0.5, center_y)
