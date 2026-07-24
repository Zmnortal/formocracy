class_name FormocracySaveRepository
extends RefCounted

# 只负责存档文件的安全读写，不理解游戏状态或时间线语义。

const SaveSchema := preload("res://scripts/save/save_schema.gd")


# 判断是否存在可加载的主存档或备份。
func has_save(save_path: String) -> bool:
	if SaveSchema.is_loadable_document(read_document_at(save_path)):
		return true
	return SaveSchema.is_loadable_document(read_document_at(save_path + ".bak"))


# 读取主存档，损坏时尝试从备份恢复。
func read_with_backup(save_path: String) -> Dictionary:
	var document := read_document_at(save_path)
	if SaveSchema.is_loadable_document(document):
		return document
	document = read_document_at(save_path + ".bak")
	if not SaveSchema.is_loadable_document(document):
		return {}
	restore_primary_document(save_path, document)
	return document


# 从指定路径读取并解析 JSON 存档。
func read_document_at(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = parser.data
	if parsed is Dictionary:
		@warning_ignore("unsafe_cast")
		var document: Dictionary = parsed
		return document
	return {}


# 返回存档文件或备份的修改时间戳。
func get_modified_time(save_path: String) -> int:
	if FileAccess.file_exists(save_path):
		return int(FileAccess.get_modified_time(save_path))
	if FileAccess.file_exists(save_path + ".bak"):
		return int(FileAccess.get_modified_time(save_path + ".bak"))
	return int(Time.get_unix_time_from_system())


# 删除主存档、备份与临时文件。
func delete_save_files(save_path: String) -> bool:
	var succeeded := true
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			succeeded = DirAccess.remove_absolute(absolute) == OK and succeeded
	return succeeded


# 将备份恢复到主存档路径。
func restore_primary_document(save_path: String, document: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(save_path)
	var temporary := absolute + ".tmp"
	if not _write_verified_json(temporary, document):
		return false
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	return DirAccess.rename_absolute(temporary, absolute) == OK


# 原子写入存档：先写临时文件，验证后替换主文件并保留备份。
func write_atomic(save_path: String, document: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(save_path)
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	if not _write_verified_json(temporary, document):
		push_error("无法写入临时存档：%s" % FileAccess.get_open_error())
		return false
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(absolute):
		if DirAccess.rename_absolute(absolute, backup) != OK:
			DirAccess.remove_absolute(temporary)
			return false
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, absolute)
		return false
	return true


# 将字典写入 JSON 文件并验证可读性，失败时删除临时文件。
func _write_verified_json(path: String, document: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(document))
	file.close()
	var verify := FileAccess.open(path, FileAccess.READ)
	if verify == null:
		return false
	var parser := JSON.new()
	if parser.parse(verify.get_as_text()) != OK:
		DirAccess.remove_absolute(path)
		return false
	if not parser.data is Dictionary:
		DirAccess.remove_absolute(path)
		return false
	return true
