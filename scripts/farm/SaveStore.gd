extends RefCounted
## Write and verify a temporary snapshot before replacing the current save.
## A verified previous snapshot is retained for recovery after interrupted writes.

static func read_snapshot(path: String, validator: Callable) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	if not json.data is Dictionary or not validator.call(json.data):
		return {}
	return json.data

static func write_snapshot(path: String, data: Dictionary, validator: Callable) -> bool:
	if not validator.call(data):
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or read_snapshot(temporary, validator).is_empty():
		return false
	# Never replace a good backup with a corrupt primary recovered earlier.
	if not read_snapshot(path, validator).is_empty():
		var backup_temp := path + ".bak.tmp"
		if DirAccess.copy_absolute(path, backup_temp) != OK:
			return false
		if DirAccess.rename_absolute(backup_temp, path + ".bak") != OK:
			return false
	return DirAccess.rename_absolute(temporary, path) == OK
