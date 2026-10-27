extends RefCounted

## One save slot as JSON with save_version (section 18). Each write keeps the previous file
## as a backup; a broken file falls back to the backup; a newer version is refused and never overwritten.

const SAVE_VERSION := 1

var path := "user://save.json"
## Set when the file on disk is from a newer game: writes are refused so it is not lost.
var blocked := false


func backup_path() -> String:
	return path + ".bak"


## Saved payload, or {} when there is no usable save.
func load_data() -> Dictionary:
	blocked = false
	for candidate in [path, backup_path()]:
		var doc = _read(candidate)
		if doc == null:
			continue
		if int(doc.get("save_version", 0)) > SAVE_VERSION:
			push_error("Save %s is from a newer version; not loading or overwriting it." % candidate)
			blocked = true
			return {}
		var data = doc.get("data", {})
		return data if data is Dictionary else {}
	return {}


func save_data(data: Dictionary) -> bool:
	if blocked:
		return false
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify({"save_version": SAVE_VERSION, "data": data}))
	file.close()
	if FileAccess.file_exists(path):
		# Windows cannot rename over an existing file.
		if FileAccess.file_exists(backup_path()):
			DirAccess.remove_absolute(backup_path())
		DirAccess.rename_absolute(path, backup_path())
	return DirAccess.rename_absolute(tmp, path) == OK


## Parsed document, or null when missing or not a JSON object.
func _read(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var doc = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if doc is Dictionary:
		return doc
	push_warning("Save %s is unreadable, trying the backup." % file_path)
	return null
