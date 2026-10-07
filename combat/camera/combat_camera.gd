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

var target_zoom: float = 1.0

var _a: Fighter
var _b: Fighter


func setup(a: Fighter, b: Fighter, stage_half_width: float) -> void:
	_a = a
	_b = b
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	limit_left = -int(stage_half_width)
	limit_right = int(stage_half_width)
	# El suavizado lo hacemos nosotros por tick (posición y zoom juntos).
	position_smoothing_enabled = false
	_update_targets()
	zoom = Vector2.ONE * target_zoom
	position = _target_position(target_zoom)
	reset_physics_interpolation()
	make_current()


## Se llama una vez por tick, desde CombatScene.
func follow() -> void:
	var fit_zoom: float = _update_targets()
	var current: float = zoom.x
	var lerp_weight: float = ZOOM_LERP_SAFETY if current > fit_zoom else ZOOM_LERP
	var new_zoom: float = lerpf(current, target_zoom, lerp_weight)
	zoom = Vector2.ONE * new_zoom

	var target_pos: Vector2 = _target_position(new_zoom)
	position = Vector2(lerpf(position.x, target_pos.x, POSITION_LERP), target_pos.y)


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
