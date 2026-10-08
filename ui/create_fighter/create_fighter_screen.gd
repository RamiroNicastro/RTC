class_name CreateFighterScreen
extends Control
## Pantalla "Crear peleador": nombre, apodo y estilo (que cambia las estadísticas).
##
## Guarda en PlayerFighter (user://) y sigue a `next_scene`. NO calcula números del combate:
## muestra las estadísticas del estilo tal cual (1 a 100).
## Teclado: Esc vuelve sin guardar.

const TITLE_SCENE: String = "res://ui/title/title_screen.tscn"
## Adónde ir después de guardar. El título lo cambia (por ejemplo, al Arcade la primera vez).
static var next_scene: String = TITLE_SCENE

## Estadísticas en el orden en que se muestran: [propiedad, clave de texto].
const STATS: Array = [
	[&"power", "STAT_POWER"], [&"speed", "STAT_SPEED"], [&"cardio", "STAT_CARDIO"],
	[&"chin", "STAT_CHIN"], [&"technique", "STAT_TECHNIQUE"], [&"defense", "STAT_DEFENSE"],
]
const BAR_SIZE := Vector2(220, 18)
const UP_COLOR := Color(0.35, 0.8, 0.45)
const DOWN_COLOR := Color(0.9, 0.4, 0.3)

var _player: PlayerFighter = PlayerFighter.load_fighter()
var _name_edit: LineEdit
var _nick_edit: LineEdit
var _style_buttons: Array[Button] = []
var _desc: Label
## Por cada estadística: [relleno de la barra, número].
var _bars: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UIStyle.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	box.add_child(UIStyle.label(tr("CREATE_TITLE"), 56, UIStyle.GOLD, 12))

	var names := HBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 24)
	_name_edit = _line_edit(tr("CREATE_NAME"), _player.full_name)
	_nick_edit = _line_edit(tr("CREATE_NICKNAME"), _player.nickname)
	names.add_child(_name_edit)
	names.add_child(_nick_edit)
	box.add_child(names)

	box.add_child(UIStyle.label(tr("CREATE_STYLE"), 26, UIStyle.MUTED, 6))
	var styles := HBoxContainer.new()
	styles.alignment = BoxContainer.ALIGNMENT_CENTER
	styles.add_theme_constant_override("separation", 10)
	for s in PlayerFighter.STYLES:
		var b := UIStyle.button(tr(s.name_key), _select_style.bind(s.id), false)
		b.custom_minimum_size = Vector2(228, 64)
		b.add_theme_font_size_override("font_size", 24)
		_style_buttons.append(b)
		styles.add_child(b)
	box.add_child(styles)

	var panel := UIStyle.panel()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)
	_desc = UIStyle.label("", 22, UIStyle.TEXT, 5)
	_desc.custom_minimum_size = Vector2(900, 0)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_desc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 48)
	grid.add_theme_constant_override("v_separation", 6)
	for st in STATS:
		grid.add_child(_stat_row(tr(st[1])))
	var grid_center := CenterContainer.new()
	grid_center.add_child(grid)
	inner.add_child(grid_center)
	box.add_child(panel)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	actions.add_child(UIStyle.button(tr("CREATE_BACK"), _go_back, false))
	var done := UIStyle.button(tr("CREATE_DONE"), _confirm)
	actions.add_child(done)
	box.add_child(actions)

	_select_style(_player.style_id)
	done.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
		_go_back()


func _line_edit(placeholder: String, text: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.max_length = PlayerFighter.MAX_NAME_LENGTH
	e.custom_minimum_size = Vector2(420, 64)
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_theme_font_override("font", UIStyle.font())
	e.add_theme_font_size_override("font_size", 30)
	e.select_all_on_focus = true
	var field := StyleBoxFlat.new()
	field.bg_color = Color(1, 1, 1, 0.08)
	field.set_corner_radius_all(10)
	field.border_width_bottom = 3
	field.border_color = UIStyle.MUTED
	e.add_theme_stylebox_override("normal", field)
	var field_focus: StyleBoxFlat = field.duplicate()
	field_focus.border_color = UIStyle.GOLD
	e.add_theme_stylebox_override("focus", field_focus)
	return e


func _stat_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := UIStyle.label(text, 22, UIStyle.TEXT, 5)
	name_label.custom_minimum_size = Vector2(150, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.12)
	bar_bg.custom_minimum_size = BAR_SIZE
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.size = Vector2(0, BAR_SIZE.y)
	bar_bg.add_child(fill)
	# Marca del 50 (el valor "normal").
	var mid := ColorRect.new()
	mid.color = Color(1, 1, 1, 0.5)
	mid.position = Vector2(BAR_SIZE.x * 0.5 - 1, -3)
	mid.size = Vector2(2, BAR_SIZE.y + 6)
	bar_bg.add_child(mid)
	row.add_child(bar_bg)
	var number := UIStyle.label("", 22, UIStyle.TEXT, 5)
	number.custom_minimum_size = Vector2(44, 0)
	row.add_child(number)
	_bars.append([fill, number])
	return row


func _select_style(id: StringName) -> void:
	_player.style_id = id
	var style: FighterStyle = _player.style()
	for i in _style_buttons.size():
		var selected: bool = PlayerFighter.STYLES[i].id == style.id
		for state in ["normal", "hover", "pressed"]:
			_style_buttons[i].add_theme_stylebox_override(state, UIStyle.choice_box(selected))
		_style_buttons[i].add_theme_color_override("font_color", UIStyle.TEXT if selected else UIStyle.MUTED)
		_style_buttons[i].add_theme_color_override("font_hover_color", UIStyle.TEXT if selected else UIStyle.MUTED)
	_desc.text = tr(style.desc_key)
	for i in STATS.size():
		var value: int = style.get(STATS[i][0])
		var fill: ColorRect = _bars[i][0]
		var number: Label = _bars[i][1]
		var target: float = BAR_SIZE.x * value / 100.0
		fill.color = UP_COLOR if value > 50 else (DOWN_COLOR if value < 50 else UIStyle.MUTED)
		fill.create_tween().tween_property(fill, "size:x", target, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		number.text = str(value)
		number.add_theme_color_override("font_color", fill.color.lightened(0.3))


func _confirm() -> void:
	_player.full_name = PlayerFighter.clean_name(_name_edit.text)
	_player.nickname = PlayerFighter.clean_name(_nick_edit.text)
	_player.save()
	var target: String = next_scene
	next_scene = TITLE_SCENE
	get_tree().change_scene_to_file(target)


func _go_back() -> void:
	next_scene = TITLE_SCENE
	get_tree().change_scene_to_file(TITLE_SCENE)
