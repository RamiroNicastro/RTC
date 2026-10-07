extends Control
## Pantalla de título (prototipo): Modo Arcade, Práctica y récords.
##
## Es el punto de entrada del juego mientras no exista la carrera (Fase 2).

const ARCADE_SCENE: String = "res://modes/arcade/arcade_run.tscn"
const PRACTICE_SCENE: String = "res://debug/combat_sandbox.tscn"

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

	var arcade := UIStyle.button(tr("MENU_ARCADE"), func() -> void: get_tree().change_scene_to_file(ARCADE_SCENE))
	box.add_child(arcade)
	box.add_child(UIStyle.button(tr("MENU_PRACTICE"), func() -> void: get_tree().change_scene_to_file(PRACTICE_SCENE), false))

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


func _process(delta: float) -> void:
	_time += delta
	if _title != null:
		_title.pivot_offset = _title.size * 0.5
		_title.scale = Vector2.ONE * (1.0 + 0.025 * sin(_time * 3.0))
