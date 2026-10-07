class_name CombatDebugOverlay
extends CanvasLayer
## Muestra en pantalla el estado interno del combate. Es solo para debug: el combate no lo conoce.
##
## "Tiempo lógico" (ticks / 60) tiene que coincidir con el "tiempo real" con cualquier límite de FPS.
## Esa es la prueba de que la lógica no depende del framerate.

var _combat: CombatScene
var _label: Label
var _start_msec: int = 0

# Contadores de los golpes del jugador (fighter_a).
var _thrown: int = 0
var _landed: int = 0
var _blocked: int = 0
var _whiffed: int = 0
var _guard_breaks: int = 0
var _dodges: int = 0
var _counters: int = 0
var _damage_dealt: int = 0
var _last_event: String = "-"


func attach(combat: CombatScene) -> void:
	_combat = combat
	_start_msec = Time.get_ticks_msec()
	combat.fighter_a.attack_started.connect(func(_m: MoveData) -> void: _thrown += 1)
	combat.fighter_a.attack_whiffed.connect(_on_whiff)
	combat.hit_resolved.connect(_on_hit)


func _on_whiff(move: MoveData) -> void:
	_whiffed += 1
	_last_event = "tick %d: %s del Jugador FALLADO" % [_combat.clock.tick, move.id]


func _on_hit(info: HitInfo) -> void:
	var what: String = "COUNTER" if info.counter else "conectó"
	match info.result:
		HitInfo.Result.BLOCKED:
			what = "ROMPIÓ LA GUARDIA" if info.guard_broken else "fue bloqueado"
		HitInfo.Result.DODGED:
			what = "fue ESQUIVADO"
	_last_event = "tick %d: %s de %s %s (%d de daño)" % [
		_combat.clock.tick, info.move.id, info.attacker.setup.display_name, what, info.damage]
	if info.defender == _combat.fighter_a and info.result == HitInfo.Result.DODGED:
		_dodges += 1
	if info.attacker != _combat.fighter_a or info.result == HitInfo.Result.DODGED:
		return
	if info.counter:
		_counters += 1
	_damage_dealt += info.damage
	if info.result == HitInfo.Result.HIT:
		_landed += 1
	else:
		_blocked += 1
		if info.guard_broken:
			_guard_breaks += 1


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 170)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)


func _process(_delta: float) -> void:
	if _combat == null or _combat.fighter_a.setup == null:
		return
	var a: Fighter = _combat.fighter_a
	var b: Fighter = _combat.fighter_b
	var max_fps: int = Engine.max_fps
	var gap: float = DistanceHitResolver.edge_gap(a, b)
	var dummy := _combat.controller_b as DummyInput
	var lines: PackedStringArray = [
		"J jab  K fuerte  L guardia  ESPACIO esquive  S/↓ cuerpo (mantener + golpe)",
		"3 rival (estilos de IA / dummy)  8 dificultad  |  dummy: 1/2/4 jab/fuerte/cuerpo  5 se levanta  |  6 rival a 10 de vida  7 quedan 5 s",
		"F1 límite FPS   F2 rangos   F3 botones táctiles   R reiniciar",
		"FPS: %d (límite: %s)   tick %d   lógico %.2f s / real %.2f s" % [
			Engine.get_frames_per_second(), "sin límite" if max_fps == 0 else str(max_fps),
			_combat.clock.tick, CombatTime.ticks_to_seconds(_combat.clock.tick),
			(Time.get_ticks_msec() - _start_msec) / 1000.0],
		_fighter_line(a),
		_fighter_line(b),
		_rival_line(dummy),
		"Pelea: %s   round %d/%d   quedan %d s   cuenta %d   caídas (round/total) jugador %d/%d  rival %d/%d" % [
			FightManager.Phase.keys()[_combat.fight.phase], _combat.fight.round_number, _combat.fight.total_rounds,
			_combat.fight.seconds_left(), _combat.fight.count,
			a.round_knockdowns, a.knockdowns, b.round_knockdowns, b.knockdowns],
		"Borde a borde: %.1f   jab %.0f → %s   fuerte %.0f → %s" % [
			gap, a.setup.jab.reach, "EN RANGO" if gap <= a.setup.jab.reach else "fuera",
			a.setup.power_punch.reach, "EN RANGO" if gap <= a.setup.power_punch.reach else "fuera"],
		"Cámara: x=%.1f   zoom=%.3f" % [_combat.camera.position.x, _combat.camera.zoom.x],
		_judges_line(),
		"Jugador: tirados %d  conectados %d  bloqueados %d  guardias rotas %d  fallados %d  daño %d" % [
			_thrown, _landed, _blocked, _guard_breaks, _whiffed, _damage_dealt],
		"Jugador: esquives exitosos %d   counters %d" % [_dodges, _counters],
		"Último: %s" % _last_event,
	]
	_label.text = "\n".join(lines)


func _rival_line(dummy: DummyInput) -> String:
	if dummy != null:
		return "Rival: dummy %s   se levanta: %s" % [dummy.mode_name(), "sí" if dummy.getup_enabled else "NO"]
	var ai := _combat.controller_b as AIInput
	if ai != null:
		return "Rival: IA %s (%s)   pensando: %s   reacción %d ticks" % [
			tr(ai.profile.style_name_key), AIInput.Difficulty.keys()[ai.difficulty], ai.intent, ai.reaction_ticks]
	return "Rival: -"


## Cómo va el round actual para cada juez (puntos de este round) y las tarjetas hasta ahora.
func _judges_line() -> String:
	if _combat.stats.rounds.is_empty():
		return "Jueces: -"
	var a: FightStats.FighterRoundStats = _combat.stats.current(0)
	var b: FightStats.FighterRoundStats = _combat.stats.current(1)
	var parts: PackedStringArray = []
	for j in _combat.judges.size():
		var judge: Judge = _combat.judges[j]
		var total := Vector2i.ZERO
		for s: Vector2i in _combat.judge_cards[j]:
			total += s
		parts.append("J%d: round %.1f-%.1f  tarjeta %d-%d" % [j + 1, judge.points(a), judge.points(b), total.x, total.y])
	return "   ".join(parts)


func _fighter_line(f: Fighter) -> String:
	var text: String = "%s: %s" % [f.setup.display_name, Fighter.State.keys()[f.state]]
	if f.state == Fighter.State.ATTACKING and f.current_move != null:
		text += " %s / %s (%d/%d)" % [
			f.current_move.id, Fighter.AttackPhase.keys()[f.attack_phase], f.attack_tick, f.current_move_total_ticks()]
	elif f.stun_left > 0 and f.state in [Fighter.State.HITSTUN, Fighter.State.BLOCKSTUN, Fighter.State.GUARD_BROKEN]:
		text += " (%d ticks)" % f.stun_left
	elif f.state == Fighter.State.KNOCKDOWN:
		text += " (barra para levantarse %d%%, %.0f toques)" % [roundi(f.getup_progress * 100.0), f.getup_taps_required()]
	elif f.state == Fighter.State.DODGING:
		text += " (%d/%d%s)" % [f.dodge_tick, f.dodge_total_ticks(), " INVULNERABLE" if f.is_dodging_head() else ""]
	if f.counter_ready_left > 0:
		text += "  COUNTER LISTO"
	return text + "   salud %d/%d (base %d)   stamina %.0f/%.0f (fatiga %.1f, cuerpo %.1f)%s" % [
		f.health, f.max_health, f.base_max_health, f.stamina, f.max_stamina, f.fatigue, f.body_drain,
		"  CANSADO" if f.is_tired() else ""]
