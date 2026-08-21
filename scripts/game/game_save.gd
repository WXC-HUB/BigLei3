class_name GameSave
extends RefCounted
## Minimal single-slot JSON save. The board itself is intentionally excluded;
## `current_level` always points to the level that should restart from its beginning.

const VERSION := 1
static var save_path := "user://bird_minesweeper_save.json"


static func exists() -> bool:
	return FileAccess.file_exists(save_path)


static func load_data() -> Dictionary:
	if not exists():
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file: %s" % FileAccess.get_open_error())
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Save file is not valid JSON data")
		return {}
	var payload := parsed as Dictionary
	if int(payload.get("version", 0)) != VERSION or not payload.get("data", {}) is Dictionary:
		push_warning("Save file version is unsupported")
		return {}
	return (payload["data"] as Dictionary).duplicate(true)


static func write(data: Dictionary) -> bool:
	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not create save file: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify({"version": VERSION, "data": data}, "\t"))
	file.flush()
	file.close()
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_save)
	var error := DirAccess.rename_absolute(absolute_temporary, absolute_save)
	if error != OK:
		push_warning("Could not finalize save file: %s" % error_string(error))
		return false
	return true


static func clear() -> bool:
	var ok := true
	for path in [save_path, save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and ok
	return ok
