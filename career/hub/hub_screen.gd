class_name HubScreen
extends Control
## Hub de la carrera: quién sos, cuándo es, cuánta plata tenés, tu récord, tus estadísticas
## y los 5 lugares (Casa, Gimnasio, Trabajo, Tienda, Arena).
##
## Solo muestra GameState y navega. Los lugares todavía no hacen nada (llegan en las próximas partes).
## Guarda al salir al menú. Teclado: Esc = menú.

## [id, clave de texto, color]. El orden es el de la grilla (2 columnas).
const PLACES: Array = [
	[&"gym", "PLACE_GYM", Color(0.85, 0.35, 0.25)],
	[&"arena", "PLACE_ARENA", Color(0.9, 0.7, 0.2)],
	[&"work", "PLACE_WORK", Color(0.35, 0.55, 0.8)],
	[&"shop", "PLACE_SHOP", Color(0.55, 0.4, 0.75)],
	[&"home", "PLACE_HOME", Color(0.35, 0.65, 0.45)],
]

var _bars: StatBars
var _toast: Label


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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

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

	var places := GridContainer.new()
	places.columns = 2
	places.add_theme_constant_override("h_separation", 14)
	places.add_theme_constant_override("v_separation", 14)
	for p in PLACES:
		var b := UIStyle.button(tr(p[1]), _on_place.bind(p[0]), false)
		b.custom_minimum_size = Vector2(300, 84)
		b.add_theme_stylebox_override("normal", _place_box(p[2]))
		b.add_theme_stylebox_override("hover", _place_box(p[2].lightened(0.15)))
		b.add_theme_stylebox_override("pressed", _place_box(p[2].darkened(0.2)))
		places.add_child(b)
	body.add_child(places)
	box.add_child(body)

	_toast = UIStyle.label("", 24, UIStyle.GOLD, 6)
	_toast.modulate.a = 0.0
	box.add_child(_toast)

	var menu := UIStyle.button(tr("HUB_MENU"), _go_menu, false)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(menu)

	_bars.show_stats(GameState.fighter, false)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
		_go_menu()


func _header() -> Control:
	var panel := UIStyle.panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	var who := VBoxContainer.new()
	var name_label := UIStyle.label(GameState.display_name(), 44, Color(0.4, 0.7, 1.0), 10)
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
	row.add_child(_info("$ %d" % GameState.money, tr("HUB_MONEY")))
	row.add_child(_info("%d-%d-%d" % [GameState.wins, GameState.losses, GameState.draws],
			tr("HUB_RECORD").format({"kos": GameState.kos})))
	panel.custom_minimum_size = Vector2(1180, 0)
	panel.add_child(row)
	return panel


## Un dato del encabezado: valor grande y explicación chica.
func _info(value: String, caption: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(UIStyle.label(value, 34, UIStyle.TEXT, 8))
	v.add_child(UIStyle.label(caption, 18, UIStyle.MUTED, 4))
	return v


func _place_box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color.darkened(0.45)
	s.set_corner_radius_all(12)
	s.border_width_left = 8
	s.border_color = color
	s.set_content_margin_all(12)
	return s


func _on_place(_id: StringName) -> void:
	# Parte 1: los lugares todavía no están. Se avisa en vez de no hacer nada.
	_toast.text = tr("HUB_SOON")
	_toast.modulate.a = 1.0
	var t := _toast.create_tween()
	t.tween_interval(1.2)
	t.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _go_menu() -> void:
	SaveManager.save()
	SceneRouter.go_title()
