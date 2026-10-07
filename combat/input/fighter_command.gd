class_name FighterCommand
extends RefCounted
## Lo que un controlador le pide al Fighter en UN tick.
##
## Regla R1: PlayerInput, DummyInput y (en el Hito F) AIInput producen este MISMO objeto.
## Las direcciones son relativas al rival, no a la pantalla.
## En los próximos hitos se suman jab, fuerte, guardia, esquive y el modificador de cuerpo.

## -1 = retroceder, 0 = quieto, +1 = avanzar hacia el rival.
var move: int = 0
