class_name EventBox
extends ColorRect
## Ventana de un evento de la historia, encima de la pantalla que lo llama (hub o Arena):
## retrato provisorio, título, texto y opciones. Al elegir, muestra qué pasó y qué cambió
## (plata, moral, relaciones…) y un botón SEGUIR.
##
## Recibe el GameState como parámetro (no usa autoloads, así las pruebas la pueden armar).
## Aplica la opción con EventRunner.choose(). NO guarda en disco ni cambia de pantalla:
## avisa con `finished` y la pantalla que la abrió decide qué sigue.

## Terminó el evento. `next_id` es el evento que sigue ya mismo ("" = ninguno).
signal finished(next_id: String)

const TEXT_WIDTH: float = 720.0
const PORTRAIT: Vector2 = Vector2(150, 150)
const UP := Color(0.45, 0.85, 0.5)
const DOWN := Color(0.95, 0.55, 0.3)

## Botones de las opciones y de SEGUIR (las pruebas los aprietan).
var option_buttons: Array[Button] = []
var continue_button: Button

var _gs: Object
var _event: Dictionary
var _content: VBoxContainer
var _next: String = ""


func _init(gs: Object, ev: Dictionary) -> void:
	_gs = gs
	_event = ev


func _ready() -> void:
	color = Color(0, 0, 0, 0.75)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UIStyle.panel()
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	panel.add_child(row)
	var who: CharacterData = EventRunner.character(StringName(_event.get("character", "")))
	if who != null:
		row.add_child(portrait(who, PORTRAIT, true))
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	row.add_child(_content)
	var title := UIStyle.label(tr(EventRunner.key(_event, "TITLE")), 38, UIStyle.GOLD, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(title)
	_content.add_child(_paragraph(_fill(tr(EventRunner.key(_event, "TEXT"))), UIStyle.TEXT))
	_show_options()
	UIStyle.pop_in.call_deferred(panel)


## Retrato provisorio: un cuadrado del color del personaje con su inicial (y el nombre abajo).
static func portrait(who: CharacterData, size: Vector2, with_name: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var face := ColorRect.new()
	face.color = who.color.darkened(0.25)
	face.custom_minimum_size = size
	var initial := UIStyle.label(TranslationServer.translate(who.name_key).trim_prefix("El ").trim_prefix("Don ").left(1), int(size.y * 0.55), who.color.lightened(0.6), 8)
	initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_child(initial)
	box.add_child(face)
	if with_name:
		var n := UIStyle.label(TranslationServer.translate(who.name_key), 22, who.color.lightened(0.3), 5)
		n.custom_minimum_size = Vector2(size.x, 0)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(n)
	return box


## "+3 moral, -8 energía por semana · 97 % de stamina en la pelea"
static func status_effects_text(s: StatusData) -> String:
	var parts: PackedStringArray = []
	if s.weekly_morale != 0:
		parts.append(TranslationServer.translate("EFFECT_MORALE").format({"n": signed_text(s.weekly_morale)}))
	if s.weekly_energy != 0:
		parts.append(TranslationServer.translate("EFFECT_ENERGY").format({"n": signed_text(s.weekly_energy)}))
	if s.weekly_money != 0:
		parts.append(_money(s.weekly_money))
	var text: String = ""
	if not parts.is_empty():
		text = TranslationServer.translate("EFFECT_PER_WEEK").format({"n": ", ".join(parts)})
	var mults: PackedStringArray = []
	if not is_equal_approx(s.training_mult, 1.0):
		mults.append(TranslationServer.translate("STATUS_TRAINING").format({"n": roundi(s.training_mult * 100)}))
	if not is_equal_approx(s.fight_stamina_mult, 1.0):
		mults.append(TranslationServer.translate("STATUS_STAMINA").format({"n": roundi(s.fight_stamina_mult * 100)}))
	if not mults.is_empty():
		text += ("  ·  " if text != "" else "") + "  ·  ".join(mults)
	return text


## Líneas del resumen de la semana para las situaciones activas y las que terminaron: [texto, color].
static func week_status_lines(week: Dictionary) -> Array:
	var out: Array = []
	for line in week.get("status_lines", []):
		var s: StatusData = EventRunner.status(StringName(line["id"]))
		if s != null:
			out.append([TranslationServer.translate("WEEK_STATUS_LINE").format({"name": TranslationServer.translate(s.name_key),
					"effects": status_effects_text(s)}), UP if s.good else DOWN])
	for id in week.get("expired", []):
		var s: StatusData = EventRunner.status(StringName(id))
		if s != null:
			out.append([TranslationServer.translate("WEEK_STATUS_EXPIRED").format({"name": TranslationServer.translate(s.name_key)}), UIStyle.MUTED])
	return out


static func signed_text(n: int) -> String:
	return ("+%d" % n) if n > 0 else str(n)


static func _money(n: int) -> String:
	return ("+$%d" % n) if n >= 0 else ("-$%d" % -n)


func _show_options() -> void:
	var options: Array = _event["options"]
	for i in options.size():
		var o: Dictionary = options[i]
		var ok: bool = EventRunner.option_available(_gs, o)
		var text: String = tr(EventRunner.option_key(_event, i))
		if not ok:
			var needs_money: bool = o.get("requires", {}).has("min_money") and _gs.money < int(o["requires"]["min_money"])
			text += "  " + tr("EVENT_NEED_MONEY" if needs_money else "EVENT_LOCKED")
		var b := UIStyle.button(text, _choose.bind(i), false)
		b.custom_minimum_size = Vector2(TEXT_WIDTH, 64)
		b.add_theme_font_size_override("font_size", 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not ok
		if not ok:
			b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
			b.add_theme_stylebox_override("disabled", UIStyle.choice_box(false))
		_content.add_child(b)
		option_buttons.append(b)
	for b in option_buttons:
		if not b.disabled:
			b.grab_focus.call_deferred()
			break


func _choose(index: int) -> void:
	if continue_button != null:
		return
	var summary: Dictionary = EventRunner.choose(_gs, _event, index)
	_next = summary["next"]
	for b in option_buttons:
		b.queue_free()
	option_buttons.clear()
	_content.add_child(_paragraph(tr(EventRunner.option_key(_event, index)), UIStyle.MUTED))
	_content.add_child(_paragraph(_fill(tr(EventRunner.result_key(_event, index))), Color(1.0, 0.92, 0.75)))
	var chips := HFlowContainer.new()
	chips.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	chips.add_theme_constant_override("h_separation", 22)
	for c in _chips(summary):
		chips.add_child(UIStyle.label(c[0], 24, c[1], 5))
	_content.add_child(chips)
	continue_button = UIStyle.button(tr("EVENT_CONTINUE"), _finish)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_content.add_child(continue_button)
	continue_button.grab_focus.call_deferred()


func _finish() -> void:
	finished.emit(_next)


## Lo que cambió, como [texto, color].
func _chips(s: Dictionary) -> Array:
	var out: Array = []
	if s["money"] != 0:
		out.append([_money(s["money"]), UP if s["money"] > 0 else DOWN])
	if s["energy"] != 0:
		out.append([tr("EFFECT_ENERGY").format({"n": signed_text(s["energy"])}), UP if s["energy"] > 0 else DOWN])
	if s["morale"] != 0:
		out.append([tr("EFFECT_MORALE").format({"n": signed_text(s["morale"])}), UP if s["morale"] > 0 else DOWN])
	for stat in s["stats"]:
		out.append(["%s %s" % [signed_text(s["stats"][stat]), tr("STAT_" + String(stat).to_upper())], UP if s["stats"][stat] > 0 else DOWN])
	for who in s["relations"]:
		var n: int = s["relations"][who]
		var c: CharacterData = EventRunner.character(StringName(who))
		if n != 0 and c != null:
			out.append(["%s %s" % [tr(c.name_key), signed_text(n)], UP if n > 0 else DOWN])
	for id in s["added"]:
		var st: StatusData = EventRunner.status(StringName(id))
		out.append([tr("EVENT_STATUS_ADDED").format({"name": tr(st.name_key)}), UIStyle.GOLD])
	for id in s["removed"]:
		var st: StatusData = EventRunner.status(StringName(id))
		out.append([tr("EVENT_STATUS_REMOVED").format({"name": tr(st.name_key)}), DOWN])
	return out


func _paragraph(text: String, c: Color) -> Label:
	var l := UIStyle.label(text, 26, c, 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Reemplaza {name} y {nick} por los del jugador.
func _fill(text: String) -> String:
	return text.format({"name": _gs.fighter.full_name, "nick": _gs.fighter.nickname})
