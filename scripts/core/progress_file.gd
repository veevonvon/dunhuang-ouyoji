extends RefCounted

var path: String
var blocked: bool = false
var recovered: bool = false
var _decode: Callable


func _init(target_path: String, decode: Callable) -> void:
	path = target_path
	_decode = decode


func read() -> Dictionary:
	var primary_exists: bool = FileAccess.file_exists(path)
	var backup_exists: bool = FileAccess.file_exists(path + ".bak")
	if not primary_exists and not backup_exists:
		return {"ok": true, "missing": true}
	var primary: Dictionary = _read_valid(path)
	if primary.get("ok", false):
		return primary
	var backup: Dictionary = _read_valid(path + ".bak")
	if backup.get("ok", false):
		recovered = true
		return backup
	blocked = true
	return _error("设备里的行囊和备份暂时无法读取，已保留原文件。本次旅行仍可导出，请先妥善保存。")


func write(text: String) -> Dictionary:
	if blocked:
		return _error("原行囊暂时无法读取，已停止写入以保护原文件。请先导出本次旅行。")
	var primary_exists: bool = FileAccess.file_exists(path)
	var primary: Dictionary = _read_valid(path) if primary_exists else {}
	if primary_exists and not primary.get("ok", false) and not recovered:
		blocked = true
		return _error("设备里的行囊已发生变化且无法读取，已保留原文件。请先导出本次旅行。")
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _error("暂时无法写入行囊，请检查设备剩余空间；之前保存的旅行仍在。")
	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_string(temporary) != text:
		DirAccess.remove_absolute(temporary)
		return _error("行囊没有完整写入，之前保存的旅行仍在。请先导出本次旅行。")
	if not _read_valid(temporary).get("ok", false):
		DirAccess.remove_absolute(temporary)
		return _error("新行囊未通过完整性检查，之前保存的旅行仍在。")
	# A recovered corrupt primary must never be copied over its good backup.
	if primary.get("ok", false):
		var backup_temporary: String = path + ".bak.tmp"
		if DirAccess.dir_exists_absolute(backup_temporary) or DirAccess.dir_exists_absolute(path + ".bak"):
			DirAccess.remove_absolute(temporary)
			return _error("行囊备份暂时无法写入，已保留之前的旅行。")
		var copy_error: Error = DirAccess.copy_absolute(path, backup_temporary)
		if copy_error != OK or FileAccess.get_file_as_string(backup_temporary) != primary.get("text", ""):
			DirAccess.remove_absolute(temporary)
			DirAccess.remove_absolute(backup_temporary)
			return _error("行囊备份未能完整保存，已保留之前的旅行。")
		if DirAccess.rename_absolute(backup_temporary, path + ".bak") != OK:
			DirAccess.remove_absolute(temporary)
			DirAccess.remove_absolute(backup_temporary)
			return _error("行囊备份无法更新，已保留之前的旅行。")
	# The temp file is a sibling, so replacement stays on the same filesystem.
	if DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return _error("新行囊暂时无法替换，之前的行囊与备份仍在。")
	recovered = false
	return {"ok": true}


func _read_valid(file_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	if file.get_length() > 100000:
		file.close()
		return {"ok": false}
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return {"ok": false}
	var result: Dictionary = _decode.call(text)
	result["text"] = text
	return result


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
