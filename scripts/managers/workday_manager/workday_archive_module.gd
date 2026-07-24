class_name WorkdayArchiveModule
extends RefCounted

# 管理档案创建、积压等待和有限容量的机器验收。

var state: WorkdayContext


# 记录所属的工作日状态引用。
func _init(owner_state: WorkdayContext) -> void:
	state = owner_state


# 将处理完的案件写入档案列表并分配递增的档案编号。
func archive_record(recorded: Dictionary) -> void:
	(
		state
		. archived_cases
		. append(
			{
				"archive_id": "ARCHIVE-%05d" % state.next_archive_serial,
				"case_id": WorkdayContext.read_string(recorded, "case_id"),
				"character_id": WorkdayContext.read_string(recorded, "character_id"),
				"applicant": WorkdayContext.read_string(recorded, "applicant"),
				"request": WorkdayContext.read_string(recorded, "request"),
				"decision": WorkdayContext.read_string(recorded, "decision"),
				"procedure_errors": WorkdayContext.read_array(recorded, "procedure_errors"),
				"document_stamps": WorkdayContext.read_array(recorded, "document_stamps"),
				"archived_day": state.day_number,
				"waiting_days": 0,
				"status": "ARCHIVED",
				"loaded": false,
				"effective_day": 0,
			}
		)
	)
	state.next_archive_serial += 1


# 返回所有尚未生效（非 EFFECTIVE）的待验收档案。
func get_pending_archives() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for archive in state.archived_cases:
		if WorkdayContext.read_string(archive, "status", "ARCHIVED") != "EFFECTIVE":
			pending.append(archive)
	return pending


# 按机器容量批量验收档案：全部置为生效并同步对应案件记录，成功返回 true。
func validate_archive_batch(archive_ids: Array) -> bool:
	if archive_ids.is_empty() or archive_ids.size() > state.machine_capacity:
		return false
	var selected := {}
	for archive_id: Variant in archive_ids:
		selected[WorkdayContext.stringify_value(archive_id)] = true
	for archive in state.archived_cases:
		if selected.has(WorkdayContext.read_string(archive, "archive_id")) and WorkdayContext.read_string(archive, "status", "ARCHIVED") == "EFFECTIVE":
			return false
	for archive in state.archived_cases:
		if not selected.has(WorkdayContext.read_string(archive, "archive_id")):
			continue
		archive.status = "EFFECTIVE"
		archive.loaded = false
		archive.effective_day = state.day_number
		for record in state.records:
			if WorkdayContext.read_string(record, "case_id") == WorkdayContext.read_string(archive, "case_id"):
				record.effective = true
	if state.persistence_enabled:
		state.save_progress()
	return true


# 将所有未生效档案的等待天数加 1。
func age_pending_archives() -> void:
	for archive in state.archived_cases:
		if WorkdayContext.read_string(archive, "status", "ARCHIVED") != "EFFECTIVE":
			archive.waiting_days = WorkdayContext.read_int(archive, "waiting_days") + 1
