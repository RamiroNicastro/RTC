class_name CombatClock
extends RefCounted
## Reloj propio del combate.
##
## Cuenta los ticks de lógica que pasaron. Se puede pausar o frenar sin tocar Engine.time_scale
## (que afectaría a todo el juego, incluida la UI):
##   - freeze(ticks): HITSTOP. La lógica se congela unos ticks en cada impacto: el golpe "pesa".
##   - slow_motion(ticks, every): cámara lenta. Durante `ticks` ticks reales, la lógica avanza 1 de cada `every`.
## Todo se mide en ticks de física fijos: se comporta igual a cualquier FPS.

var tick: int = 0
var paused: bool = false
## Si es false, freeze() y slow_motion() no hacen nada (las pruebas automáticas lo apagan).
var effects_enabled: bool = true

var _freeze_left: int = 0
var _slow_left: int = 0
var _slow_every: int = 1
var _slow_counter: int = 0


## Congela la lógica `ticks` ticks (si ya estaba congelada, se queda con el mayor).
func freeze(ticks: int) -> void:
	if effects_enabled:
		_freeze_left = maxi(_freeze_left, ticks)


## Cámara lenta: durante `ticks` ticks reales, la lógica avanza 1 de cada `every`.
func slow_motion(ticks: int, every: int) -> void:
	if effects_enabled:
		_slow_left = ticks
		_slow_every = maxi(1, every)
		_slow_counter = 0


func is_frozen() -> bool:
	return _freeze_left > 0


func is_slow() -> bool:
	return _slow_left > 0


## Se llama una vez por cada tick de física. Devuelve true si la lógica debe avanzar en este tick.
func advance() -> bool:
	if paused:
		return false
	if _freeze_left > 0:
		_freeze_left -= 1
		return false
	if _slow_left > 0:
		_slow_left -= 1
		_slow_counter += 1
		if _slow_counter % _slow_every != 0:
			return false
	tick += 1
	return true
