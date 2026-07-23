extends Node

# 工作日状态。
# 管理玩家每日的案件记录、结算、存档、工作时长与跨日推进，是连接玩法与持久化的核心状态。

const CASES_PER_DAY := 3
const DEFAULT_SAVE_PATH := "user://formocracy-save.json"

# 当前工作日的核心数据
var day_number := 1
var records: Array[Dictionary] = []
var save_path := DEFAULT_SAVE_PATH
var current_level_id := "day_1"
var target_case_count := CASES_PER_DAY
var report_title := "工作日处理回执"
var player_name := ""
var reinstatement_date := ""
var player_signature: Array = []

# 案件决策缓存与后续后果
var decision_by_case_id: Dictionary = {}
var persistence_enabled := true

# 工作时长与经济状态
var workday_duration := 180.0
var seconds_remaining := 180.0
var base_salary := 0
var living_expenses: Dictionary = {}
var balance := 0
var political_credit := 0
var delayed_consequences: Array[Dictionary] = []


# 使用 CSV 关卡配置初始化工作日状态。
func configure_level(level_id: String, configured_day: int, case_count: int, configured_report_title: String) -> void:
	current_level_id = level_id
	day_number = configured_day
	target_case_count = maxi(1, case_count)
	report_title = configured_report_title
	records.clear()


# 使用 JSON 工作日本体配置初始化工作日状态（时长、日薪、生活支出等）。
func configure_workday(workday: Dictionary) -> void:
	current_level_id = String(workday.get("id", "WORKDAY-001"))
	day_number = int(workday.get("day_number", 1))
	target_case_count = workday.get("case_ids", []).size()
	report_title = String(workday.get("report_title", "工作日处理回执"))
	workday_duration = float(workday.get("duration_seconds", 180))
	seconds_remaining = workday_duration
	base_salary = int(workday.get("base_salary", 0))
	living_expenses = workday.get("living_expenses", {}).duplicate(true)
	if records.is_empty():
		decision_by_case_id.clear()


# 将一份申请的处理结果追加到当日记录。
# case_data 为原始案件字典，stamp_type 为处理决策（通常为“批准”或“驳回”）。
# 会对缺失字段使用默认值（未标明部门 / 未编号事项 / 身份记录受限 / 事项内容受限），并设置 submitted 为 true、effective 为 false。
# 记录一份案件的处理结果（简化版，无程序错误与耗时）。
func record_case(case_data: Dictionary, stamp_type: String) -> void:
	record_case_result(case_data, stamp_type, [], 0.0, [])


# 记录一份案件的处理结果，包括决策、程序错误、耗时与已装袋材料。
# 根据规则评估判断是否决策正确，并应用对应的后果（绩效、罚款、政治信用等）。
func record_case_result(case_data: Dictionary, stamp_type: String, procedure_errors: Array, elapsed_seconds: float, packed_document_ids: Array) -> void:
	var evaluation: Dictionary = ConfigDatabase.evaluate_gameplay_case(case_data) if case_data.has("rule_ids") else {"decision": String(case_data.get("correct_decision", stamp_type)), "violation_ids": []}
	var correct := stamp_type == String(evaluation.get("decision", "")) and procedure_errors.is_empty()
	var consequence_id := String(case_data.get("consequence_correct_id" if correct else "consequence_wrong_id", ""))
	var consequence := ConfigDatabase.get_ontology("consequences", consequence_id)
	records.append({
		"case_id": String(case_data.get("case_id", "")),
		"character_id": String(case_data.get("character_id", "")),
		"department": String(case_data.get("department", "未标明部门")),
		"code": String(case_data.get("code", "未编号事项")),
		"applicant": String(case_data.get("applicant", "身份记录受限")),
		"request": String(case_data.get("request", "事项内容受限")),
		"decision": stamp_type,
		"correct_decision": evaluation.get("decision", ""),
		"correct": correct,
		"violation_ids": evaluation.get("violation_ids", []),
		"procedure_errors": procedure_errors.duplicate(),
		"packed_document_ids": packed_document_ids.duplicate(),
		"elapsed_seconds": elapsed_seconds,
		"performance": int(consequence.get("performance", 0)),
		"fine": int(consequence.get("fine", 0)),
		"political_credit": int(consequence.get("political_credit", 0)),
		"consequence_id": consequence_id,
		"submitted": true,
		"effective": false
	})
	var delay_days := int(consequence.get("delay_days", 0))
	if delay_days > 0:
		delayed_consequences.append({"due_day": day_number + delay_days, "case_id": case_data.get("case_id", ""), "consequence_id": consequence_id})
	political_credit += int(consequence.get("political_credit", 0))
	var case_id := String(case_data.get("case_id", ""))
	if not case_id.is_empty():
		decision_by_case_id[case_id] = stamp_type
	if persistence_enabled:
		save_progress()


# 每帧推进工作倒计时，秒数不会低于 0。
func tick(delta: float) -> void:
	seconds_remaining = maxf(0.0, seconds_remaining - delta)


# 判断当日工作时长是否已耗尽。
func is_time_up() -> bool:
	return seconds_remaining <= 0.0


# 计算当前工作日的结算（日薪、绩效、罚款、生活支出与净结余）。
func get_settlement() -> Dictionary:
	var performance := 0
	var fines := 0
	for record in records:
		performance += int(record.get("performance", 0))
		fines += int(record.get("fine", 0))
	var expenses := 0
	for amount in living_expenses.values():
		expenses += int(amount)
	return {
		"base_salary": base_salary,
		"performance": performance,
		"fines": fines,
		"living_expenses": expenses,
		"net": base_salary + performance - fines - expenses,
		"balance_after": balance + base_salary + performance - fines - expenses,
		"political_evaluation": "受到关注" if political_credit < 0 else "评价稳定",
	}


# 判断当前工作日是否已积累足够案件以触发日报场景。
# 当 records 数量达到 CASES_PER_DAY（3 件）时返回 true。
func should_show_report() -> bool:
	return records.size() >= target_case_count


# 查询指定案件在本工作日的玩家决策。
func get_case_decision(case_id: String) -> String:
	return String(decision_by_case_id.get(case_id, ""))


# 遍历当日记录并生成统计摘要。
# 统计字段包括 reviewed（已审查数）、submitted（已送交数）、approved（批准数）、rejected（驳回数）、returned（退回补正数，当前固定 0）、
# effective（已取得现实效力数）与 pending（等待设施处理数）。返回的字典供日报界面使用。
func get_summary() -> Dictionary:
	var approved := 0
	var rejected := 0
	var effective := 0
	var procedure_errors := 0
	for record in records:
		if record.decision == "批准":
			approved += 1
		elif record.decision == "驳回":
			rejected += 1
		if record.effective:
			effective += 1
		procedure_errors += record.get("procedure_errors", []).size()
	return {
		"reviewed": records.size(),
		"submitted": records.size(),
		"approved": approved,
		"rejected": rejected,
		"returned": 0,
		"effective": effective,
		"pending": records.size() - effective
		,"procedure_errors": procedure_errors
	}


# 进入下一工作日。
# 将 day_number 加 1，并清空 records 数组，准备接收新一天的案件。
# 进入下一工作日：更新余额并清空当日记录。
func begin_next_day() -> void:
	balance = int(get_settlement().balance_after)
	day_number += 1
	records.clear()
	if persistence_enabled:
		save_progress()


# 判断是否存在可加载的存档文件。
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


# 开始新游戏：重置所有状态并删除旧存档。
func start_new_game() -> void:
	day_number = 1
	records.clear()
	current_level_id = "day_1"
	target_case_count = CASES_PER_DAY
	report_title = "工作日处理回执"
	player_name = ""
	reinstatement_date = ""
	player_signature.clear()
	decision_by_case_id.clear()
	balance = 0
	political_credit = 0
	delayed_consequences.clear()
	persistence_enabled = true
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# 将当前进度写入存档文件。
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
		"player_name": player_name,
		"reinstatement_date": reinstatement_date,
		"player_signature": player_signature,
		"decision_by_case_id": decision_by_case_id,
		"balance": balance,
		"political_credit": political_credit,
		"delayed_consequences": delayed_consequences,
	}))
	return true


# 从存档文件读取进度并恢复状态。
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
	player_name = String(parsed.get("player_name", ""))
	reinstatement_date = String(parsed.get("reinstatement_date", ""))
	player_signature = parsed.get("player_signature", []).duplicate(true)
	decision_by_case_id = parsed.get("decision_by_case_id", {}).duplicate()
	balance = int(parsed.get("balance", 0))
	political_credit = int(parsed.get("political_credit", 0))
	delayed_consequences.assign(parsed.get("delayed_consequences", []))
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
	player_name = ""
	reinstatement_date = ""
	player_signature.clear()
	decision_by_case_id.clear()
	workday_duration = 180.0
	seconds_remaining = workday_duration
	base_salary = 0
	living_expenses.clear()
	balance = 0
	political_credit = 0
	delayed_consequences.clear()
	persistence_enabled = false
