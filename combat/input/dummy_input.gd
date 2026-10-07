class_name DummyInput
extends FighterController
## Rival de práctica: hoy se queda quieto.
##
## En el Hito C suma modos de prueba (siempre bloquea, pega cada X segundos).


func get_command(_me: Fighter, _opponent: Fighter) -> FighterCommand:
	return FighterCommand.new()
