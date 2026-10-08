class_name CombatScene
extends Node2D
## Raíz del combate.
##
## Regla R2: se configura con start(FightSetup) y al terminar emite fight_finished(FightResult).
## No usa autoloads ni conoce la carrera. Se puede correr solo desde debug/combat_sandbox.tscn.
##
## Maneja el orden de cada tick, que es siempre el mismo:
##   1. leer los comandos de AMBOS controladores (nadie tiene ventaja por el orden);
##   2. avanzar a los dos Fighters;
##   3. resolver el espacio (cuerdas y choque entre peleadores);
##   4. resolver los golpes de AMBOS y recién después aplicarlos (si conectan en el mismo tick, es un intercambio);
##   5. avanzar al árbitro (reloj, cuenta, rounds) y mover la cámara.

## Se emite por cada golpe que llegó al rival (HIT, BLOCKED o DODGED).
signal hit_resolved(info: HitInfo)
## Salida del combate (R2): se emite una sola vez, cuando termina la pelea.
signal fight_finished(result: FightResult)
## El jugador eligió "salir" en la pausa (el modo que lanzó el combate decide qué hacer).
signal quit_requested()

@onready var ring: Ring = $Ring
@onready var fighter_a: Fighter = $FighterA
@onready var fighter_b: Fighter = $FighterB
@onready var camera: CombatCamera = $CombatCamera
@onready var hud: CombatHUD = $CombatHUD
@onready var touch_controls: TouchControls = $TouchControls
@onready var result_screen: ResultScreen = $ResultScreen
@onready var fx: CombatFX = $CombatFX
@onready var sfx: CombatSfx = $CombatSfx
@onready var pause_menu: PauseMenu = $PauseMenu

var clock := CombatClock.new()
## Árbitro: rounds, reloj, knockdowns, cuenta, KO y TKO.
var fight := FightManager.new()
## Registro de lo que pasa en la pelea (lo usan los jueces y el FightResult).
var stats := FightStats.new()
var judges: Array[Judge] = Judge.make_panel()
## Tarjetas: un elemento por juez, con un Vector2i (A, B) por round puntuado.
var judge_cards: Array = [[], [], []]
## Intercambiable: más adelante HitboxHitResolver, sin tocar nada más.
var hit_resolver: HitResolver = DistanceHitResolver.new()
## El resultado, cuando la pelea terminó (null mientras tanto).
var result: FightResult

var controller_a: FighterController
var controller_b: FighterController
var _setup: FightSetup
var _started: bool = false


func start(fight_setup: FightSetup) -> void:
	_setup = fight_setup
	clock.effects_enabled = fight_setup.game_feel
	ring.configure(fight_setup.ring_width)

	fighter_a.configure(fight_setup.fighter_a, 1)
	fighter_b.configure(fight_setup.fighter_b, -1)
	_place_fighters_at_start()

	controller_a = _make_controller(fight_setup.fighter_a)
	controller_b = _make_controller(fight_setup.fighter_b)

	fighter_a.attack_started.connect(func(_m: MoveData) -> void: stats.record_attack_started(0))
	fighter_b.attack_started.connect(func(_m: MoveData) -> void: stats.record_attack_started(1))
	for f in [fighter_a, fighter_b]:
		f.attack_whiffed.connect(func(m: MoveData) -> void: sfx.play_whoosh(0.8 if m.is_power_punch else 0.3))
		# Aviso sonoro del fuerte (acompaña el destello del guante).
		f.attack_started.connect(func(m: MoveData) -> void:
			if m.is_power_punch:
				sfx.play_whoosh(0.1))

	# Conectar ANTES de fight.setup(): si la pelea arranca sin cartel, el round 1 empieza ahí mismo.
	fight.round_started.connect(func(_n: int) -> void: stats.start_round())
	fight.round_ended.connect(_on_round_ended)
	fight.round_break_started.connect(_on_round_break_started)
	fight.fight_ended.connect(_on_fight_ended)
	# Sonido: campana al empezar y terminar cada round, público de fondo.
	fight.round_started.connect(func(_n: int) -> void: sfx.play_bell(1))
	fight.round_ended.connect(func(_n: int) -> void: sfx.play_bell(3))
	sfx.start_crowd_ambience()
	fight.setup(fighter_a, fighter_b, fight_setup)

	camera.setup(fighter_a, fighter_b, ring.stage_half_width())
	fx.setup(fighter_a, fighter_b)
	for f in [fighter_a, fighter_b]:
		f.cut_opened.connect(func(_spot: int) -> void: fx.on_cut_opened(f))
	pause_menu.setup(self)
	hud.setup(fighter_a, fighter_b, fight)
	# Los botones táctiles se ven solo en celulares (en PC se muestran con F3 desde la sandbox).
	# No se usa is_touchscreen_available(): con la emulación de toque por mouse da true en la PC.
	touch_controls.visible = OS.has_feature("mobile")
	_started = true


# delta se ignora a propósito: la lógica avanza por ticks fijos (ver CombatTime).
func _physics_process(_delta: float) -> void:
	if not _started:
		return
	# Los toques del jugador se guardan en CADA tick, aunque la lógica esté congelada (hitstop, cámara lenta).
	if not clock.paused:
		for c in [controller_a, controller_b]:
			if c is PlayerInput:
				(c as PlayerInput).poll()
	if not clock.advance():
		camera.follow()  # durante el hitstop la lógica se congela, pero la sacudida sigue
		return

	var cmd_a: FighterCommand = controller_a.get_command(fighter_a, fighter_b)
	var cmd_b: FighterCommand = controller_b.get_command(fighter_b, fighter_a)
	# Fuera de la pelea activa (cuenta, carteles, descanso, final), solo el caído puede hacer algo: tocar para levantarse.
	if not fight.is_fighting():
		if fight.downed != fighter_a:
			cmd_a = FighterCommand.new()
			fighter_a.clear_buffer()
		if fight.downed != fighter_b:
			cmd_b = FighterCommand.new()
			fighter_b.clear_buffer()

	fighter_a.tick(cmd_a)
	fighter_b.tick(cmd_b)

	ring.resolve_positions(fighter_a, fighter_b)
	if fight.is_fighting():
		_record_aggression()
		_resolve_hits()
	fight.tick()
	camera.follow()


func _resolve_hits() -> void:
	var info_a: HitInfo = _check_hit(fighter_a, fighter_b)
	var info_b: HitInfo = _check_hit(fighter_b, fighter_a)
	# Intercambio en el que los dos tumbarían: nadie tiene ventaja por el orden → los dos quedan con 1 de salud.
	if info_a != null and info_b != null and info_a.result == HitInfo.Result.HIT and info_b.result == HitInfo.Result.HIT \
			and info_a.damage >= fighter_b.health and info_b.damage >= fighter_a.health:
		info_a.damage = maxi(0, fighter_b.health - 1)
		info_b.damage = maxi(0, fighter_a.health - 1)
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
		info.damage = maxi(0, info.defender.health - 1)
	if info.result == HitInfo.Result.DODGED:
		# Que te esquiven cansa como pegarle al aire.
		info.attacker.spend_stamina(info.move.whiff_stamina_penalty)
	info.defender.receive_hit(info)
	if not info.attacker.is_down():
		info.attacker.notify_attack_result(info)
	if info.knockback > 0.0 and info.result != HitInfo.Result.DODGED:
		info.defender.push_back(info.knockback)
	stats.record_hit(info, _index_of(info.attacker))
	hit_resolved.emit(info)
	_impact_feel(info)
	if info.defender.state == Fighter.State.KNOCKDOWN:
		stats.record_knockdown(_index_of(info.defender))
		_knockdown_feel(info.defender)   # antes de on_knockdown: si es TKO, la cámara lenta final la pone el fin de pelea
		fight.on_knockdown(info.defender)
	# Un corte gravísimo: el médico para la pelea en el momento.
	elif fight.is_fighting() and info.defender.worst_cut_severity() >= Fighter.DOCTOR_IMMEDIATE_SEVERITY:
		fight.stop_by_doctor(info.defender)


## Game feel de cada impacto: hitstop (la lógica se congela), sacudida, zoom y vibración.
## Todo proporcional a la fuerza del golpe: un jab apenas se nota, un fuerte cargado sacude todo.
func _impact_feel(info: HitInfo) -> void:
	fx.on_hit(info)
	var strength: float = clampf(info.damage / 14.0, 0.0, 1.6)
	match info.result:
		HitInfo.Result.HIT:
			sfx.play_hit(strength + (0.3 if info.counter else 0.0), info.zone == MoveData.Zone.BODY)
			if info.counter or strength >= 1.0:
				sfx.play_crowd_cheer(0.5)
		HitInfo.Result.BLOCKED:
			if info.guard_broken:
				sfx.play_guard_break()
			else:
				sfx.play_block(strength)
		HitInfo.Result.DODGED:
			sfx.play_dodge()
	match info.result:
		HitInfo.Result.HIT:
			var hitstop: int = 2 + roundi(strength * 5.0)
			if info.counter:
				hitstop += 3
			if info.charge_ratio >= 0.5:
				hitstop += 3
			if info.star:
				hitstop += 6
				camera.kick_zoom(0.12)
				fx.flash(0.4)
				sfx.play_crowd_cheer(1.0)
			clock.freeze(hitstop)
			camera.shake(0.1 + strength * 0.35)
			if info.move.is_power_punch:
				camera.kick_zoom(0.02 + strength * 0.05)
			_vibrate(20 + roundi(strength * 40.0))
			ring.excite(0.08 + strength * 0.3 + (0.3 if info.counter else 0.0))
		HitInfo.Result.BLOCKED:
			if info.guard_broken:
				clock.freeze(8)
				camera.shake(0.45)
				camera.kick_zoom(0.05)
				_vibrate(60)
			else:
				clock.freeze(2)
				camera.shake(0.06 + strength * 0.15)
		HitInfo.Result.DODGED:
			clock.freeze(3)


func _knockdown_feel(f: Fighter) -> void:
	fx.on_knockdown(f)
	ring.excite(1.0)
	sfx.play_knockdown()
	sfx.play_crowd_cheer(1.0)
	clock.freeze(14)
	clock.slow_motion(70, 3)
	camera.shake(0.8)
	camera.kick_zoom(0.1)
	_vibrate(180)


func _vibrate(ms: int) -> void:
	if OS.has_feature("mobile") and _setup.game_feel:
		Input.vibrate_handheld(ms)


## Agresividad para los jueces: ticks en que cada uno avanza hacia el rival (también caminando con la guardia arriba).
func _record_aggression() -> void:
	for f in [fighter_a, fighter_b]:
		if f.state in [Fighter.State.MOVING, Fighter.State.BLOCKING] and f.position.x * f.facing > f.previous_x * f.facing:
			stats.record_forward_tick(_index_of(f))


## Al terminar cada round, los tres jueces lo puntúan con lo que registró FightStats.
func _on_round_ended(_round_number: int) -> void:
	var a: FightStats.FighterRoundStats = stats.current(0)
	var b: FightStats.FighterRoundStats = stats.current(1)
	for j in judges.size():
		judge_cards[j].append(judges[j].score_round(a, b))


func _on_fight_ended(winner: Fighter, method: FightManager.Method) -> void:
	if method == FightManager.Method.KO or method == FightManager.Method.TKO:
		# Final dramático: cámara lenta y zoom sobre el que quedó en la lona.
		clock.slow_motion(150, 4)
		camera.focus(_other(winner))
		fx.flash(0.6)
		sfx.play_crowd_cheer(1.2)
	sfx.play_bell(5)
	result = _build_result(winner, method)
	result_screen.show_result(result)
	fight_finished.emit(result)


func _build_result(winner: Fighter, method: FightManager.Method) -> FightResult:
	var r := FightResult.new()
	r.fighter_names = PackedStringArray([fighter_a.setup.display_name, fighter_b.setup.display_name])
	r.scheduled_rounds = fight.total_rounds
	r.end_round = fight.round_number
	r.end_round_elapsed_seconds = roundi(_setup.round_seconds - CombatTime.ticks_to_seconds(fight.round_ticks_left))
	r.stats = stats
	r.knockdowns = Vector2i(fighter_a.knockdowns, fighter_b.knockdowns)
	r.final_health = Vector2i(fighter_a.health, fighter_b.health)
	r.final_max_health = Vector2i(fighter_a.max_health, fighter_b.max_health)
	r.base_health = Vector2i(fighter_a.base_max_health, fighter_b.base_max_health)
	# Lesiones: los cortes (la carrera los va a usar para el tiempo de recuperación).
	for f in [fighter_a, fighter_b]:
		for c in f.cuts:
			r.injuries.append({"type": "cut", "fighter": _index_of(f),
					"spot": Fighter.CutSpot.keys()[c.spot].to_lower(), "severity": snappedf(c.severity, 0.01)})

	r.judge_cards = judge_cards
	for j in judges.size():
		r.judge_name_keys.append(judges[j].judge_name_key)
		var total := Vector2i.ZERO
		for round_score: Vector2i in judge_cards[j]:
			total += round_score
		r.judge_totals.append(total)

	match method:
		FightManager.Method.KO:
			r.method = FightResult.Method.KO
			r.winner_index = _index_of(winner)
		FightManager.Method.TKO:
			r.method = FightResult.Method.TKO
			r.winner_index = _index_of(winner)
		FightManager.Method.DOCTOR:
			r.method = FightResult.Method.DOCTOR_STOPPAGE
			r.winner_index = _index_of(winner)
		_:
			var decision: Array = FightResult.decide(r.judge_totals)
			r.winner_index = decision[0]
			r.method = decision[1]
	return r


func _index_of(f: Fighter) -> int:
	return 0 if f == fighter_a else 1


func _other(f: Fighter) -> Fighter:
	return fighter_b if f == fighter_a else fighter_a


func _place_fighters_at_start() -> void:
	fighter_a.position = Vector2(-_setup.start_distance * 0.5, 0.0)
	fighter_b.position = Vector2(_setup.start_distance * 0.5, 0.0)
	fighter_a.previous_x = fighter_a.position.x
	fighter_b.previous_x = fighter_b.position.x
	# Evita que la interpolación "deslice" a los peleadores (al empezar y al volver a su lugar).
	fighter_a.reset_physics_interpolation()
	fighter_b.reset_physics_interpolation()


## Descanso entre rounds: cada uno vuelve a su lugar y se recupera en parte.
func _on_round_break_started(_round_number: int) -> void:
	# El médico revisa los cortes: si alguno es muy grave, para la pelea.
	for f in [fighter_a, fighter_b]:
		if f.worst_cut_severity() >= Fighter.DOCTOR_CHECK_SEVERITY:
			fight.stop_by_doctor(f)
			return
	fighter_a.recover_between_rounds()
	fighter_b.recover_between_rounds()
	# El cutman trabaja los cortes.
	fighter_a.treat_cuts()
	fighter_b.treat_cuts()
	_place_fighters_at_start()


# --- Pausa ---

## Pausa la lógica del combate (los toques no avanzan nada) y avisa a quien quiera mostrar un menú.
signal pause_changed(paused: bool)


func set_paused(value: bool) -> void:
	if not _started or result != null:
		return
	clock.paused = value
	if not value:
		for c in [controller_a, controller_b]:
			if c is PlayerInput:
				(c as PlayerInput).clear_pending()
	pause_changed.emit(value)


func is_paused() -> bool:
	return clock.paused


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode in [KEY_ESCAPE, KEY_P]:
		set_paused(not is_paused())
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Si la app pierde el foco (llamada, minimizar) o se toca "Atrás" en Android: pausa.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		set_paused(true)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		set_paused(not is_paused())


func _make_controller(fighter_setup: FighterSetup) -> FighterController:
	match fighter_setup.controller_type:
		FighterSetup.ControllerType.PLAYER:
			return PlayerInput.new()
		FighterSetup.ControllerType.AI:
			var ai := AIInput.new()
			ai.configure(fighter_setup.ai_profile, fighter_setup.ai_seed, fighter_setup.ai_difficulty)
			return ai
		_:
			return DummyInput.new()
