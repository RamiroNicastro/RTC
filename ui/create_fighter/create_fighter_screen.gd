class_name CreateFighterScreen
extends Control
## Pantalla "Crear peleador": nombre, apodo y estilo (que cambia las estadísticas).
##
## Guarda en PlayerFighter (user://). Si `for_career` está activo, además arranca una carrera
## nueva (GameState + SaveManager) y va al hub; si no, va a `next_scene`.
## NO calcula números del combate: muestra las estadísticas del estilo tal cual (1 a 100).
## Teclado: Esc vuelve sin guardar.

const TITLE_SCENE: String = "res://ui/title/title_screen.tscn"
## Adónde ir después de guardar. El título lo cambia (por ejemplo, al Arcade la primera vez).
static var next_scene: String = TITLE_SCENE
## true = esta creación arranca una carrera nueva.
static var for_career: bool = false

var _player: PlayerFighter = PlayerFighter.load_fighter()
var _name_edit: LineEdit
var _nick_edit: LineEdit
var _style_buttons: Array[Button] = []
var _desc: Label
var _bars: StatBars


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

	box.add_child(UIStyle.label(tr("CAREER_NEW_TITLE" if for_career else "CREATE_TITLE"), 56, UIStyle.GOLD, 12))

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
	_bars = StatBars.new()
	var bars_center := CenterContainer.new()
	bars_center.add_child(_bars)
	inner.add_child(bars_center)
	if for_career:
		inner.add_child(UIStyle.label(tr("CAREER_NEW_HINT"), 20, UIStyle.GOLD, 5))
	box.add_child(panel)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	actions.add_child(UIStyle.button(tr("CREATE_BACK"), _go_back, false))
	var done := UIStyle.button(tr("CAREER_START" if for_career else "CREATE_DONE"), _confirm)
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
	_bars.show_stats(style)


func _confirm() -> void:
	_player.full_name = PlayerFighter.clean_name(_name_edit.text)
	_player.nickname = PlayerFighter.clean_name(_nick_edit.text)
	if for_career and _player.full_name.is_empty() and _player.nickname.is_empty():
		# En la carrera el peleador necesita un nombre: se marca el campo y no se avanza.
		_name_edit.grab_focus()
		_name_edit.placeholder_text = tr("CAREER_NEED_NAME")
		return
	_player.save()
	var target: String = next_scene
	if for_career:
		GameState.new_career(_player)
		SaveManager.save()
		target = SceneRouter.HUB
	_reset_static()
	SceneRouter.go(target)


func _go_back() -> void:
	_reset_static()
	SceneRouter.go_title()


static func _reset_static() -> void:
	next_scene = TITLE_SCENE
	for_career = false
