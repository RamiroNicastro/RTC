extends Control
## Pantalla de título: Carrera (continuar o nueva), Modo Arcade, Mi peleador y Práctica.
##
## Solo navega (SceneRouter). La carrera se carga con SaveManager antes de ir al hub.

var _time: float = 0.0
var _title: Label
## Segundo toque en "Nueva carrera" cuando ya hay una guardada (para no borrarla sin querer).
var _confirm_new: bool = false
var _new_button: Button


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
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	_title = UIStyle.label(tr("GAME_TITLE"), 96, UIStyle.GOLD, 14)
	box.add_child(_title)
	box.add_child(UIStyle.label(tr("GAME_SUBTITLE"), 26, UIStyle.MUTED, 6))
	box.add_child(Control.new())

	var has_career: bool = SaveManager.has_save()
	var main: Button
	if has_career:
		main = UIStyle.button(tr("MENU_CONTINUE_CAREER"), _continue_career)
	else:
		main = UIStyle.button(tr("MENU_NEW_CAREER"), _new_career)
	main.custom_minimum_size = Vector2(560, 92)
	main.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(main)

	var others := HBoxContainer.new()
	others.alignment = BoxContainer.ALIGNMENT_CENTER
	others.add_theme_constant_override("separation", 12)
	if has_career:
		_new_button = _small_button(tr("MENU_NEW_CAREER"), _new_career)
		others.add_child(_new_button)
	others.add_child(_small_button(tr("MENU_ARCADE"), _go_arcade))
	others.add_child(_small_button(tr("MENU_EDIT_FIGHTER"), _go_create.bind(SceneRouter.TITLE)))
	others.add_child(_small_button(tr("MENU_PRACTICE"), SceneRouter.go.bind(SceneRouter.PRACTICE)))
	box.add_child(others)

	if PlayerFighter.exists():
		var me := PlayerFighter.load_fighter()
		box.add_child(UIStyle.label(tr("MENU_YOUR_FIGHTER").format({"name": me.display_name(tr("ARCADE_YOU")),
				"style": tr(me.style().name_key)}), 24, Color(0.4, 0.7, 1.0), 5))

	var rec := ArcadeRecords.load_records()
	var rec_text: String = tr("MENU_RECORD").format({"score": rec.best_score, "titles": rec.championships})
	box.add_child(UIStyle.label(rec_text, 22, UIStyle.MUTED, 5))
	box.add_child(UIStyle.label(tr("MENU_HINT"), 18, Color(0.5, 0.52, 0.58), 4))
	main.grab_focus()
	await get_tree().process_frame
	var i: int = 0
	for c in box.get_children():
		if c is Control:
			UIStyle.pop_in(c, i * 0.06)
			i += 1


## La primera vez, antes del Arcade se crea el peleador.
func _go_arcade() -> void:
	if PlayerFighter.exists():
		SceneRouter.go(SceneRouter.ARCADE)
	else:
		_go_create(SceneRouter.ARCADE)


func _go_create(then: String) -> void:
	CreateFighterScreen.next_scene = then
	CreateFighterScreen.for_career = false
	SceneRouter.go(SceneRouter.CREATE_FIGHTER)


func _continue_career() -> void:
	if SaveManager.load_slot():
		SceneRouter.go_hub()


## Si ya hay una carrera guardada, el primer toque pide confirmación (la nueva la reemplaza).
func _new_career() -> void:
	if SaveManager.has_save() and not _confirm_new:
		_confirm_new = true
		_new_button.text = tr("MENU_NEW_CAREER_CONFIRM")
		return
	CreateFighterScreen.for_career = true
	SceneRouter.go(SceneRouter.CREATE_FIGHTER)


func _small_button(text: String, on_pressed: Callable) -> Button:
	var b := UIStyle.button(text, on_pressed, false)
	b.custom_minimum_size = Vector2(270, 70)
	b.add_theme_font_size_override("font_size", 26)
	return b


func _process(delta: float) -> void:
	_time += delta
	if _title != null:
		_title.pivot_offset = _title.size * 0.5
		_title.scale = Vector2.ONE * (1.0 + 0.025 * sin(_time * 3.0))
