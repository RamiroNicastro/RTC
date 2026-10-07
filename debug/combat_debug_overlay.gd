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
	var what: String = "conectó"
	if info.result == HitInfo.Result.BLOCKED:
		what = "ROMPIÓ LA GUARDIA" if info.guard_broken else "fue bloqueado"
	_last_event = "tick %d: %s de %s %s (%d de daño)" % [
		_combat.clock.tick, info.move.id, info.attacker.setup.display_name, what, info.damage]
	if info.attacker != _combat.fighter_a:
		return
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
		"J jab   K fuerte   L guardia (mantener)   |   1/2 rival tira jab/fuerte   3 modo del rival",
		"F1 límite FPS   F2 rangos   F3 botones táctiles   R reiniciar",
		"FPS: %d (límite: %s)   tick %d   lógico %.2f s / real %.2f s" % [
			Engine.get_frames_per_second(), "sin límite" if max_fps == 0 else str(max_fps),
			_combat.clock.tick, CombatTime.ticks_to_seconds(_combat.clock.tick),
			(Time.get_ticks_msec() - _start_msec) / 1000.0],
		_fighter_line(a),
		_fighter_line(b),
		"Modo del rival: %s" % (dummy.mode_name() if dummy != null else "-"),
		"Borde a borde: %.1f   jab %.0f → %s   fuerte %.0f → %s" % [
			gap, a.setup.jab.reach, "EN RANGO" if gap <= a.setup.jab.reach else "fuera",
			a.setup.power_punch.reach, "EN RANGO" if gap <= a.setup.power_punch.reach else "fuera"],
		"Cámara: x=%.1f   zoom=%.3f" % [_combat.camera.position.x, _combat.camera.zoom.x],
		"Jugador: tirados %d  conectados %d  bloqueados %d  guardias rotas %d  fallados %d  daño %d" % [
			_thrown, _landed, _blocked, _guard_breaks, _whiffed, _damage_dealt],
		"Último: %s" % _last_event,
	]
	_label.text = "\n".join(lines)


func _fighter_line(f: Fighter) -> String:
	var text: String = "%s: %s" % [f.setup.display_name, Fighter.State.keys()[f.state]]
	if f.state == Fighter.State.ATTACKING and f.current_move != null:
		text += " %s / %s (%d/%d)" % [
			f.current_move.id, Fighter.AttackPhase.keys()[f.attack_phase], f.attack_tick, f.current_move_total_ticks()]
	elif f.stun_left > 0 and f.state in [Fighter.State.HITSTUN, Fighter.State.BLOCKSTUN, Fighter.State.GUARD_BROKEN]:
		text += " (%d ticks)" % f.stun_left
	return text + "   salud %d/%d   stamina %.0f/%.0f (fatiga %.1f)%s" % [
		f.health, f.max_health, f.stamina, f.max_stamina, f.fatigue, "  CANSADO" if f.is_tired() else ""]
