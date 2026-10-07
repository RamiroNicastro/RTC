class_name DummyInput
extends FighterController
## Rival de práctica con modos de prueba. NO es la IA (esa llega en el Hito F).
##
## Modos:
##   QUIETO          no hace nada
##   SIEMPRE_BLOQUEA mantiene la guardia
##   JAB_CADA_X      tira un jab cada interval_ticks
##   FUERTE_CADA_X   tira un fuerte cada interval_ticks
##   BLOQUEA_Y_JAB   mantiene la guardia y suelta un jab cada interval_ticks
## La sandbox también puede pedirle un golpe puntual con queue_jab() / queue_power().

enum Mode { QUIETO, SIEMPRE_BLOQUEA, JAB_CADA_X, FUERTE_CADA_X, BLOQUEA_Y_JAB }

var mode: Mode = Mode.QUIETO
var interval_ticks: int = 90

var _counter: int = 0
var _jab_requested: bool = false
var _power_requested: bool = false


func queue_jab() -> void:
	_jab_requested = true


func queue_power() -> void:
	_power_requested = true


func cycle_mode() -> void:
	mode = ((mode + 1) % Mode.size()) as Mode
	_counter = 0


func mode_name() -> String:
	return Mode.keys()[mode]


func get_command(_me: Fighter, _opponent: Fighter) -> FighterCommand:
	var cmd := FighterCommand.new()
	cmd.guard = mode == Mode.SIEMPRE_BLOQUEA or mode == Mode.BLOQUEA_Y_JAB

	_counter += 1
	if _counter >= interval_ticks:
		_counter = 0
		match mode:
			Mode.JAB_CADA_X, Mode.BLOQUEA_Y_JAB:
				cmd.jab = true
			Mode.FUERTE_CADA_X:
				cmd.power = true

	if _jab_requested:
		cmd.jab = true
	if _power_requested:
		cmd.power = true
	_jab_requested = false
	_power_requested = false
	return cmd
