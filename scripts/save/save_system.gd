class_name FormocracySaveSystem
extends RefCounted

# 存档用例协调器：连接游戏状态快照、存档树、迁移和文件仓储。

const SaveSchema := preload("res://scripts/save/save_schema.gd")
const SaveRepository := preload("res://scripts/save/save_repository.gd")
const SaveMigrator := preload("res://scripts/save/save_migrator.gd")

var state: WorkdayContext
var repository := SaveRepository.new()


# 初始化保存系统，绑定所属游戏状态。
func _init(owner_state: WorkdayContext) -> void:
	state = owner_state


# 判断是否存在可加载的存档。
func has_save() -> bool:
	return repository.has_save(state.save_path)


# 返回全部时间线节点（会自动迁移旧版存档）。
func get_checkpoint_nodes() -> Array[Dictionary]:
	var document := _read_or_migrate_document()
	var result: Array[Dictionary] = []
	for node: Dictionary in _read_nodes(document):
		result.append(node.duplicate(true))
	return result


# 读取存档选择页所需的当前临时进度摘要。
func get_save_summary() -> Dictionary:
	var document := _read_or_migrate_document()
	if document.is_empty():
		return {}
	var working_state := WorkdayContext.read_dictionary(document, "working_state")
	var modified := WorkdayContext.read_int(document, "updated_at", repository.get_modified_time(state.save_path))
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(modified)
	return {
		"day_number": maxi(1, WorkdayContext.read_int(working_state, "day_number", 1)),
		"player_name": WorkdayContext.read_string(working_state, "player_name"),
		"date":
		(
			"%02d/%02d"
			% [
				WorkdayContext.read_int(datetime, "month"),
				WorkdayContext.read_int(datetime, "day"),
			]
		),
		"time":
		(
			"%02d:%02d"
			% [
				WorkdayContext.read_int(datetime, "hour"),
				WorkdayContext.read_int(datetime, "minute"),
			]
		),
	}


# 删除所有存档文件。
func delete_save() -> bool:
	return repository.delete_save_files(state.save_path)


# 创建 Opening 完成后的初始根节点存档。
func create_initial_checkpoint() -> bool:
	var document := SaveSchema.make_empty_tree()
	document["working_state"] = state._capture_state()
	document["updated_at"] = int(Time.get_unix_time_from_system())
	var root_id := _new_checkpoint_id(0)
	var nodes := _read_nodes(document)
	nodes.append(_make_checkpoint(root_id, "", 0, 0))
	document["nodes"] = nodes
	document["active_checkpoint_id"] = root_id
	state.active_checkpoint_id = root_id
	return repository.write_atomic(state.save_path, document)


# 将刚完成的一天保存为当前节点的新子节点。
func create_checkpoint(completed_day: int) -> bool:
	var document := _read_or_migrate_document()
	if document.is_empty():
		document = SaveSchema.make_empty_tree()
	var parent_id := state.active_checkpoint_id
	if parent_id.is_empty():
		parent_id = WorkdayContext.read_string(document, "active_checkpoint_id")
	var sibling_count := 0
	var nodes := _read_nodes(document)
	for node: Dictionary in nodes:
		if WorkdayContext.read_string(node, "parent_id") == parent_id:
			sibling_count += 1
	var node_id := _new_checkpoint_id(completed_day)
	nodes.append(_make_checkpoint(node_id, parent_id, completed_day, sibling_count))
	document["nodes"] = nodes
	document["version"] = SaveSchema.CURRENT_VERSION
	document["active_checkpoint_id"] = node_id
	document["working_state"] = state._capture_state()
	document["updated_at"] = int(Time.get_unix_time_from_system())
	state.active_checkpoint_id = node_id
	return repository.write_atomic(state.save_path, document)

	# 从指定历史节点恢复，并将其设为后续新分支的父节点。


func load_checkpoint(node_id: String) -> bool:
	var document := _read_or_migrate_document()
	for node: Dictionary in _read_nodes(document):
		if WorkdayContext.read_string(node, "node_id") != node_id:
			continue
		var snapshot := WorkdayContext.read_dictionary(node, "state")
		if snapshot.is_empty():
			return false
		state._apply_state(snapshot)
		state.active_checkpoint_id = node_id
		state.resume_loaded = true
		document["active_checkpoint_id"] = node_id
		document["working_state"] = state._capture_state()
		document["updated_at"] = int(Time.get_unix_time_from_system())
		state.persistence_enabled = true
		return repository.write_atomic(state.save_path, document)
	return false


# 删除选中节点及全部后代；初始根节点不可删除。
func delete_checkpoint(node_id: String) -> bool:
	var document := _read_or_migrate_document()
	var target: Dictionary = {}
	var nodes := _read_nodes(document)
	for node: Dictionary in nodes:
		if WorkdayContext.read_string(node, "node_id") == node_id:
			target = node
			break
	if target.is_empty() or WorkdayContext.read_int(target, "completed_day") == 0:
		return false
	var deleting := {node_id: true}
	var changed := true
	while changed:
		changed = false
		for node: Dictionary in nodes:
			var id := WorkdayContext.read_string(node, "node_id")
			var parent_id := WorkdayContext.read_string(node, "parent_id")
			if not deleting.has(id) and deleting.has(parent_id):
				deleting[id] = true
				changed = true
	var kept: Array[Dictionary] = []
	for node: Dictionary in nodes:
		if not deleting.has(WorkdayContext.read_string(node, "node_id")):
			kept.append(node)
	document["nodes"] = kept
	if deleting.has(WorkdayContext.read_string(document, "active_checkpoint_id")):
		var parent_id := WorkdayContext.read_string(target, "parent_id")
		document["active_checkpoint_id"] = parent_id
		state.active_checkpoint_id = parent_id
		for node: Dictionary in kept:
			if WorkdayContext.read_string(node, "node_id") == parent_id:
				document["working_state"] = WorkdayContext.read_dictionary(node, "state")
				break
	document["updated_at"] = int(Time.get_unix_time_from_system())
	return repository.write_atomic(state.save_path, document)


# 将当前完整状态写入存档文件。
func save_progress() -> bool:
	var document := _read_or_migrate_document()
	if document.is_empty():
		document = SaveSchema.make_empty_tree(state.active_checkpoint_id)
	document["version"] = SaveSchema.CURRENT_VERSION
	document["active_checkpoint_id"] = state.active_checkpoint_id
	document["working_state"] = state._capture_state()
	document["updated_at"] = int(Time.get_unix_time_from_system())
	return repository.write_atomic(state.save_path, document)


# 载入最近一次临时进度。
func load_progress() -> bool:
	var document := _read_or_migrate_document()
	if document.is_empty():
		return false
	var snapshot := WorkdayContext.read_dictionary(document, "working_state")
	if snapshot.is_empty():
		return false
	state._apply_state(snapshot)
	state.active_checkpoint_id = WorkdayContext.read_string(document, "active_checkpoint_id")
	state.resume_loaded = true
	if state.decision_by_case_id.is_empty():
		for record in state.records:
			var saved_case_id := WorkdayContext.read_string(record, "case_id")
			if not saved_case_id.is_empty():
				state.decision_by_case_id[saved_case_id] = WorkdayContext.read_string(record, "decision")
	state.persistence_enabled = true
	return true


# 修复 v5 及更早版本可能产生的跨日卡死存档。
func repair_legacy_exhausted_evening(save_version: int) -> bool:
	return SaveMigrator.repair_exhausted_evening(state, save_version)


# 读取主存档，损坏时尝试备份恢复，旧版存档自动迁移到树结构。
func _read_or_migrate_document() -> Dictionary:
	var document := repository.read_with_backup(state.save_path)
	if document.is_empty():
		return {}
	if WorkdayContext.read_int(document, "version", 1) >= SaveSchema.CURRENT_VERSION and document.has("nodes"):
		if state.active_checkpoint_id.is_empty():
			state.active_checkpoint_id = WorkdayContext.read_string(document, "active_checkpoint_id")
		return document
	var migrated: Dictionary = SaveMigrator.migrate_legacy_document(document, repository.get_modified_time(state.save_path), Callable(self, "_new_checkpoint_id"))
	state.active_checkpoint_id = WorkdayContext.read_string(migrated, "active_checkpoint_id")
	repository.write_atomic(state.save_path, migrated)
	return migrated


# 构造一个时间线节点字典。
func _make_checkpoint(node_id: String, parent_id: String, completed_day: int, branch_order: int) -> Dictionary:
	return {
		"node_id": node_id,
		"parent_id": parent_id,
		"completed_day": completed_day,
		"branch_order": branch_order,
		"created_at": int(Time.get_unix_time_from_system()),
		"player_name": state.player_name,
		"state": state._capture_state(),
	}


# 生成基于完成日期与微秒时间戳的唯一节点 ID。
func _new_checkpoint_id(completed_day: int) -> String:
	return "day-%02d-%d" % [completed_day, Time.get_ticks_usec()]


# 将动态存档节点数组收窄为 Manager 内部使用的强类型节点列表。
func _read_nodes(document: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in WorkdayContext.read_array(document, "nodes"):
		if value is Dictionary:
			@warning_ignore("unsafe_cast")
			var node: Dictionary = value
			result.append(node)
	return result
