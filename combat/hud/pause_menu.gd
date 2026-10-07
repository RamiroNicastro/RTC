class_name PauseMenu
extends CanvasLayer
## Pausa del combate: botón ⏸ siempre visible (también en el celular) y menú SEGUIR / SALIR.
##
## Solo llama a CombatScene.set_paused() y emite su señal quit_requested; no decide qué pasa al salir
## (eso lo decide el modo que lanzó el combate: arcade, práctica o, más adelante, la carrera).
## process_mode ALWAYS: funciona aunque algún día se use get_tree().paused.

var _combat: CombatScene
var _button: Button
var _overlay: Control
var _resume: Button


func setup(combat: CombatScene) -> void:
	_combat = combat
	combat.pause_changed.connect(_on_pause_changed)


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button = Button.new()
	_button.text = "II"
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(64, 56)
	_button.add_theme_font_override("font", UIStyle.font())
	_button.add_theme_font_size_override("font_size", 26)
	_button.modulate.a = 0.75
	_button.pressed.connect(func() -> void: _combat.set_paused(true))
	add_child(_button)
	get_viewport().size_changed.connect(_place_button)
	_place_button()

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	box.add_child(UIStyle.label(tr("PAUSE_TITLE"), 90, UIStyle.GOLD, 14))
	_resume = UIStyle.button(tr("PAUSE_RESUME"), func() -> void: _combat.set_paused(false))
	box.add_child(_resume)
	box.add_child(UIStyle.button(tr("PAUSE_QUIT"), func() -> void:
		_combat.set_paused(false)
		_combat.quit_requested.emit(), false))


## Arriba a la derecha del reloj (no tapa las barras ni el reloj).
func _place_button() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	_button.position = Vector2(view.x * 0.5 + 70.0, 18.0)


func _on_pause_changed(paused: bool) -> void:
	_overlay.visible = paused
	_button.visible = not paused
	if paused:
		_resume.grab_focus()
