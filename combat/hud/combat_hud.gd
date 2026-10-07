class_name CombatHUD
extends CanvasLayer
## HUD del combate (placeholder): barras de salud y de stamina de los dos peleadores.
##
## Solo LEE el estado de los Fighters; nunca lo modifica.
## La parte clara de la barra de salud muestra el daño reciente y baja con retraso (es solo visual).
## La barra de stamina se pone naranja cuando el peleador está cansado.
## Al final de la barra: tramo gris = FATIGA, tramo violeta = desgaste por golpes al CUERPO.
## Las dos bajan el máximo y no se recuperan hasta el descanso entre rounds.
## Al centro: carteles de la pelea (knockdown + cuenta + barra para levantarse, "¡BOXEEN!", KO).
## Los textos salen de i18n/textos.csv con tr().
## En el Hito I se ancla a la safe area.

const BAR_SIZE := Vector2(460.0, 26.0)
const STAMINA_BAR_HEIGHT: float = 10.0
const MARGIN := Vector2(28.0, 24.0)
## Velocidad (fracción de barra por segundo) con la que baja la marca del daño reciente.
const TRAIL_SPEED: float = 0.6

const COLOR_STAMINA := Color(0.3, 0.85, 0.4)
const COLOR_STAMINA_TIRED := Color(1.0, 0.55, 0.1)
const COLOR_FATIGUE := Color(0.45, 0.45, 0.48)
const COLOR_BODY_DRAIN := Color(0.6, 0.25, 0.75)
## Salud máxima perdida por daño profundo (no se recupera en la pelea).
const COLOR_DEEP_DAMAGE := Color(0.1, 0.1, 0.1)

var _a: Fighter
var _b: Fighter
var _fight: FightManager
var _trail_a: float = 1.0
var _trail_b: float = 1.0
var _canvas: Control


func setup(a: Fighter, b: Fighter, fight: FightManager) -> void:
	_a = a
	_b = b
	_fight = fight


func _ready() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_canvas_draw)
	add_child(_canvas)


# La animación de la barra es puramente visual: puede usar delta.
func _process(delta: float) -> void:
	if _a == null:
		return
	_trail_a = _approach_trail(_trail_a, _health_ratio(_a), delta)
	_trail_b = _approach_trail(_trail_b, _health_ratio(_b), delta)
	_canvas.queue_redraw()


func _approach_trail(trail: float, real: float, delta: float) -> float:
	if real >= trail:
		return real
	return maxf(real, trail - TRAIL_SPEED * delta)


func _health_ratio(f: Fighter) -> float:
	return float(f.health) / float(f.base_max_health)


func _on_canvas_draw() -> void:
	if _a == null:
		return
	var width: float = _canvas.size.x
	_draw_fighter_bars(Vector2(MARGIN.x, MARGIN.y), _a, _trail_a, false)
	_draw_fighter_bars(Vector2(width - MARGIN.x - BAR_SIZE.x, MARGIN.y), _b, _trail_b, true)
	_draw_round_clock()
	_draw_fight_messages(width)


## Arriba al centro: número de round y reloj.
func _draw_round_clock() -> void:
	if _fight == null:
		return
	var round_text: String = tr("COMBAT_ROUND_SHORT").format({"n": _fight.round_number, "total": _fight.total_rounds})
	_draw_centered(round_text, 34.0, 20, Color(0.85, 0.85, 0.85))
	var secs: int = _fight.seconds_left()
	var clock_color: Color = Color(1.0, 0.35, 0.3) if secs <= 10 and _fight.is_fighting() else Color.WHITE
	_draw_centered("%d:%02d" % [secs / 60, secs % 60], 70.0, 34, clock_color)


func _draw_fight_messages(width: float) -> void:
	if _fight == null:
		return
	match _fight.phase:
		FightManager.Phase.ROUND_INTRO:
			_draw_centered(tr("COMBAT_ROUND").format({"n": _fight.round_number}), 270.0, 72, Color.WHITE)
			_draw_centered(tr("COMBAT_FIGHT"), 340.0, 48, Color(1.0, 0.85, 0.3))
		FightManager.Phase.ROUND_BREAK:
			_draw_centered(tr("COMBAT_ROUND_END").format({"n": _fight.round_number}), 270.0, 56, Color.WHITE)
			_draw_centered(tr("COMBAT_REST"), 320.0, 26, Color(0.8, 0.8, 0.8))
		FightManager.Phase.COUNT:
			_draw_centered(tr("COMBAT_KNOCKDOWN"), 230.0, 44, Color(1.0, 0.85, 0.3))
			if _fight.count > 0:
				_draw_centered(str(_fight.count), 330.0, 96, Color.WHITE)
			var f: Fighter = _fight.downed
			if f != null:
				var bar_size := Vector2(360.0, 22.0)
				var pos := Vector2((width - bar_size.x) * 0.5, 370.0)
				_canvas.draw_rect(Rect2(pos - Vector2(3, 3), bar_size + Vector2(6, 6)), Color(0, 0, 0, 0.75))
				_canvas.draw_rect(Rect2(pos, Vector2(bar_size.x * f.getup_progress, bar_size.y)), Color(0.4, 0.9, 1.0))
				_draw_centered(tr("COMBAT_GET_UP_HINT"), 430.0, 22, Color.WHITE)
		FightManager.Phase.RESUME:
			_draw_centered(tr("COMBAT_FIGHT"), 300.0, 72, Color(1.0, 0.85, 0.3))
		FightManager.Phase.ENDED:
			match _fight.method:
				FightManager.Method.KO, FightManager.Method.TKO:
					var title: String = tr("COMBAT_KO") if _fight.method == FightManager.Method.KO else tr("COMBAT_TKO")
					_draw_centered(title, 290.0, 96, Color(1.0, 0.3, 0.2))
					_draw_centered(tr("COMBAT_WINNER").format({"name": _fight.winner.setup.display_name}), 360.0, 36, Color.WHITE)
				FightManager.Method.DECISION:
					_draw_centered(tr("COMBAT_FIGHT_OVER"), 290.0, 64, Color.WHITE)
					_draw_centered(tr("COMBAT_DECISION_PENDING"), 345.0, 26, Color(0.8, 0.8, 0.8))


func _draw_centered(text: String, y: float, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var pos := Vector2(0.0, y)
	var width: float = _canvas.size.x
	_canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 10, Color.BLACK)
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


## mirrored = true: las barras se vacían hacia la derecha (lado del rival).
func _draw_fighter_bars(pos: Vector2, f: Fighter, trail: float, mirrored: bool) -> void:
	# Salud.
	_canvas.draw_rect(Rect2(pos - Vector2(3, 3), BAR_SIZE + Vector2(6, 6)), Color(0, 0, 0, 0.7))
	_canvas.draw_rect(Rect2(pos, BAR_SIZE), Color(0.25, 0.05, 0.05))
	_canvas.draw_rect(_fill_rect(pos, BAR_SIZE, trail, mirrored), Color(1.0, 0.85, 0.6))
	_canvas.draw_rect(_fill_rect(pos, BAR_SIZE, _health_ratio(f), mirrored), Color(0.9, 0.2, 0.15))
	# Tramo oscuro al final: la salud máxima perdida por daño profundo.
	var lost: float = float(f.base_max_health - f.max_health) / float(f.base_max_health)
	if lost > 0.0:
		var lost_width: float = BAR_SIZE.x * lost
		var lx: float = pos.x if mirrored else pos.x + BAR_SIZE.x - lost_width
		_canvas.draw_rect(Rect2(Vector2(lx, pos.y), Vector2(lost_width, BAR_SIZE.y)), COLOR_DEEP_DAMAGE)
		_canvas.draw_rect(Rect2(Vector2(lx, pos.y), Vector2(lost_width, BAR_SIZE.y)), Color(0.5, 0.5, 0.5, 0.6), false, 1.0)

	# Stamina.
	var st_pos := Vector2(pos.x, pos.y + BAR_SIZE.y + 6.0)
	var st_size := Vector2(BAR_SIZE.x, STAMINA_BAR_HEIGHT)
	_canvas.draw_rect(Rect2(st_pos - Vector2(2, 2), st_size + Vector2(4, 4)), Color(0, 0, 0, 0.7))
	_canvas.draw_rect(Rect2(st_pos, st_size), Color(0.08, 0.15, 0.08))
	var st_color: Color = COLOR_STAMINA_TIRED if f.is_tired() else COLOR_STAMINA
	_canvas.draw_rect(_fill_rect(st_pos, st_size, f.stamina / f.base_max_stamina, mirrored), st_color)
	# Desde el final de la barra: primero el desgaste del cuerpo y después la fatiga.
	var from_end: float = 0.0
	for segment in [[f.body_drain, COLOR_BODY_DRAIN], [f.fatigue, COLOR_FATIGUE]]:
		var width: float = st_size.x * float(segment[0]) / f.base_max_stamina
		if width <= 0.0:
			continue
		var x: float = st_pos.x + from_end if mirrored else st_pos.x + st_size.x - from_end - width
		_canvas.draw_rect(Rect2(Vector2(x, st_pos.y), Vector2(width, st_size.y)), segment[1])
		from_end += width

	# Nombre.
	var font: Font = ThemeDB.fallback_font
	var name_pos := Vector2(pos.x, st_pos.y + STAMINA_BAR_HEIGHT + 22.0)
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	_canvas.draw_string_outline(font, name_pos, f.setup.display_name, align, BAR_SIZE.x, 18, 5, Color.BLACK)
	_canvas.draw_string(font, name_pos, f.setup.display_name, align, BAR_SIZE.x, 18, Color.WHITE)


func _fill_rect(pos: Vector2, size: Vector2, ratio: float, mirrored: bool) -> Rect2:
	var fill_width: float = size.x * clampf(ratio, 0.0, 1.0)
	var x: float = pos.x + (size.x - fill_width if mirrored else 0.0)
	return Rect2(Vector2(x, pos.y), Vector2(fill_width, size.y))
