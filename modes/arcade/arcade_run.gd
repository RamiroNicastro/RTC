extends Node
## Modo Arcade (prototipo, Fase 1): escalera de rivales con puntaje, récords y "una más".
##
## Flujo:  VS → PELEA → (gana) CONTEO DE PUNTOS → VS del siguiente … → ¡CAMPEÓN!
##                    → (pierde) GAME OVER: continuar (−50 % de puntos) o menú
##                    → (empate) revancha contra el mismo rival
## Usa el combate tal cual (R2): arma un FightSetup y escucha fight_finished(FightResult).
## Teclado: Enter/J aceptan, Esc vuelve al menú (en la pelea, Esc es pausa).
## Ritmo arcade: rounds cortos (ROUND_SECONDS) y, al terminar cada pelea, un botón CONTINUAR
## (el jugador decide cuándo seguir; así puede mirar la pantalla de resultado).

const COMBAT_SCENE: PackedScene = preload("res://combat/combat_scene.tscn")
const TITLE_SCENE: String = "res://ui/title/title_screen.tscn"
## Segundos después del final para mostrar el botón CONTINUAR (primero se ve el KO y el resultado).
const CONTINUE_BUTTON_DELAY: float = 2.5
const ROUND_SECONDS: float = 45.0
const CONTINUE_PENALTY: float = 0.5

var _ladder: Array[ArcadeRivals.Rival] = ArcadeRivals.ladder()
var _stage: int = 0
var _score: int = 0
var _records: ArcadeRecords = ArcadeRecords.load_records()
var _combat: CombatScene
var _ui: CanvasLayer
var _bg: ColorRect
## La partida ya se contó en los récords (para no contarla dos veces si continúa).
var _run_counted: bool = false


func _ready() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 30
	add_child(_ui)
	_show_vs()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	# Durante la pelea, Esc lo maneja el combate (pausa). En las demás pantallas vuelve al menú.
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE and _combat == null:
		get_tree().change_scene_to_file(TITLE_SCENE)


# --- Pantallas ---

func _show_vs() -> void:
	_clear()
	var rival: ArcadeRivals.Rival = _ladder[_stage]
	var box := _screen()
	box.add_child(UIStyle.label(tr("ARCADE_STAGE").format({"n": _stage + 1, "total": _ladder.size()}), 28, UIStyle.MUTED))
	var vs := HBoxContainer.new()
	vs.alignment = BoxContainer.ALIGNMENT_CENTER
	vs.add_theme_constant_override("separation", 40)
	vs.add_child(UIStyle.label(tr("ARCADE_YOU"), 64, Color(0.4, 0.7, 1.0), 12))
	vs.add_child(UIStyle.label("VS", 80, UIStyle.GOLD, 14))
	var rival_box := VBoxContainer.new()
	rival_box.add_child(UIStyle.label("\"%s\"" % rival.nickname, 64, rival.color.lightened(0.2), 12))
	rival_box.add_child(UIStyle.label(rival.full_name, 30, UIStyle.TEXT))
	vs.add_child(rival_box)
	box.add_child(vs)
	box.add_child(UIStyle.label("%s  ·  %s  ·  %s" % [
		tr(rival.profile.style_name_key),
		tr("AI_DIFFICULTY_" + AIInput.Difficulty.keys()[rival.difficulty]),
		tr("ARCADE_ROUND_ONE") if rival.rounds == 1 else tr("ARCADE_ROUNDS").format({"n": rival.rounds})], 26, UIStyle.TEXT))
	box.add_child(UIStyle.label("“%s”" % tr(rival.quote_key), 26, rival.color.lightened(0.35), 6))
	box.add_child(UIStyle.label(_style_tip(rival.profile), 22, UIStyle.MUTED, 5))
	for c in rival.challenges:
		box.add_child(UIStyle.label(tr("CHALLENGE_LINE").format({"text": tr(ArcadeRivals.challenge_key(c)),
				"bonus": ArcadeRivals.CHALLENGE_BONUS}), 22, UIStyle.GOLD, 5))
	box.add_child(UIStyle.label(tr("ARCADE_SCORE_LINE").format({"score": _score, "best": _records.best_score}), 24, UIStyle.GOLD, 6))
	var go := UIStyle.button(tr("ARCADE_FIGHT"), _start_fight)
	box.add_child(go)
	_animate(box, go)


func _start_fight() -> void:
	_clear()
	var rival: ArcadeRivals.Rival = _ladder[_stage]
	var player := FighterSetup.new()
	player.display_name = tr("ARCADE_YOU")
	player.controller_type = FighterSetup.ControllerType.PLAYER
	player.color = Color(0.2, 0.55, 0.9)
	var enemy := FighterSetup.new()
	enemy.display_name = "\"%s\" %s" % [rival.nickname, rival.full_name.get_slice(" ", 1)]
	enemy.controller_type = FighterSetup.ControllerType.AI
	enemy.ai_profile = rival.profile
	enemy.ai_difficulty = rival.difficulty
	enemy.color = rival.color
	enemy.power_punch = rival.signature
	var setup := FightSetup.new()
	setup.fighter_a = player
	setup.fighter_b = enemy
	setup.rounds = rival.rounds
	setup.round_seconds = ROUND_SECONDS
	_combat = COMBAT_SCENE.instantiate()
	add_child(_combat)
	_combat.start(setup)
	_combat.touch_controls.visible = OS.has_feature("mobile")
	_combat.fight_finished.connect(_on_fight_finished)
	_combat.quit_requested.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))


func _on_fight_finished(r: FightResult) -> void:
	await get_tree().create_timer(CONTINUE_BUTTON_DELAY).timeout
	if not is_inside_tree():
		return
	# Botón CONTINUAR abajo al centro, encima del combate (que sigue visible con su resultado).
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var cont := UIStyle.button(tr("ARCADE_CONTINUE_FIGHT"), func() -> void: _after_fight(r))
	holder.add_child(cont)
	var view: Vector2 = get_viewport().get_visible_rect().size
	cont.position = Vector2((view.x - cont.custom_minimum_size.x) * 0.5, view.y - cont.custom_minimum_size.y - 24.0)
	UIStyle.pop_in(cont)
	cont.grab_focus()


func _after_fight(r: FightResult) -> void:
	if r.winner_index == 0:
		_show_tally(r)
	elif r.is_draw():
		_show_draw()
	else:
		_show_game_over()


func _show_tally(r: FightResult) -> void:
	_clear()
	var rival: ArcadeRivals.Rival = _ladder[_stage]
	var lines: Array = ArcadeScore.breakdown(r, 0, rival.score_mult)
	# Desafíos: los cumplidos suman bonus; los fallados se muestran en 0 (para que den ganas de volver).
	for c in rival.challenges:
		var done: bool = ArcadeRivals.challenge_done(c, r, 0)
		lines.append([ArcadeRivals.challenge_key(c), ArcadeRivals.CHALLENGE_BONUS if done else 0, done])
	var gained: int = ArcadeScore.total(lines, rival.score_mult)
	var box := _screen()
	box.add_child(UIStyle.label(tr("ARCADE_VICTORY"), 72, UIStyle.GOLD, 14))
	var list := VBoxContainer.new()
	box.add_child(list)
	var total_label := UIStyle.label("", 40, UIStyle.TEXT)
	var next_text: String = tr("ARCADE_NEXT") if _stage + 1 < _ladder.size() else tr("ARCADE_FINAL_BELT")
	var next := UIStyle.button(next_text, _advance)
	next.visible = false
	box.add_child(total_label)
	box.add_child(next)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	UIStyle.pop_in(box.get_child(0))
	# Conteo línea por línea, con un ritmo que se disfruta.
	for l in lines:
		await get_tree().create_timer(0.28).timeout
		if not is_inside_tree():
			return
		var is_challenge: bool = l.size() > 2
		var text: String = tr(l[0])
		var color: Color = UIStyle.TEXT if int(l[1]) >= 0 else UIStyle.RED
		if is_challenge:
			text = ("✓ " if l[2] else "✗ ") + text
			color = UIStyle.GOLD if l[2] else UIStyle.MUTED
		var row := UIStyle.label("%s   %+d" % [text, int(l[1])], 28, color, 6)
		list.add_child(row)
		UIStyle.pop_in(row)
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	var before: int = _score
	_score += gained
	total_label.text = tr("ARCADE_MULT").format({"mult": "%.1f" % rival.score_mult, "gained": gained})
	UIStyle.pop_in(total_label)
	var tw := create_tween()
	tw.tween_method(func(v: int) -> void: total_label.text = tr("ARCADE_TOTAL").format({"score": v, "gained": gained}),
			before, _score, 0.9)
	await tw.finished
	if not is_inside_tree():
		return
	next.visible = true
	UIStyle.pop_in(next)
	next.grab_focus()


func _advance() -> void:
	_stage += 1
	if _stage >= _ladder.size():
		_show_champion()
	else:
		_show_vs()


func _show_draw() -> void:
	_clear()
	var box := _screen()
	box.add_child(UIStyle.label(tr("ARCADE_DRAW"), 72, UIStyle.TEXT, 14))
	box.add_child(UIStyle.label(tr("ARCADE_DRAW_HINT"), 26, UIStyle.MUTED))
	var again := UIStyle.button(tr("ARCADE_REMATCH"), _show_vs)
	box.add_child(again)
	_animate(box, again)


func _show_game_over() -> void:
	_clear()
	var is_record: bool = _records.register_run(_score, _stage + 1, false, not _run_counted)
	_run_counted = true
	var box := _screen()
	box.add_child(UIStyle.label(tr("ARCADE_GAME_OVER"), 90, UIStyle.RED, 14))
	box.add_child(UIStyle.label(tr("ARCADE_REACHED").format({"n": _stage + 1, "total": _ladder.size(), "score": _score}), 30, UIStyle.TEXT))
	if is_record and _score > 0:
		box.add_child(UIStyle.label(tr("ARCADE_NEW_RECORD"), 40, UIStyle.GOLD, 10))
	else:
		box.add_child(UIStyle.label(tr("ARCADE_BEST").format({"score": _records.best_score}), 24, UIStyle.MUTED))
	var cont := UIStyle.button(tr("ARCADE_CONTINUE"), func() -> void:
		_score = roundi(_score * CONTINUE_PENALTY)
		_show_vs())
	box.add_child(cont)
	box.add_child(UIStyle.button(tr("ARCADE_MENU"), func() -> void: get_tree().change_scene_to_file(TITLE_SCENE), false))
	_animate(box, cont)


func _show_champion() -> void:
	_clear()
	var is_record: bool = _records.register_run(_score, _ladder.size() + 1, true, not _run_counted)
	_run_counted = true
	var box := _screen()
	box.add_child(UIStyle.label(tr("ARCADE_CHAMPION"), 100, UIStyle.GOLD, 16))
	box.add_child(UIStyle.label(tr("ARCADE_FINAL_SCORE").format({"score": _score}), 40, UIStyle.TEXT))
	if is_record:
		box.add_child(UIStyle.label(tr("ARCADE_NEW_RECORD"), 40, UIStyle.GOLD, 10))
	var again := UIStyle.button(tr("ARCADE_PLAY_AGAIN"), func() -> void:
		_stage = 0
		_score = 0
		_run_counted = false
		_show_vs())
	box.add_child(again)
	box.add_child(UIStyle.button(tr("ARCADE_MENU"), func() -> void: get_tree().change_scene_to_file(TITLE_SCENE), false))
	_animate(box, again)


# --- Ayudas ---

## Consejo según el estilo del rival: enseña a jugar sin tutorial.
func _style_tip(profile: AIProfile) -> String:
	match profile.style_name_key:
		"AI_STYLE_PRESSURE":
			return tr("TIP_PRESSURE")
		"AI_STYLE_OUTBOXER":
			return tr("TIP_OUTBOXER")
		"AI_STYLE_COUNTER":
			return tr("TIP_COUNTER")
	return ""


## Pantalla vacía con fondo y una columna centrada.
func _screen() -> VBoxContainer:
	_bg = ColorRect.new()
	_bg.color = Color(UIStyle.BG, 0.94)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	return box


func _animate(box: VBoxContainer, focus: Control) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var i: int = 0
	for c in box.get_children():
		if c is Control:
			UIStyle.pop_in(c, i * 0.07)
			i += 1
	focus.grab_focus()


func _clear() -> void:
	for c in _ui.get_children():
		c.queue_free()
	if _combat != null:
		_combat.queue_free()
		_combat = null
