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
const STAMINA_BAR_HEIGHT: float = 16.0
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
## Animación de carteles: tiempo desde que cambió la fase (los carteles entran con un golpe de escala).
var _last_phase: int = -1
var _last_count: int = 0
var _banner_time: float = 0.0
var _count_time: float = 0.0
## Temblor de las barras al recibir daño.
var _last_health := Vector2i(-1, -1)
var _shake := Vector2.ZERO
var _time: float = 0.0


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
	_time += delta
	_banner_time += delta
	_count_time += delta
	if _fight != null:
		if _fight.phase != _last_phase:
			_last_phase = _fight.phase
			_banner_time = 0.0
		if _fight.count != _last_count:
			_last_count = _fight.count
			_count_time = 0.0
	# Temblor proporcional al daño recibido.
	if _last_health.x >= 0:
		_shake.x = maxf(_shake.x, float(_last_health.x - _a.health) * 1.5)
		_shake.y = maxf(_shake.y, float(_last_health.y - _b.health) * 1.5)
	_last_health = Vector2i(_a.health, _b.health)
	_shake = _shake.move_toward(Vector2.ZERO, 60.0 * delta)
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
	_draw_fighter_bars(Vector2(MARGIN.x, MARGIN.y) + _jitter(_shake.x), _a, _trail_a, false)
	_draw_fighter_bars(Vector2(width - MARGIN.x - BAR_SIZE.x, MARGIN.y) + _jitter(_shake.y), _b, _trail_b, true)
	_draw_cut_vignette(width)
	_draw_round_clock()
	_draw_fight_messages(width)


## Con un corte grave, el jugador "ve rojo" en el borde de la pantalla (sangre en el ojo).
func _draw_cut_vignette(width: float) -> void:
	var sev: float = _a.worst_cut_severity()
	if sev < 0.5:
		return
	var a: float = clampf((sev - 0.5) * 0.5, 0.0, 0.35)
	var h: float = _canvas.size.y
	var edge := Color(0.6, 0.0, 0.0, a)
	var clear := Color(0.6, 0.0, 0.0, 0.0)
	var w: float = width * 0.18
	_canvas.draw_polygon(PackedVector2Array([Vector2(width - w, 0), Vector2(width, 0), Vector2(width, h), Vector2(width - w, h)]),
			PackedColorArray([clear, edge, edge, clear]))


## Arriba al centro: número de round y reloj.
func _draw_round_clock() -> void:
	if _fight == null:
		return
	var round_text: String = tr("COMBAT_ROUND_SHORT").format({"n": _fight.round_number, "total": _fight.total_rounds})
	_draw_centered(round_text, 34.0, 20, Color(0.85, 0.85, 0.85))
	var secs: int = _fight.seconds_left()
	var hurry: bool = secs <= 10 and _fight.is_fighting()
	var clock_color: Color = Color(1.0, 0.35, 0.3) if hurry else Color.WHITE
	# Últimos 10 segundos: el reloj late.
	var beat: float = 1.0 + (0.18 * maxf(0.0, sin(_time * TAU)) if hurry else 0.0)
	_draw_centered("%d:%02d" % [secs / 60, secs % 60], 70.0, 34, clock_color, beat)


func _draw_fight_messages(width: float) -> void:
	if _fight == null:
		return
	match _fight.phase:
		FightManager.Phase.ROUND_INTRO:
			_draw_centered(tr("COMBAT_ROUND").format({"n": _fight.round_number}), 270.0, 84, Color.WHITE, _pop(_banner_time))
			if _banner_time > 0.6:
				_draw_centered(tr("COMBAT_FIGHT"), 350.0, 60, UIStyle.GOLD, _pop(_banner_time - 0.6))
		FightManager.Phase.ROUND_BREAK:
			_draw_centered(tr("COMBAT_ROUND_END").format({"n": _fight.round_number}), 270.0, 64, Color.WHITE, _pop(_banner_time))
			_draw_centered(tr("COMBAT_REST"), 320.0, 26, Color(0.8, 0.8, 0.8))
		FightManager.Phase.COUNT:
			_draw_centered(tr("COMBAT_KNOCKDOWN"), 230.0, 56, UIStyle.GOLD, _pop(_banner_time))
			if _fight.count > 0:
				_draw_centered(str(_fight.count), 340.0, 120, Color.WHITE, _pop(_count_time, 0.8))
			var f: Fighter = _fight.downed
			if f != null:
				var bar_size := Vector2(360.0, 22.0)
				var pos := Vector2((width - bar_size.x) * 0.5, 370.0)
				_canvas.draw_rect(Rect2(pos - Vector2(3, 3), bar_size + Vector2(6, 6)), Color(0, 0, 0, 0.75))
				_canvas.draw_rect(Rect2(pos, Vector2(bar_size.x * f.getup_progress, bar_size.y)), Color(0.4, 0.9, 1.0))
				_draw_centered(tr("COMBAT_GET_UP_HINT"), 430.0, 22, Color.WHITE)
		FightManager.Phase.RESUME:
			_draw_centered(tr("COMBAT_FIGHT"), 300.0, 80, UIStyle.GOLD, _pop(_banner_time))
		FightManager.Phase.ENDED:
			match _fight.method:
				FightManager.Method.DOCTOR:
					_draw_centered(tr("COMBAT_DOCTOR"), 300.0, 84, UIStyle.RED, _pop(_banner_time, 1.2))
				FightManager.Method.KO, FightManager.Method.TKO:
					var title: String = tr("COMBAT_KO") if _fight.method == FightManager.Method.KO else tr("COMBAT_TKO")
					_draw_centered(title, 300.0, 130, UIStyle.RED, _pop(_banner_time, 1.2))
				FightManager.Method.DECISION:
					# El resultado (jueces) lo muestra ResultScreen un momento después.
					_draw_centered(tr("COMBAT_FIGHT_OVER"), 290.0, 72, Color.WHITE, _pop(_banner_time))


## Texto centrado con la fuente del juego. scale > 1 lo agranda desde el centro (para los carteles que "golpean").
func _draw_centered(text: String, y: float, font_size: int, color: Color, scale: float = 1.0) -> void:
	var font: Font = UIStyle.font()
	var width: float = _canvas.size.x
	var center := Vector2(width * 0.5, y - font_size * 0.35)
	_canvas.draw_set_transform(center * (1.0 - scale), 0.0, Vector2.ONE * scale)
	var pos := Vector2(0.0, y)
	_canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 14, Color.BLACK)
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
	_canvas.draw_set_transform(Vector2.ZERO)


## Escala de entrada de un cartel: arranca grande y "cae" a su tamaño con rebote.
func _pop(t: float, strength: float = 1.0) -> float:
	if t >= 0.3:
		return 1.0
	var k: float = t / 0.3
	return 1.0 + strength * (1.0 - k) * (1.0 - k) * 1.2


func _jitter(amount: float) -> Vector2:
	if amount <= 0.1:
		return Vector2.ZERO
	return Vector2(sin(_time * 83.0), cos(_time * 71.0)) * amount


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
	# Medidor de estrella: tramo dorado fino debajo de la stamina; lleno, late.
	var star_pos := Vector2(st_pos.x, st_pos.y + STAMINA_BAR_HEIGHT + 4.0)
	var star_size := Vector2(st_size.x * 0.55, 8.0)
	if mirrored:
		star_pos.x = st_pos.x + st_size.x - star_size.x
	_canvas.draw_rect(Rect2(star_pos - Vector2(2, 2), star_size + Vector2(4, 4)), Color(0, 0, 0, 0.7))
	var star_color: Color = UIStyle.GOLD
	if f.star_ready():
		star_color = UIStyle.GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 10.0))
	_canvas.draw_rect(_fill_rect(star_pos, star_size, f.star_meter, mirrored), star_color)
	var star_icon_x: float = star_pos.x + star_size.x + 6.0 if not mirrored else star_pos.x - 22.0
	var star_font: Font = UIStyle.font()
	_canvas.draw_string_outline(star_font, Vector2(star_icon_x, star_pos.y + 12.0), "★",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color.BLACK)
	_canvas.draw_string(star_font, Vector2(star_icon_x, star_pos.y + 12.0), "★",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, star_color if f.star_meter > 0.0 else Color(0.4, 0.4, 0.45))
	if f.is_tired() and fmod(_time, 0.6) < 0.4:
		var tired_font: Font = UIStyle.font()
		var tired_align := HORIZONTAL_ALIGNMENT_LEFT if mirrored else HORIZONTAL_ALIGNMENT_RIGHT
		_canvas.draw_string_outline(tired_font, st_pos + Vector2(0, STAMINA_BAR_HEIGHT + 40.0), tr("HUD_TIRED"),
				tired_align, st_size.x, 22, 6, Color.BLACK)
		_canvas.draw_string(tired_font, st_pos + Vector2(0, STAMINA_BAR_HEIGHT + 40.0), tr("HUD_TIRED"),
				tired_align, st_size.x, 22, COLOR_STAMINA_TIRED)
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
	if f.has_cuts():
		# Aviso de corte bajo la barra (rojo más intenso cuanto más grave).
		var cut_font: Font = UIStyle.font()
		var sev: float = clampf(f.worst_cut_severity(), 0.0, 1.0)
		var cut_align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
		var cut_pos := Vector2(pos.x, st_pos.y + STAMINA_BAR_HEIGHT + 66.0)
		var cut_text: String = tr("HUD_CUT").format({"pct": roundi(sev * 100.0)})
		_canvas.draw_string_outline(cut_font, cut_pos, cut_text, cut_align, BAR_SIZE.x, 20, 6, Color.BLACK)
		_canvas.draw_string(cut_font, cut_pos, cut_text, cut_align, BAR_SIZE.x, 20, Color(1.0, 0.6 - sev * 0.5, 0.5 - sev * 0.5))
	var font: Font = UIStyle.font()
	var name_pos := Vector2(pos.x, st_pos.y + STAMINA_BAR_HEIGHT + 40.0)
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	_canvas.draw_string_outline(font, name_pos, f.setup.display_name, align, BAR_SIZE.x, 24, 7, Color.BLACK)
	_canvas.draw_string(font, name_pos, f.setup.display_name, align, BAR_SIZE.x, 24, Color.WHITE)


func _fill_rect(pos: Vector2, size: Vector2, ratio: float, mirrored: bool) -> Rect2:
	var fill_width: float = size.x * clampf(ratio, 0.0, 1.0)
	var x: float = pos.x + (size.x - fill_width if mirrored else 0.0)
	return Rect2(Vector2(x, pos.y), Vector2(fill_width, size.y))
