class_name CombatClock
extends RefCounted
## Reloj propio del combate.
##
## Cuenta los ticks de lógica que pasaron. Se puede pausar sin tocar Engine.time_scale,
## que afectaría a todo el juego. En el Hito H acá se agrega el hitstop
## (congelar la lógica unos ticks por impacto).

var tick: int = 0
var paused: bool = false


## Se llama una vez por cada tick de física. Devuelve true si la lógica debe avanzar en este tick.
func advance() -> bool:
	if paused:
		return false
	tick += 1
	return true
