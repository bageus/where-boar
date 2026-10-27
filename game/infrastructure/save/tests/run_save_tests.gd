extends SceneTree

const SaveStore = preload("res://game/infrastructure/save/public/save_store.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_round_trip_keeps_backup(), "save round trip keeps the previous file as backup")
	failures += _check(_corrupt_file_uses_backup(), "a corrupt save falls back to the backup")
	failures += _check(_newer_version_is_refused(), "a newer save is refused and not overwritten")
	failures += _check(_missing_save_is_empty(), "no save loads as empty")
	print("save tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _store() -> SaveStore:
	var store := SaveStore.new()
	store.path = "user://test_save.json"
	for file_path in [store.path, store.backup_path()]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	return store


func _round_trip_keeps_backup() -> bool:
	var store := _store()
	store.save_data({"tusks": 1})
	store.save_data({"tusks": 2})
	var backup := FileAccess.get_file_as_string(store.backup_path())
	# JSON numbers load as floats.
	return store.load_data() == {"tusks": 2.0} and "\"tusks\":1" in backup


func _corrupt_file_uses_backup() -> bool:
	var store := _store()
	store.save_data({"tusks": 1})
	store.save_data({"tusks": 2})
	FileAccess.open(store.path, FileAccess.WRITE).store_string("{broken")
	return store.load_data() == {"tusks": 1.0}


func _newer_version_is_refused() -> bool:
	var store := _store()
	var newer := JSON.stringify({"save_version": SaveStore.SAVE_VERSION + 1, "data": {"tusks": 9}})
	FileAccess.open(store.path, FileAccess.WRITE).store_string(newer)
	var loaded := store.load_data()
	var refused := not store.save_data({"tusks": 0})
	return loaded.is_empty() and store.blocked and refused \
		and FileAccess.get_file_as_string(store.path) == newer


func _missing_save_is_empty() -> bool:
	return _store().load_data().is_empty()
