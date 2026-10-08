class_name ArenaScreen
extends Node
## La Arena de la carrera: ofertas de la semana → pelea → resultado → hub.
##
## Usa el combate tal cual (R2): ArenaRules arma el FightSetup y aplica el FightResult.
## El resultado se aplica y se guarda apenas termina la pelea (antes del botón CONTINUAR).
## Abandonar desde la pausa vuelve al hub sin consecuencias (la oferta sigue).
## Teclado: Esc vuelve al hub (en la pelea, Esc es pausa).

const COMBAT_SCENE: PackedScene = preload("res://combat/combat_scene.tscn")
## Segundos después del final para mostrar CONTINUAR (primero se ve el KO y el resultado).
const CONTINUE_BUTTON_DELAY: float = 2.5
const LEVEL_KEYS: Dictionary = {
	FightOffer.Level.EASY: "ARENA_EASY",
	FightOffer.Level.EVEN: "ARENA_EVEN",
	FightOffer.Level.HARD: "ARENA_HARD",
}
const LEVEL_COLORS: Dictionary = {
	FightOffer.Level.EASY: Color(0.45, 0.85, 0.5),
	FightOffer.Level.EVEN: Color(1.0, 0.82, 0.25),
	FightOffer.Level.HARD: Color(0.95, 0.35, 0.3),
}
const ME_COLOR := Color(0.4, 0.7, 1.0)

var _ui: CanvasLayer
var _combat: CombatScene
## Botones de las ofertas (las pruebas los leen).
var _fight_buttons: Array[Button] = []
## Resumen del último resultado (las pruebas lo leen).
var _last_summary: Dictionary = {}


func _ready() -> void:
	if not GameState.active and not SaveManager.load_slot():
		SceneRouter.go_title.call_deferred()
		return
	_ui = CanvasLayer.new()
	_ui.layer = 30
	add_child(_ui)
	_show_offers()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE and _combat == null:
		_back_to_hub()


# --- Ofertas ---

func _show_offers() -> void:
	_clear()
	var box := _screen()
	box.add_child(UIStyle.label(tr("PLACE_ARENA"), 42, UIStyle.GOLD, 10))
	box.add_child(UIStyle.label(tr("ARENA_STATUS").format({"rank": GameState.rank, "energy": GameState.energy}), 22, UIStyle.MUTED, 5))
	var offers: Array[FightOffer] = ArenaRules.weekly_offers(GameState)
	SaveManager.save()
	var can: bool = ArenaRules.can_fight(GameState)
	var back := UIStyle.button(tr("ARENA_BACK"), _back_to_hub, false)
	back.custom_minimum_size = Vector2(320, 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if offers.is_empty():
		box.add_child(UIStyle.label(tr("ARENA_NO_FIGHTS"), 28, UIStyle.TEXT, 6))
		box.add_child(back)
		_animate(box, back)
		return
	if not can:
		box.add_child(UIStyle.label(tr("ARENA_TOO_TIRED").format({"n": ArenaRules.MIN_ENERGY}), 24, Color(0.95, 0.65, 0.2), 5))
	var assigned: bool = offers[0].kind == FightOffer.Kind.ASSIGNED
	box.add_child(UIStyle.label(tr("ARENA_ASSIGNED_HINT" if assigned else "ARENA_CHOICE_HINT"), 22, UIStyle.TEXT, 5))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_fight_buttons.clear()
	for o in offers:
		row.add_child(_card(o, can))
	box.add_child(row)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	bottom.add_child(back)
	if assigned:
		var decline := UIStyle.button(tr("ARENA_DECLINE"), _decline, false)
		decline.custom_minimum_size = Vector2(320, 60)
		bottom.add_child(decline)
	box.add_child(bottom)
	_animate(box, _fight_buttons[0] if can else back)


## Carta de una oferta: dificultad, rival, récord, estilo, bolsa y comparación de estadísticas.
func _card(o: FightOffer, can: bool) -> PanelContainer:
	var panel := UIStyle.panel()
	panel.custom_minimum_size = Vector2(380, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var tag: String = tr("ARENA_ASSIGNED") if o.kind == FightOffer.Kind.ASSIGNED else tr(LEVEL_KEYS[o.level])
	v.add_child(UIStyle.label(tag, 22, LEVEL_COLORS[o.level], 5))
	v.add_child(UIStyle.label("\"%s\"" % o.rival.nickname, 30, o.rival.color.lightened(0.25), 8))
	v.add_child(UIStyle.label(o.rival.full_name, 22, UIStyle.TEXT, 5))
	v.add_child(UIStyle.label(tr("ARENA_RIVAL_LINE").format({"rank": o.rank, "record": o.record_text(), "kos": o.kos}), 20, UIStyle.MUTED, 4))
	v.add_child(UIStyle.label(tr(o.profile().style_name_key), 20, UIStyle.MUTED, 4))
	v.add_child(_compare(o))
	v.add_child(UIStyle.label(tr("ARENA_PURSE").format({"n": o.purse}), 26, UIStyle.GOLD, 6))
	var b := UIStyle.button(tr("ARENA_ACCEPT") if o.kind == FightOffer.Kind.ASSIGNED else tr("ARENA_FIGHT"), _start_fight.bind(o))
	b.custom_minimum_size = Vector2(340, 60)
	b.disabled = not can
	_fight_buttons.append(b)
	v.add_child(b)
	return panel


## Tabla "vos contra él" con las 6 estadísticas (el número más alto, resaltado).
func _compare(o: FightOffer) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 0)
	g.add_child(Control.new())
	g.add_child(UIStyle.label(tr("ARENA_YOU"), 16, ME_COLOR, 4))
	g.add_child(UIStyle.label(tr("ARENA_HIM"), 16, o.rival.color.lightened(0.25), 4))
	for st in StatBars.STATS:
		var mine: int = GameState.fighter.get(st[0])
		var his: int = o.rival.get(st[0])
		var name_label := UIStyle.label(tr(st[1]), 16, UIStyle.TEXT, 4)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(name_label)
		g.add_child(UIStyle.label(str(mine), 16, StatBars.UP_COLOR if mine > his else UIStyle.MUTED, 4))
		g.add_child(UIStyle.label(str(his), 16, StatBars.DOWN_COLOR if his > mine else UIStyle.MUTED, 4))
	return g


func _decline() -> void:
	ArenaRules.decline(GameState)
	SaveManager.save()
	_back_to_hub()


# --- Pelea ---

func _start_fight(o: FightOffer) -> void:
	if not ArenaRules.can_fight(GameState):
		return
	_clear()
	_combat = COMBAT_SCENE.instantiate()
	add_child(_combat)
	_combat.start(ArenaRules.build_fight_setup(GameState, o))
	_combat.touch_controls.visible = OS.has_feature("mobile")
	_combat.fight_finished.connect(_on_fight_finished.bind(o))
	_combat.quit_requested.connect(_back_to_hub)


func _on_fight_finished(r: FightResult, o: FightOffer) -> void:
	_last_summary = ArenaRules.apply_result(GameState, o, r)
	SaveManager.save()
	await get_tree().create_timer(CONTINUE_BUTTON_DELAY).timeout
	if not is_inside_tree():
		return
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var cont := UIStyle.button(tr("ARCADE_CONTINUE_FIGHT"), _show_result.bind(r))
	holder.add_child(cont)
	var view: Vector2 = get_viewport().get_visible_rect().size
	cont.position = Vector2((view.x - cont.custom_minimum_size.x) * 0.5, view.y - cont.custom_minimum_size.y - 24.0)
	UIStyle.pop_in(cont)
	cont.grab_focus()


# --- Resultado ---

func _show_result(r: FightResult) -> void:
	_clear()
	var s: Dictionary = _last_summary
	var box := _screen()
	var title: String = tr("ARENA_WON") if s["won"] else (tr("RESULT_DRAW_TITLE") if s["draw"] else tr("ARENA_LOST"))
	var color: Color = StatBars.UP_COLOR if s["won"] else (UIStyle.GOLD if s["draw"] else UIStyle.RED)
	box.add_child(UIStyle.label(title, 64, color, 14))
	box.add_child(UIStyle.label(tr(r.method_key()), 28, UIStyle.TEXT, 6))
	box.add_child(UIStyle.label(tr("ARENA_PAY").format({"n": s["pay"]}) + ("  " + tr("ARENA_KO_BONUS") if s["ko"] else ""), 32, UIStyle.GOLD, 8))
	var rank_line: String = tr("ARENA_RANK_CHANGE").format({"before": s["rank_before"], "after": s["rank_after"]})
	box.add_child(UIStyle.label(rank_line, 28, UIStyle.TEXT, 6))
	box.add_child(UIStyle.label(tr("ARENA_RECORD").format({"record": "%d-%d-%d" % [GameState.wins, GameState.losses, GameState.draws],
			"kos": GameState.kos}), 22, UIStyle.MUTED, 5))
	var energy_color: Color = UIStyle.TEXT if s["energy"] >= ArenaRules.MIN_ENERGY else Color(0.95, 0.65, 0.2)
	box.add_child(UIStyle.label(tr("ARENA_ENERGY_AFTER").format({"n": s["energy"]}), 24, energy_color, 5))
	var week: Dictionary = s["week"]
	box.add_child(UIStyle.label(tr("WEEK_EXPENSES").format({"n": week["expenses"]}), 22, UIStyle.MUTED, 5))
	if week.get("birthday", false):
		box.add_child(UIStyle.label(tr("WEEK_BIRTHDAY").format({"age": GameState.age()}), 24, UIStyle.GOLD, 5))
	if week.get("in_debt", false):
		box.add_child(UIStyle.label(tr("WEEK_DEBT_WARNING"), 22, UIStyle.RED, 5))
	var back := UIStyle.button(tr("ARENA_BACK"), _back_to_hub)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	_animate(box, back)


func _back_to_hub() -> void:
	SceneRouter.go_hub()


# --- Ayudas de pantalla ---

func _screen() -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(UIStyle.BG, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	return box


func _animate(box: VBoxContainer, focus: Control) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var i: int = 0
	for c in box.get_children():
		if c is Control:
			UIStyle.pop_in(c, i * 0.05)
			i += 1
	if is_instance_valid(focus):
		focus.grab_focus()


func _clear() -> void:
	for c in _ui.get_children():
		c.queue_free()
	if _combat != null:
		_combat.queue_free()
		_combat = null
