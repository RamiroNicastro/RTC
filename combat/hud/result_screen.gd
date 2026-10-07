class_name ResultScreen
extends CanvasLayer
## Pantalla final de la pelea (placeholder): resultado, tarjetas de los jueces y estadísticas.
##
## Solo MUESTRA un FightResult; no decide nada. Aparece un momento después del cartel de KO o de fin de pelea.
## Los textos salen de i18n/textos.csv con tr().

## Segundos de espera para que primero se vea el cartel grande del HUD.
const SHOW_DELAY_SECONDS: float = 1.8
## El panel nunca sube más que esto (deja libre la parte de arriba: barras, reloj y botones).
const MIN_TOP: float = 165.0

var _panel: PanelContainer


func _ready() -> void:
	layer = 15
	visible = false


func show_result(result: FightResult) -> void:
	await get_tree().create_timer(SHOW_DELAY_SECONDS).timeout
	_build(result)
	visible = true


func _build(r: FightResult) -> void:
	if _panel != null:
		_panel.queue_free()
	var view: Vector2 = get_viewport().get_visible_rect().size

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 1.0)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)

	_label(box, _method_text(r), 34, Color(1.0, 0.85, 0.3))
	var who: String = tr("RESULT_DRAW") if r.is_draw() else tr("COMBAT_WINNER").format({"name": r.winner_name()})
	_label(box, who, 24, Color.WHITE)
	if not r.is_decision():
		var elapsed: int = r.end_round_elapsed_seconds
		_label(box, tr("RESULT_WHEN").format({"round": r.end_round, "time": "%d:%02d" % [elapsed / 60, elapsed % 60]}),
				20, Color(0.8, 0.8, 0.8))

	# Tarjetas de los jueces.
	if not r.judge_totals.is_empty():
		box.add_child(HSeparator.new())
		for j in r.judge_totals.size():
			var t: Vector2i = r.judge_totals[j]
			_label(box, "%s:  %d - %d" % [tr(r.judge_name_keys[j]), t.x, t.y], 18, Color(0.9, 0.9, 0.9))

	# Estadísticas: Jugador | dato | Rival.
	box.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	box.add_child(grid)
	var a: FightStats.FighterRoundStats = r.stats.totals(0)
	var b: FightStats.FighterRoundStats = r.stats.totals(1)
	_row(grid, r.fighter_names[0], "", r.fighter_names[1], Color(1.0, 0.85, 0.3))
	_row(grid, "%d/%d (%d%%)" % [a.landed, a.thrown, roundi(a.accuracy() * 100.0)], tr("RESULT_LANDED"),
			"%d/%d (%d%%)" % [b.landed, b.thrown, roundi(b.accuracy() * 100.0)])
	_row(grid, str(a.landed_power), tr("RESULT_POWER"), str(b.landed_power))
	_row(grid, str(a.landed_body), tr("RESULT_BODY"), str(b.landed_body))
	_row(grid, str(a.counters), tr("RESULT_COUNTERS"), str(b.counters))
	_row(grid, str(a.blocks_made + a.dodges_made), tr("RESULT_DEFENSE"), str(b.blocks_made + b.dodges_made))
	_row(grid, str(r.knockdowns.x), tr("RESULT_KNOCKDOWNS"), str(r.knockdowns.y))
	_row(grid, str(a.damage_dealt), tr("RESULT_DAMAGE"), str(b.damage_dealt))

	# Centrar después de que el panel calcule su tamaño.
	await get_tree().process_frame
	_panel.position = Vector2((view.x - _panel.size.x) * 0.5, maxf(MIN_TOP, (view.y - _panel.size.y) * 0.5))


func _method_text(r: FightResult) -> String:
	match r.method:
		FightResult.Method.KO:
			return tr("COMBAT_KO")
		FightResult.Method.TKO:
			return tr("COMBAT_TKO")
		FightResult.Method.UNANIMOUS_DECISION:
			return tr("RESULT_UNANIMOUS")
		FightResult.Method.SPLIT_DECISION:
			return tr("RESULT_SPLIT")
		FightResult.Method.MAJORITY_DECISION:
			return tr("RESULT_MAJORITY")
	return tr("RESULT_DRAW_TITLE")


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UIStyle.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _row(grid: GridContainer, left: String, middle: String, right: String, color: Color = Color.WHITE) -> void:
	for text in [left, middle, right]:
		var l := Label.new()
		l.text = text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 170.0
		l.add_theme_font_override("font", UIStyle.font())
		l.add_theme_font_size_override("font_size", 19)
		l.add_theme_color_override("font_color", color if text != middle else Color(0.7, 0.7, 0.75))
		grid.add_child(l)
