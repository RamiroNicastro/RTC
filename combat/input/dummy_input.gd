class_name DummyInput
extends FighterController
## Rival de práctica: se queda quieto, salvo que la sandbox le pida un jab con queue_jab().
##
## En el Hito C suma modos de prueba (siempre bloquea, pega cada X segundos).

var _jab_requested: bool = false


## Pide que el dummy tire un jab en el próximo tick (lo usa la sandbox de debug).
func queue_jab() -> void:
	_jab_requested = true


func get_command(_me: Fighter, _opponent: Fighter) -> FighterCommand:
	var cmd := FighterCommand.new()
	cmd.jab = _jab_requested
	_jab_requested = false
	return cmd
