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
##   4. resolver los golpes de AMBOS y recién después aplicarlos (si conectan en el mismo tick, es un intercambio);
##   5. mover la cámara.

## Se emite por cada golpe que llegó al rival (HIT, BLOCKED o DODGED).
signal hit_resolved(info: HitInfo)

@onready var ring: Ring = $Ring
@onready var fighter_a: Fighter = $FighterA
@onready var fighter_b: Fighter = $FighterB
@onready var camera: CombatCamera = $CombatCamera
@onready var hud: CombatHUD = $CombatHUD
@onready var touch_controls: TouchControls = $TouchControls

var clock := CombatClock.new()
## Árbitro: knockdowns, cuenta, KO y TKO (desde el Hito E2, también rounds).
var fight := FightManager.new()
## Intercambiable: más adelante HitboxHitResolver, sin tocar nada más.
var hit_resolver: HitResolver = DistanceHitResolver.new()

var controller_a: FighterController
var controller_b: FighterController
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

	controller_a = _make_controller(fight_setup.fighter_a.controller_type)
	controller_b = _make_controller(fight_setup.fighter_b.controller_type)

	fight.setup(fighter_a, fighter_b)
	camera.setup(fighter_a, fighter_b, ring.stage_half_width())
	hud.setup(fighter_a, fighter_b, fight)
	# Los botones táctiles se ven solo en celulares (en PC se muestran con F3 desde la sandbox).
	# No se usa is_touchscreen_available(): con la emulación de toque por mouse da true en la PC.
	touch_controls.visible = OS.has_feature("mobile")
	_started = true


# delta se ignora a propósito: la lógica avanza por ticks fijos (ver CombatTime).
func _physics_process(_delta: float) -> void:
	if not _started or not clock.advance():
		return

	var cmd_a: FighterCommand = controller_a.get_command(fighter_a, fighter_b)
	var cmd_b: FighterCommand = controller_b.get_command(fighter_b, fighter_a)
	# Fuera de la pelea activa (cuenta, "¡boxeen!", final), solo el caído puede hacer algo: tocar para levantarse.
	if not fight.is_fighting():
		if fight.downed != fighter_a:
			cmd_a = FighterCommand.new()
		if fight.downed != fighter_b:
			cmd_b = FighterCommand.new()

	fighter_a.tick(cmd_a)
	fighter_b.tick(cmd_b)

	ring.resolve_positions(fighter_a, fighter_b)
	if fight.is_fighting():
		_resolve_hits()
	fight.tick()
	camera.follow()


func _resolve_hits() -> void:
	var info_a: HitInfo = _check_hit(fighter_a, fighter_b)
	var info_b: HitInfo = _check_hit(fighter_b, fighter_a)
	if info_a != null:
		_apply_hit(info_a)
	if info_b != null:
		_apply_hit(info_b)


## Devuelve el HitInfo si el golpe del atacante conecta en este tick, o null si no hay nada que aplicar.
func _check_hit(attacker: Fighter, defender: Fighter) -> HitInfo:
	if not attacker.is_hit_active():
		return null
	var info: HitInfo = hit_resolver.resolve(attacker, defender, attacker.current_move)
	if info.result == HitInfo.Result.WHIFF:
		return null  # puede conectar en el siguiente tick activo
	attacker.mark_move_connected()
	return info


func _apply_hit(info: HitInfo) -> void:
	# Si en este mismo tick ya cayó el otro (intercambio), este golpe no puede tirar a nadie más.
	if not fight.is_fighting() and info.result == HitInfo.Result.HIT and info.damage >= info.defender.health:
		info.damage = info.defender.health - 1
	if info.result == HitInfo.Result.DODGED:
		# Que te esquiven cansa como pegarle al aire.
		info.attacker.spend_stamina(info.move.whiff_stamina_penalty)
	info.defender.receive_hit(info)
	hit_resolved.emit(info)
	if info.defender.state == Fighter.State.KNOCKDOWN:
		fight.on_knockdown(info.defender)


func _make_controller(type: FighterSetup.ControllerType) -> FighterController:
	match type:
		FighterSetup.ControllerType.PLAYER:
			return PlayerInput.new()
		_:
			return DummyInput.new()
