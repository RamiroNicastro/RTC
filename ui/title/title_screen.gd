extends Control
## Pantalla de título (prototipo): Modo Arcade, Práctica y récords.
##
## Es el punto de entrada del juego mientras no exista la carrera (Fase 2).

const ARCADE_SCENE: String = "res://modes/arcade/arcade_run.tscn"
const PRACTICE_SCENE: String = "res://debug/combat_sandbox.tscn"
const CREATE_SCENE: String = "res://ui/create_fighter/create_fighter_screen.tscn"
const TITLE_SCENE: String = "res://ui/title/title_screen.tscn"

var _time: float = 0.0
var _title: Label


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

	var arcade := UIStyle.button(tr("MENU_ARCADE"), _go_arcade)
	box.add_child(arcade)
	box.add_child(UIStyle.button(tr("MENU_EDIT_FIGHTER"), _go_create.bind(TITLE_SCENE), false))
	box.add_child(UIStyle.button(tr("MENU_PRACTICE"), func() -> void: get_tree().change_scene_to_file(PRACTICE_SCENE), false))

	if PlayerFighter.exists():
		var me := PlayerFighter.load_fighter()
		box.add_child(UIStyle.label(tr("MENU_YOUR_FIGHTER").format({"name": me.display_name(tr("ARCADE_YOU")),
				"style": tr(me.style().name_key)}), 24, Color(0.4, 0.7, 1.0), 5))

	var rec := ArcadeRecords.load_records()
	var rec_text: String = tr("MENU_RECORD").format({"score": rec.best_score, "titles": rec.championships})
	box.add_child(UIStyle.label(rec_text, 22, UIStyle.MUTED, 5))
	box.add_child(UIStyle.label(tr("MENU_HINT"), 18, Color(0.5, 0.52, 0.58), 4))
	arcade.grab_focus()
	await get_tree().process_frame
	var i: int = 0
	for c in box.get_children():
		if c is Control:
			UIStyle.pop_in(c, i * 0.06)
			i += 1


## La primera vez, antes del Arcade se crea el peleador.
func _go_arcade() -> void:
	if PlayerFighter.exists():
		get_tree().change_scene_to_file(ARCADE_SCENE)
	else:
		_go_create(ARCADE_SCENE)


func _go_create(then: String) -> void:
	CreateFighterScreen.next_scene = then
	get_tree().change_scene_to_file(CREATE_SCENE)


func _process(delta: float) -> void:
	_time += delta
	if _title != null:
		_title.pivot_offset = _title.size * 0.5
		_title.scale = Vector2.ONE * (1.0 + 0.025 * sin(_time * 3.0))
