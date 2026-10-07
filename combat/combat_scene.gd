class_name CombatScene
extends Node2D
## Raíz del combate.
##
## Regla R2: se configura con start(FightSetup) y (desde el Hito E3) devuelve un FightResult.
## No usa autoloads ni conoce la carrera. Se puede correr solo desde debug/combat_sandbox.tscn.
##
## Maneja el orden de cada tick, que es siempre el mismo:
##   1. leer los comandos de AMBOS controladores (nadie tiene ventaja por el orden);
##   2. avanzar a los dos Fighters;
##   3. resolver el espacio (cuerdas y choque entre peleadores);
##   4. mover la cámara.

@onready var ring: Ring = $Ring
@onready var fighter_a: Fighter = $FighterA
@onready var fighter_b: Fighter = $FighterB
@onready var camera: CombatCamera = $CombatCamera

var clock := CombatClock.new()

var _controller_a: FighterController
var _controller_b: FighterController
var _started: bool = false


func start(fight_setup: FightSetup) -> void:
	ring.configure(fight_setup.ring_width)

	fighter_a.configure(fight_setup.fighter_a, 1)
	fighter_b.configure(fight_setup.fighter_b, -1)
	fighter_a.position = Vector2(-fight_setup.start_distance * 0.5, 0.0)
	fighter_b.position = Vector2(fight_setup.start_distance * 0.5, 0.0)
	fighter_a.previous_x = fighter_a.position.x
	fighter_b.previous_x = fighter_b.position.x
	# Evita que la interpolación "deslice" a los peleadores desde (0, 0) en el primer frame.
	fighter_a.reset_physics_interpolation()
	fighter_b.reset_physics_interpolation()

	_controller_a = _make_controller(fight_setup.fighter_a.controller_type)
	_controller_b = _make_controller(fight_setup.fighter_b.controller_type)

	camera.setup(fighter_a, fighter_b, ring.stage_half_width())
	_started = true


# delta se ignora a propósito: la lógica avanza por ticks fijos (ver CombatTime).
func _physics_process(_delta: float) -> void:
	if not _started or not clock.advance():
		return

	var cmd_a: FighterCommand = _controller_a.get_command(fighter_a, fighter_b)
	var cmd_b: FighterCommand = _controller_b.get_command(fighter_b, fighter_a)

	fighter_a.tick(cmd_a)
	fighter_b.tick(cmd_b)

	ring.resolve_positions(fighter_a, fighter_b)
	camera.follow()


func _make_controller(type: FighterSetup.ControllerType) -> FighterController:
	match type:
		FighterSetup.ControllerType.PLAYER:
			return PlayerInput.new()
		_:
			return DummyInput.new()
