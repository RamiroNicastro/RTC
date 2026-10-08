class_name PlayerFighter
extends RefCounted
## El peleador del jugador: nombre, apodo y estilo elegido. Se guarda en JSON en user://.
##
## Es provisorio hasta que exista GameState (Fase 2): ahí pasa a ser parte de la partida.
## NO calcula números del combate: arma una FighterData y eso lo convierte StatFormulas.

## Ruta del archivo (las pruebas la cambian para no pisar el peleador real).
static var path: String = "user://player_fighter.json"
const SAVE_VERSION: int = 1
const MAX_NAME_LENGTH: int = 16
## Color del jugador en el ring (el rival usa el de su ficha).
const COLOR := Color(0.2, 0.55, 0.9)

## Estilos para elegir, en el orden en que se muestran.
const STYLES: Array[FighterStyle] = [
	preload("res://data/fighter_styles/balanced.tres"),
	preload("res://data/fighter_styles/puncher.tres"),
	preload("res://data/fighter_styles/stylist.tres"),
	preload("res://data/fighter_styles/brawler.tres"),
	preload("res://data/fighter_styles/counterpuncher.tres"),
]

var full_name: String = ""
var nickname: String = ""
var style_id: StringName = &"balanced"


## true si el jugador ya creó su peleador (si no, hay que mostrarle la pantalla de creación).
static func exists() -> bool:
	return FileAccess.file_exists(path)


static func load_fighter() -> PlayerFighter:
	var p := PlayerFighter.new()
	if not exists():
		return p
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		p.full_name = clean_name(str(data.get("full_name", "")))
		p.nickname = clean_name(str(data.get("nickname", "")))
		p.style_id = StringName(str(data.get("style_id", "balanced")))
		if find_style(p.style_id) == null:
			p.style_id = &"balanced"
	return p


func save() -> void:
	var data := {
		"save_version": SAVE_VERSION,
		"full_name": full_name,
		"nickname": nickname,
		"style_id": String(style_id),
	}
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("No se pudo guardar el peleador.")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


## Saca espacios de más y corta los nombres muy largos (para que entren en las barras del HUD).
static func clean_name(text: String) -> String:
	var t: String = " ".join(text.strip_edges().split(" ", false))
	return t.substr(0, MAX_NAME_LENGTH)


static func find_style(id: StringName) -> FighterStyle:
	for s in STYLES:
		if s.id == id:
			return s
	return null


func style() -> FighterStyle:
	var s: FighterStyle = find_style(style_id)
	return s if s != null else STYLES[0]


## Nombre para mostrar en la pelea: "Apodo" Nombre, o lo que haya.
## `fallback` se usa si el jugador no escribió nada (lo pasa la UI ya traducido).
func display_name(fallback: String) -> String:
	if full_name.is_empty() and nickname.is_empty():
		return fallback
	if nickname.is_empty():
		return full_name
	if full_name.is_empty():
		return "\"%s\"" % nickname
	return "\"%s\" %s" % [nickname, full_name]


## La ficha del jugador (lo que StatFormulas convierte en un FighterSetup).
func to_fighter_data() -> FighterData:
	var d := FighterData.new()
	d.full_name = full_name
	d.nickname = nickname
	d.color = COLOR
	style().apply_to(d)
	return d
