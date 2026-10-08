class_name StatBars
extends GridContainer
## Las 6 estadísticas como barras de 1 a 100 (en 2 columnas), con una marca en el 50.
## Verde por encima de 50, rojo por debajo. Sirve para cualquier objeto con esas propiedades
## (FighterData, FighterStyle). NO calcula nada: solo muestra.

## [propiedad, clave de texto], en el orden en que se muestran.
const STATS: Array = [
	[&"power", "STAT_POWER"], [&"speed", "STAT_SPEED"], [&"cardio", "STAT_CARDIO"],
	[&"chin", "STAT_CHIN"], [&"technique", "STAT_TECHNIQUE"], [&"defense", "STAT_DEFENSE"],
]
const UP_COLOR := Color(0.35, 0.8, 0.45)
const DOWN_COLOR := Color(0.9, 0.4, 0.3)

var bar_size := Vector2(220, 18)
## Números de cada estadística (en el orden de STATS). Las pruebas los leen.
var numbers: Array[Label] = []
var _fills: Array[ColorRect] = []


func _init(width: float = 220.0, column_count: int = 2) -> void:
	bar_size.x = width
	columns = column_count
	add_theme_constant_override("h_separation", 48)
	add_theme_constant_override("v_separation", 6)
	for st in STATS:
		add_child(_row(tr(st[1])))


## Muestra los valores de `source` (cualquier objeto con power, speed, cardio, chin, technique y defense).
func show_stats(source: Object, animate: bool = true) -> void:
	for i in STATS.size():
		var value: int = int(source.get(STATS[i][0]))
		var fill: ColorRect = _fills[i]
		var target: float = bar_size.x * value / 100.0
		fill.color = UP_COLOR if value > 50 else (DOWN_COLOR if value < 50 else UIStyle.MUTED)
		if animate:
			fill.create_tween().tween_property(fill, "size:x", target, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			fill.size.x = target
		numbers[i].text = str(value)
		numbers[i].add_theme_color_override("font_color", fill.color.lightened(0.3))


func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := UIStyle.label(text, 22, UIStyle.TEXT, 5)
	name_label.custom_minimum_size = Vector2(150, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.12)
	bar_bg.custom_minimum_size = bar_size
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.size = Vector2(0, bar_size.y)
	bar_bg.add_child(fill)
	# Marca del 50 (el valor "normal").
	var mid := ColorRect.new()
	mid.color = Color(1, 1, 1, 0.5)
	mid.position = Vector2(bar_size.x * 0.5 - 1, -3)
	mid.size = Vector2(2, bar_size.y + 6)
	bar_bg.add_child(mid)
	row.add_child(bar_bg)
	var number := UIStyle.label("", 22, UIStyle.TEXT, 5)
	number.custom_minimum_size = Vector2(44, 0)
	row.add_child(number)
	_fills.append(fill)
	numbers.append(number)
	return row
