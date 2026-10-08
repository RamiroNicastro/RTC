class_name PlayerInput
extends FighterController
## Convierte el input del jugador en un FighterCommand.
##
## Lee acciones del Input Map ("move_left", "move_right", "jab", "power", "guard", "dodge", "body").
## Los botones táctiles disparan esas mismas acciones, así que este archivo no cambia con el táctil.
##
## Los toques NO se pierden: CombatScene llama a poll() en CADA tick de física, incluso durante el hitstop
## y la cámara lenta (cuando la lógica está congelada). Los "apretó" quedan guardados hasta que
## get_command() los usa. Sin esto, un jab apretado durante la pausa del impacto se perdía.

var _pending_jab: bool = false
var _pending_power: bool = false
var _pending_dodge: bool = false
## true si al apretar el golpe también estaba apretado el modificador de cuerpo.
var _pending_body: bool = false


## Descarta lo pendiente (al salir de la pausa: lo apretado en el menú no debe salir como golpe).
func clear_pending() -> void:
	_pending_jab = false
	_pending_power = false
	_pending_dodge = false
	_pending_body = false


## Se llama en cada tick de física (avance o no la lógica). Guarda lo que se apretó.
func poll() -> void:
	var body_now: bool = Input.is_action_pressed("body")
	if Input.is_action_just_pressed("jab"):
		_pending_jab = true
		_pending_body = _pending_body or body_now
	if Input.is_action_just_pressed("power"):
		_pending_power = true
		_pending_body = _pending_body or body_now
	if Input.is_action_just_pressed("dodge"):
		_pending_dodge = true


func get_command(me: Fighter, _opponent: Fighter) -> FighterCommand:
	poll()
	var cmd := FighterCommand.new()
	# -1 = izquierda de la pantalla, +1 = derecha.
	var screen_dir: int = int(signf(Input.get_axis("move_left", "move_right")))
	# Pasar a dirección relativa: si miro a la izquierda, ir a la izquierda es avanzar.
	cmd.move = screen_dir * me.facing
	cmd.jab = _pending_jab
	cmd.power = _pending_power
	cmd.dodge = _pending_dodge
	cmd.body = Input.is_action_pressed("body") or _pending_body
	cmd.power_held = Input.is_action_pressed("power")
	cmd.guard = Input.is_action_pressed("guard")
	_pending_jab = false
	_pending_power = false
	_pending_dodge = false
	_pending_body = false
	return cmd
