class_name CombatDebugOverlay
extends CanvasLayer
## Muestra en pantalla el estado interno del combate. Es solo para debug: el combate no lo conoce.
##
## "Tiempo lógico" (ticks / 60) tiene que coincidir con el "tiempo real" con cualquier límite de FPS.
## Esa es la prueba de que la lógica no depende del framerate.

var _combat: CombatScene
var _label: Label
var _start_msec: int = 0

# Contadores de golpes del jugador (fighter_a) para comprobar que el daño se aplica una sola vez.
var _thrown: int = 0
var _landed: int = 0
var _whiffed: int = 0
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
	_last_event = "tick %d: %s FALLADO" % [_combat.clock.tick, move.id]


func _on_hit(info: HitInfo) -> void:
	_last_event = "tick %d: %s de %s conectó (%d de daño)" % [
		_combat.clock.tick, info.move.id, info.attacker.setup.display_name, info.damage]
	if info.attacker == _combat.fighter_a:
		_landed += 1
		_damage_dealt += info.damage


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 84)
	_label.add_theme_font_size_override("font_size", 17)
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
	var in_range: bool = gap <= a.setup.jab.reach
	var lines: PackedStringArray = [
		"FPS: %d   (límite: %s)   [F1 límite FPS] [F2 rangos] [R reiniciar]   J = jab" % [
			Engine.get_frames_per_second(), "sin límite" if max_fps == 0 else str(max_fps)],
		"Viewport: %s" % str(get_viewport().get_visible_rect().size),
		"Tick: %d   tiempo lógico: %.2f s   tiempo real: %.2f s" % [
			_combat.clock.tick,
			CombatTime.ticks_to_seconds(_combat.clock.tick),
			(Time.get_ticks_msec() - _start_msec) / 1000.0],
		_fighter_line(a),
		_fighter_line(b),
		"Distancia entre centros: %.1f   borde a borde: %.1f   alcance jab: %.0f → %s" % [
			b.position.x - a.position.x, gap, a.setup.jab.reach, "EN RANGO" if in_range else "fuera"],
		"Cámara: x=%.1f   zoom=%.3f   (objetivo %.3f)" % [
			_combat.camera.position.x, _combat.camera.zoom.x, _combat.camera.target_zoom],
		"Jabs: tirados %d   conectados %d   fallados %d   daño hecho %d" % [
			_thrown, _landed, _whiffed, _damage_dealt],
		"Último: %s" % _last_event,
	]
	_label.text = "\n".join(lines)


func _fighter_line(f: Fighter) -> String:
	var text: String = "%s: %s" % [f.setup.display_name, Fighter.State.keys()[f.state]]
	if f.state == Fighter.State.ATTACKING and f.current_move != null:
		text += " / %s (%d/%d)" % [
			Fighter.AttackPhase.keys()[f.attack_phase], f.attack_tick, f.current_move.total_ticks()]
	elif f.state == Fighter.State.HITSTUN:
		text += " (%d ticks)" % f.hitstun_left
	return text + "   salud %d/%d   x=%.1f" % [f.health, f.max_health, f.position.x]
