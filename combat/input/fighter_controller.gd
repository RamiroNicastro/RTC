class_name FighterController
extends RefCounted
## Base de todos los controladores (jugador, dummy y, más adelante, IA).
##
## Su única tarea es devolver un FighterCommand por tick. Nunca modifica al Fighter directamente.


func get_command(_me: Fighter, _opponent: Fighter) -> FighterCommand:
	return FighterCommand.new()
