extends Node

const CASES_PER_DAY := 3
const DEFAULT_SAVE_PATH := "user://formocracy-save.json"

var day_number := 1
var records: Array[Dictionary] = []
var save_path := DEFAULT_SAVE_PATH
var current_level_id := "day_1"
var target_case_count := CASES_PER_DAY
var report_title := "工作日处理回执"
var decision_by_case_id: Dictionary = {}
var persistence_enabled := true


func configure_level(level_id: String, configured_day: int, case_count: int, configured_report_title: String) -> void:
	current_level_id = level_id
	day_number = configured_day
	target_case_count = maxi(1, case_count)
	report_title = configured_report_title
	records.clear()


# 将一份申请的处理结果追加到当日记录。
# case_data 为原始案件字典，stamp_type 为处理决策（通常为“批准”或“驳回”）。
# 会对缺失字段使用默认值（未标明部门 / 未编号事项 / 身份记录受限 / 事项内容受限），并设置 submitted 为 true、effective 为 false。
func record_case(case_data: Dictionary, stamp_type: String) -> void:
	records.append({
		"case_id": String(case_data.get("case_id", "")),
		"character_id": String(case_data.get("character_id", "")),
		"department": String(case_data.get("department", "未标明部门")),
		"code": String(case_data.get("code", "未编号事项")),
		"applicant": String(case_data.get("applicant", "身份记录受限")),
		"request": String(case_data.get("request", "事项内容受限")),
		"decision": stamp_type,
		"submitted": true,
		"effective": false
	})
	var case_id := String(case_data.get("case_id", ""))
	if not case_id.is_empty():
		decision_by_case_id[case_id] = stamp_type
	if persistence_enabled:
		save_progress()


# 判断当前工作日是否已积累足够案件以触发日报场景。
# 当 records 数量达到 CASES_PER_DAY（3 件）时返回 true。
func should_show_report() -> bool:
	return records.size() >= target_case_count


func get_case_decision(case_id: String) -> String:
	return String(decision_by_case_id.get(case_id, ""))


# 遍历当日记录并生成统计摘要。
# 统计字段包括 reviewed（已审查数）、submitted（已送交数）、approved（批准数）、rejected（驳回数）、returned（退回补正数，当前固定 0）、
# effective（已取得现实效力数）与 pending（等待设施处理数）。返回的字典供日报界面使用。
func get_summary() -> Dictionary:
	var approved := 0
	var rejected := 0
	var effective := 0
	for record in records:
		if record.decision == "批准":
			approved += 1
		elif record.decision == "驳回":
			rejected += 1
		if record.effective:
			effective += 1
	return {
		"reviewed": records.size(),
		"submitted": records.size(),
		"approved": approved,
		"rejected": rejected,
		"returned": 0,
		"effective": effective,
		"pending": records.size() - effective
	}


# 进入下一工作日。
# 将 day_number 加 1，并清空 records 数组，准备接收新一天的案件。
func begin_next_day() -> void:
	day_number += 1
	records.clear()
	if persistence_enabled:
		save_progress()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func start_new_game() -> void:
	day_number = 1
	records.clear()
	current_level_id = "day_1"
	target_case_count = CASES_PER_DAY
	report_title = "工作日处理回执"
	decision_by_case_id.clear()
	persistence_enabled = true
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func save_progress() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档：%s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify({
		"version": 2,
		"day_number": day_number,
		"records": records,
		"current_level_id": current_level_id,
		"target_case_count": target_case_count,
		"report_title": report_title,
		"decision_by_case_id": decision_by_case_id,
	}))
	return true


func load_progress() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	day_number = maxi(1, int(parsed.get("day_number", 1)))
	records.assign(parsed.get("records", []))
	current_level_id = String(parsed.get("current_level_id", "day_1"))
	target_case_count = maxi(1, int(parsed.get("target_case_count", CASES_PER_DAY)))
	report_title = String(parsed.get("report_title", "工作日处理回执"))
	decision_by_case_id = parsed.get("decision_by_case_id", {}).duplicate()
	if decision_by_case_id.is_empty():
		for record in records:
			var saved_case_id := String(record.get("case_id", ""))
			if not saved_case_id.is_empty():
				decision_by_case_id[saved_case_id] = String(record.get("decision", ""))
	persistence_enabled = true
	return true


# 测试与调试辅助方法。
# 将 day_number 重置为 1 并清空 records，恢复游戏到初始状态。
func reset_for_tests() -> void:
	day_number = 1
	records.clear()
	current_level_id = "day_1"
	target_case_count = CASES_PER_DAY
	report_title = "工作日处理回执"
	decision_by_case_id.clear()
	persistence_enabled = false
