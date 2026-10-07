class_name FighterCommand
extends RefCounted
## Lo que un controlador le pide al Fighter en UN tick.
##
## Regla R1: PlayerInput, DummyInput y (en el Hito F) AIInput producen este MISMO objeto.
## Las direcciones son relativas al rival, no a la pantalla.

## -1 = retroceder, 0 = quieto, +1 = avanzar hacia el rival.
var move: int = 0
## Golpes: true solo en el tick en que se apretó el botón (no mientras se mantiene).
var jab: bool = false
var power: bool = false
## Guardia: true MIENTRAS se mantiene apretado.
var guard: bool = false
## Esquive: true solo en el tick en que se apretó.
var dodge: bool = false
## Modificador de cuerpo: true MIENTRAS se mantiene. Convierte el jab o el fuerte en golpe al cuerpo.
var body: bool = false
