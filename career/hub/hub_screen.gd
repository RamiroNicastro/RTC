class_name HubScreen
extends Control
## Hub de la carrera: quién sos, cuándo es, cuánta plata tenés, tu récord, tus estadísticas,
## tu energía, las acciones que te quedan y los 5 lugares.
##
## Gimnasio (entrenar), Trabajo (plata) y Casa (descansar) usan WeekActions; Arena y Tienda
## todavía avisan "Próximamente". Guarda después de cada acción y al salir.
## Teclado: Esc = cerrar ventana o volver al menú.

## [id, clave de texto, color]. El orden es el de la grilla (2 columnas).
const PLACES: Array = [
	[&"gym", "PLACE_GYM", Color(0.85, 0.35, 0.25)],
	[&"arena", "PLACE_ARENA", Color(0.9, 0.7, 0.2)],
	[&"work", "PLACE_WORK", Color(0.35, 0.55, 0.8)],
	[&"shop", "PLACE_SHOP", Color(0.55, 0.4, 0.75)],
	[&"home", "PLACE_HOME", Color(0.35, 0.65, 0.45)],
]
const ENERGY_BAR := Vector2(300, 20)
const PLAYER_BLUE := Color(0.4, 0.7, 1.0)

var _root_box: CenterContainer
var _bars: StatBars
var _toast: Label
## Ventana abierta encima del hub (gimnasio, trabajo, casa, fin de semana). null = ninguna.
var _overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not GameState.active and not SaveManager.load_slot():
		# Sin carrera (por ejemplo, abriendo esta escena suelta en el editor): volver al título.
		SceneRouter.go_title.call_deferred()
		return
	var bg := ColorRect.new()
	bg.color = UIStyle.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
		if _overlay != null:
			_close_overlay()
		else:
			_go_menu()


# --- Pantalla principal ---

## Arma (o rearma, después de cada acción) todo el hub con los datos de GameState.
func _build() -> void:
	if _root_box != null:
		_root_box.queue_free()
	_root_box = CenterContainer.new()
	_root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_box)
	move_child(_root_box, 1)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_root_box.add_child(box)

	box.add_child(_header())

	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 32)
	var stats_panel := UIStyle.panel()
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 8)
	stats_box.add_child(UIStyle.label(tr("HUB_STATS"), 24, UIStyle.MUTED, 5))
	_bars = StatBars.new(180.0, 1)
	stats_box.add_child(_bars)
	stats_panel.add_child(stats_box)
	body.add_child(stats_panel)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	var places := GridContainer.new()
	places.columns = 2
	places.add_theme_constant_override("h_separation", 14)
	places.add_theme_constant_override("v_separation", 14)
	for p in PLACES:
		var b := UIStyle.button(tr(p[1]), _on_place.bind(p[0]), false)
		b.custom_minimum_size = Vector2(300, 80)
		b.add_theme_stylebox_override("normal", _place_box(p[2]))
		b.add_theme_stylebox_override("hover", _place_box(p[2].lightened(0.15)))
		b.add_theme_stylebox_override("pressed", _place_box(p[2].darkened(0.2)))
		places.add_child(b)
	right.add_child(places)
	right.add_child(_energy_row())
	right.add_child(_actions_row())
	body.add_child(right)
	box.add_child(body)

	_toast = UIStyle.label("", 24, UIStyle.GOLD, 6)
	_toast.modulate.a = 0.0
	box.add_child(_toast)

	var menu := UIStyle.button(tr("HUB_MENU"), _go_menu, false)
	menu.custom_minimum_size = Vector2(380, 70)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(menu)

	_bars.show_stats(GameState.fighter, false)


func _header() -> Control:
	var panel := UIStyle.panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	var who := VBoxContainer.new()
	var name_label := UIStyle.label(GameState.display_name(), 44, PLAYER_BLUE, 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	who.add_child(name_label)
	var style: FighterStyle = PlayerFighter.find_style(GameState.style_id)
	var sub := UIStyle.label(tr("HUB_SUBTITLE").format({
		"style": tr(style.name_key) if style != null else "",
		"tier": tr("TIER_%d" % GameState.tier)}), 22, UIStyle.MUTED, 5)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	who.add_child(sub)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(who)
	row.add_child(_info(tr("HUB_DATE").format({"week": GameState.week_of_year(), "year": GameState.week / GameState.WEEKS_PER_YEAR + 1}),
			tr("HUB_AGE").format({"age": GameState.age()})))
	var money_caption: String = tr("HUB_DEBT") if GameState.money < 0 else tr("HUB_MONEY")
	var money_text: String = ("-$ %d" % -GameState.money) if GameState.money < 0 else ("$ %d" % GameState.money)
	row.add_child(_info(money_text, money_caption, UIStyle.RED if GameState.money < 0 else UIStyle.TEXT))
	row.add_child(_info("%d-%d-%d" % [GameState.wins, GameState.losses, GameState.draws],
			tr("HUB_RECORD").format({"kos": GameState.kos})))
	panel.custom_minimum_size = Vector2(1180, 0)
	panel.add_child(row)
	return panel


## Un dato del encabezado: valor grande y explicación chica.
func _info(value: String, caption: String, color: Color = UIStyle.TEXT) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(UIStyle.label(value, 34, color, 8))
	v.add_child(UIStyle.label(caption, 18, UIStyle.RED if color == UIStyle.RED else UIStyle.MUTED, 4))
	return v


func _energy_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(UIStyle.label(tr("HUB_ENERGY"), 22, UIStyle.TEXT, 5))
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.12)
	bg.custom_minimum_size = ENERGY_BAR
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	var ratio: float = float(GameState.energy) / GameState.MAX_ENERGY
	fill.size = Vector2(ENERGY_BAR.x * ratio, ENERGY_BAR.y)
	fill.color = StatBars.UP_COLOR if GameState.energy >= WeekActions.TIRED_ENERGY else Color(0.95, 0.65, 0.2)
	bg.add_child(fill)
	row.add_child(bg)
	row.add_child(UIStyle.label("%d" % GameState.energy, 22, fill.color.lightened(0.3), 5))
	return row


func _actions_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(UIStyle.label(tr("HUB_ACTIONS"), 22, UIStyle.TEXT, 5))
	for i in GameState.ACTIONS_PER_WEEK:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(26, 26)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = UIStyle.GOLD if i < GameState.actions_left else Color(1, 1, 1, 0.15)
		row.add_child(dot)
	return row


func _place_box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color.darkened(0.45)
	s.set_corner_radius_all(12)
	s.border_width_left = 8
	s.border_color = color
	s.set_content_margin_all(12)
	return s


func _on_place(id: StringName) -> void:
	match id:
		&"gym":
			_open_gym()
		&"work":
			_open_simple(tr("PLACE_WORK"), tr("WORK_DESC").format({"pay": WeekActions.WORK_PAY, "energy": WeekActions.WORK_ENERGY}),
					tr("WORK_DO"), _do_work, WeekActions.can_work(GameState))
		&"home":
			_open_simple(tr("PLACE_HOME"), tr("HOME_DESC").format({"energy": WeekActions.REST_ENERGY}),
					tr("HOME_DO"), _do_rest, true)
		_:
			_show_toast(tr("HUB_SOON"))


func _show_toast(text: String, color: Color = UIStyle.GOLD) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	var t := _toast.create_tween()
	t.tween_interval(2.2)
	t.tween_property(_toast, "modulate:a", 0.0, 0.5)


# --- Ventanas (gimnasio, trabajo, casa, fin de semana) ---

## Abre una ventana encima del hub. Devuelve la caja donde va el contenido.
func _open_overlay(title: String) -> VBoxContainer:
	_close_overlay()
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := UIStyle.panel()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UIStyle.label(title, 44, UIStyle.GOLD, 10))
	UIStyle.pop_in.call_deferred(panel)
	return box


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _open_gym() -> void:
	var box := _open_overlay(tr("PLACE_GYM"))
	var mult: float = WeekActions.session_mult(GameState)
	if mult < 1.0:
		box.add_child(UIStyle.label(tr("GYM_WEAK").format({"pct": roundi(mult * 100)}), 22, Color(0.95, 0.65, 0.2), 5))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for t in WeekActions.TRAININGS:
		var b := UIStyle.button("%s\n%s" % [tr(t.name_key), _training_effect(t)], _do_train.bind(t), false)
		b.custom_minimum_size = Vector2(470, 92)
		b.add_theme_font_size_override("font_size", 24)
		b.disabled = not WeekActions.can_train(GameState, t)
		if b.disabled:
			b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
			b.add_theme_stylebox_override("disabled", UIStyle.choice_box(false))
		grid.add_child(b)
	box.add_child(grid)
	var back := UIStyle.button(tr("CREATE_BACK"), _close_overlay, false)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)


## "Potencia ++  Mentón +   (-30 energía)"
func _training_effect(t: TrainingData) -> String:
	var parts: PackedStringArray = []
	if t.all_stats:
		parts.append(tr("TRAINING_ALL_STATS"))
	else:
		parts.append(tr(_stat_key(t.main_stat)) + " ++")
		if t.side_stat != &"":
			parts.append(tr(_stat_key(t.side_stat)) + " +")
	return "%s   %s" % ["  ".join(parts), tr("ENERGY_COST").format({"n": t.energy_cost})]


static func _stat_key(stat: StringName) -> String:
	return "STAT_" + String(stat).to_upper()


func _open_simple(title: String, desc: String, action_text: String, action: Callable, enabled: bool) -> void:
	var box := _open_overlay(title)
	var d := UIStyle.label(desc, 26, UIStyle.TEXT, 6)
	d.custom_minimum_size = Vector2(640, 0)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(d)
	if not enabled:
		box.add_child(UIStyle.label(tr("TOO_TIRED"), 22, Color(0.95, 0.65, 0.2), 5))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.add_child(UIStyle.button(tr("CREATE_BACK"), _close_overlay, false))
	var go := UIStyle.button(action_text, action)
	go.disabled = not enabled
	row.add_child(go)
	box.add_child(row)
	if enabled:
		go.grab_focus.call_deferred()


# --- Acciones ---

func _do_train(t: TrainingData) -> void:
	var r: Dictionary = WeekActions.train(GameState, t)
	var gains: Dictionary = r["gains"]
	var parts: PackedStringArray = []
	for stat in gains:
		parts.append("+%d %s" % [gains[stat], tr(_stat_key(stat))])
	var text: String = "  ".join(parts) if not parts.is_empty() else tr("GYM_NO_GAIN")
	_after_action(text, r["week"])


func _do_work() -> void:
	var r: Dictionary = WeekActions.work(GameState)
	_after_action(tr("WORK_DONE").format({"pay": r["money"]}), r["week"])


func _do_rest() -> void:
	var r: Dictionary = WeekActions.rest(GameState)
	_after_action(tr("HOME_DONE").format({"energy": r["energy"]}), r["week"])


## Después de cada acción: guardar, rearmar el hub, mostrar el resultado y, si pasó la semana, el resumen.
func _after_action(text: String, week: Dictionary) -> void:
	SaveManager.save()
	_close_overlay()
	_build()
	_show_toast(text, StatBars.UP_COLOR)
	if not week.is_empty():
		_show_week_summary(week)


func _show_week_summary(week: Dictionary) -> void:
	var box := _open_overlay(tr("WEEK_END_TITLE").format({"week": GameState.week_of_year()}))
	if week.get("birthday", false):
		box.add_child(UIStyle.label(tr("WEEK_BIRTHDAY").format({"age": GameState.age()}), 30, UIStyle.GOLD, 6))
	box.add_child(UIStyle.label(tr("WEEK_EXPENSES").format({"n": week["expenses"]}), 28, UIStyle.TEXT, 6))
	box.add_child(UIStyle.label(tr("WEEK_ENERGY").format({"n": week["energy"]}), 28, UIStyle.TEXT, 6))
	if week.get("in_debt", false):
		var warn := UIStyle.label(tr("WEEK_DEBT_WARNING"), 24, UIStyle.RED, 5)
		warn.custom_minimum_size = Vector2(640, 0)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(warn)
	var ok := UIStyle.button(tr("WEEK_CONTINUE"), _close_overlay)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ok)
	ok.grab_focus.call_deferred()


func _go_menu() -> void:
	SaveManager.save()
	SceneRouter.go_title()
