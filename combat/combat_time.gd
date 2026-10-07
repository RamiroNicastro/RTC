class_name CombatTime
## Conversión entre ticks de combate y segundos.
##
## La lógica del combate SIEMPRE cuenta en ticks (enteros), nunca en segundos ni con delta.
## 1 tick = 1 frame a 60 FPS, así el frame data de diseño se lee directo ("jab: 6 de arranque").
## Si algún día cambia el tick rate, solo cambia este archivo.

const TICKS_PER_SECOND: int = 60
const SECONDS_PER_TICK: float = 1.0 / TICKS_PER_SECOND


static func ticks_to_seconds(ticks: int) -> float:
	return ticks * SECONDS_PER_TICK


static func seconds_to_ticks(seconds: float) -> int:
	return roundi(seconds * TICKS_PER_SECOND)
