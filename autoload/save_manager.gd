extends Node
## Autoload: guarda y carga la carrera (GameState) en JSON dentro de user://.
##
## Un slot por ahora (sección 14 del plan), pero la API ya recibe el número de slot.
## Escritura segura: archivo temporal → se renombra, y se conserva una copia .bak.
## NO decide cuándo guardar, salvo el autoguardado al cerrar o pausar la app en el celular.

## 2: se suma la historia (moral, flags, relaciones, situaciones y eventos).
const SAVE_VERSION: int = 2
const DEFAULT_SLOT: int = 1

## Carpeta de las partidas (las pruebas la cambian para no pisar las reales).
var folder: String = "user://"


func slot_path(slot: int = DEFAULT_SLOT) -> String:
	return folder.path_join("slot_%d.json" % slot)


func has_save(slot: int = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Guarda la carrera en curso. Devuelve false si no hay carrera o no se pudo escribir.
func save(slot: int = DEFAULT_SLOT) -> bool:
	if not GameState.active:
		return false
	var data: Dictionary = GameState.to_dict()
	data["save_version"] = SAVE_VERSION
	var path: String = slot_path(slot)
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("No se pudo guardar la carrera.")
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	return true


## Carga la carrera en GameState. Si el archivo está roto, prueba con la copia .bak.
func load_slot(slot: int = DEFAULT_SLOT) -> bool:
	var path: String = slot_path(slot)
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(p)) == OK and json.data is Dictionary:
			GameState.from_dict(_migrate(json.data))
			return true
	return false


func delete_slot(slot: int = DEFAULT_SLOT) -> void:
	var path: String = slot_path(slot)
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Pasa un guardado viejo al formato actual. Cada versión nueva suma su paso acá.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("save_version", 1))
	if version > SAVE_VERSION:
		push_warning("Guardado de una versión más nueva del juego (%d)." % version)
	if version < 2:
		# Carrera empezada antes de los eventos: arranca la historia de cero (moral inicial,
		# sin flags ni relaciones). GameState.from_dict completa el resto con sus valores por defecto.
		data["morale"] = GameState.START_MORALE
	return data


## Autoguardado al pausar la app (Android) o cerrar la ventana. Nunca a mitad de pelea:
## la carrera solo cambia GameState fuera del combate.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.active:
			save()
