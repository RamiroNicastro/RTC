class_name CombatDebugOverlay
extends CanvasLayer
## Muestra en pantalla el estado interno del combate. Es solo para debug: el combate no lo conoce.
##
## "Tiempo lógico" (ticks / 60) tiene que coincidir con el "tiempo real" con cualquier límite de FPS.
## Esa es la prueba de que la lógica no depende del framerate.

var _combat: CombatScene
var _label: Label
var _start_msec: int = 0


func attach(combat: CombatScene) -> void:
	_combat = combat
	_start_msec = Time.get_ticks_msec()


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)


func _process(_delta: float) -> void:
	if _combat == null or _combat.fighter_a.setup == null:
		return
	var a: Fighter = _combat.fighter_a
	var b: Fighter = _combat.fighter_b
	var max_fps: int = Engine.max_fps
	var lines: PackedStringArray = [
		"FPS: %d   (límite: %s)   [F1 cambia el límite]   [R reinicia]" % [
			Engine.get_frames_per_second(), "sin límite" if max_fps == 0 else str(max_fps)],
		"Viewport: %s" % str(get_viewport().get_visible_rect().size),
		"Tick: %d   tiempo lógico: %.2f s   tiempo real: %.2f s" % [
			_combat.clock.tick,
			CombatTime.ticks_to_seconds(_combat.clock.tick),
			(Time.get_ticks_msec() - _start_msec) / 1000.0],
		"%s: %s   x=%.1f" % [a.setup.display_name, Fighter.State.keys()[a.state], a.position.x],
		"%s: %s   x=%.1f" % [b.setup.display_name, Fighter.State.keys()[b.state], b.position.x],
		"Distancia entre centros: %.1f" % (b.position.x - a.position.x),
		"Cámara: x=%.1f   zoom=%.3f   (objetivo %.3f)" % [
			_combat.camera.position.x, _combat.camera.zoom.x, _combat.camera.target_zoom],
	]
	_label.text = "\n".join(lines)
