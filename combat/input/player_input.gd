class_name PlayerInput
extends FighterController
## Convierte el input del jugador en un FighterCommand.
##
## Lee acciones del Input Map ("move_left", "move_right", "jab"). En el Hito T, los botones táctiles
## disparan esas mismas acciones, así que este archivo no cambia.


func get_command(me: Fighter, _opponent: Fighter) -> FighterCommand:
	var cmd := FighterCommand.new()
	# -1 = izquierda de la pantalla, +1 = derecha.
	var screen_dir: int = int(signf(Input.get_axis("move_left", "move_right")))
	# Pasar a dirección relativa: si miro a la izquierda, ir a la izquierda es avanzar.
	cmd.move = screen_dir * me.facing
	cmd.jab = Input.is_action_just_pressed("jab")
	return cmd
