extends WorkdayContext

# 工作日状态。
# 管理玩家每日的案件记录、结算、存档、工作时长与跨日推进，是连接玩法与持久化的核心状态。

const SaveSchema := preload("res://scripts/save/save_schema.gd")
const SaveSystem := preload("res://scripts/save/save_system.gd")
const WorkdayManagerScript := preload("res://scripts/managers/workday_manager/workday_manager.gd")
const DEFAULT_SAVE_PATH := SaveSchema.DEFAULT_PATH
const SAVE_TREE_VERSION := SaveSchema.CURRENT_VERSION

var save_system: FormocracySaveSystem:
	get:
		return _save()
var manager: WorkdayManager:
	get:
		return _manager_instance()

var _save_system: FormocracySaveSystem
var _workday_manager: WorkdayManager


# 返回当前使用的存档系统实例；若未创建则初始化。
func _save() -> FormocracySaveSystem:
	if _save_system == null:
		_save_system = SaveSystem.new(self)
	return _save_system


# 返回工作日 Manager 实例；若未创建则初始化。
func _manager_instance() -> WorkdayManager:
	if _workday_manager == null:
		_workday_manager = WorkdayManagerScript.new(self)
	return _workday_manager


# 使用 CSV 关卡配置初始化工作日状态。
func configure_level(level_id: String, configured_day: int, case_count: int, configured_report_title: String) -> void:
	current_level_id = level_id
	day_number = configured_day
	target_case_count = maxi(1, case_count)
	report_title = configured_report_title
	records.clear()


# 使用 JSON 工作日本体配置初始化工作日状态（时长、日薪、生活支出等）。
func configure_workday(workday: Dictionary) -> void:
	var loaded_seconds_remaining := seconds_remaining
	current_level_id = read_string(workday, "id", "WORKDAY-001")
	# 工作日配置定义的是该关卡最早可出现的日期，不能覆盖存档中已经推进的日期。
	# 否则进入下一天主场景时，WORKDAY-001 会把 day_number 从 2 写回 1，
	# 夜间地图便会误判为同一天并保留已经用尽的行动次数。
	day_number = maxi(day_number, read_int(workday, "day_number", 1))
	var case_ids := read_array(workday, "case_ids")
	var slots := read_array(workday, "slots")
	var inferred_case_count := case_ids.size() if not case_ids.is_empty() else slots.size()
	target_case_count = maxi(1, read_int(workday, "case_count", inferred_case_count))
	report_title = read_string(workday, "report_title", "工作日处理回执")
	workday_duration = read_float(workday, "duration_seconds", 180.0)
	machine_capacity = maxi(1, read_int(workday, "machine_capacity", 2))
	base_salary = read_int(workday, "base_salary")
	living_expenses = read_dictionary(workday, "living_expenses")
	if resume_loaded:
		seconds_remaining = clampf(loaded_seconds_remaining, 0.0, workday_duration)
		resume_loaded = false
	else:
		seconds_remaining = workday_duration
	if records.is_empty():
		decision_by_case_id.clear()


# 查询指定案件在本工作日的玩家决策。
func get_case_decision(case_id: String) -> String:
	return read_string(decision_by_case_id, case_id)


# 审核到期的个人表单。饮水表字段与登记身份一致时核发，否则退回补正。
func process_due_personal_forms() -> void:
	manager.process_due_personal_forms()


# 根据饮水保障状态准备新工作日，缺水会缩短时间并降低拖拽响应。
func prepare_new_workday() -> void:
	manager.prepare_new_workday()


# 在抵达地点后登记一次夜间行动。回家始终可达，行动数不会低于零。
func arrive_at_evening_location(location_id: String) -> void:
	evening_location_id = location_id
	if evening_actions_remaining > 0:
		evening_actions_remaining -= 1
	if persistence_enabled:
		save_progress()


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
	workday_duration = 180.0
	seconds_remaining = workday_duration
	base_salary = 0
	living_expenses.clear()
	balance = 0
	political_credit = 0
	delayed_consequences.clear()
	settled_day_number = 0
	machine_capacity = 2
	archived_cases.clear()
	next_archive_serial = 1
	desk_item_layout.clear()
	evening_day_number = 0
	evening_actions_remaining = 2
	evening_location_id = "LOCATION-OFFICE"
	personal_form_inventory.clear()
	next_inventory_serial = 1
	water_covered_until_day = 1
	water_deprived = false
	last_personal_review_results.clear()
	newspaper_subscriptions.clear()
	newspaper_read_history.clear()
	last_newspaper_submission_result.clear()
	active_checkpoint_id = ""
	resume_loaded = false
	persistence_enabled = true
	save_system.delete_save()


# 将当前状态捕获为可独立恢复的完整快照。
func _capture_state() -> Dictionary:
	return {
		"day_number": day_number,
		"records": records,
		"current_level_id": current_level_id,
		"target_case_count": target_case_count,
		"report_title": report_title,
		"player_name": player_name,
		"reinstatement_date": reinstatement_date,
		"player_signature": player_signature,
		"workday_duration": workday_duration,
		"seconds_remaining": seconds_remaining,
		"base_salary": base_salary,
		"living_expenses": living_expenses,
		"decision_by_case_id": decision_by_case_id,
		"balance": balance,
		"political_credit": political_credit,
		"delayed_consequences": delayed_consequences,
		"settled_day_number": settled_day_number,
		"machine_capacity": machine_capacity,
		"archived_cases": archived_cases,
		"next_archive_serial": next_archive_serial,
		"desk_item_layout": desk_item_layout,
		"evening_day_number": evening_day_number,
		"evening_actions_remaining": evening_actions_remaining,
		"evening_location_id": evening_location_id,
		"personal_form_inventory": personal_form_inventory,
		"next_inventory_serial": next_inventory_serial,
		"water_covered_until_day": water_covered_until_day,
		"water_deprived": water_deprived,
		"last_personal_review_results": last_personal_review_results,
		"newspaper_subscriptions": newspaper_subscriptions,
		"newspaper_read_history": newspaper_read_history,
		"last_newspaper_submission_result": last_newspaper_submission_result,
	}


# 将当前完整状态写入存档文件。
func save_progress() -> bool:
	return _save().save_progress()


# 创建完成工作日后的时间线检查点。
func create_checkpoint(completed_day: int) -> bool:
	return _save().create_checkpoint(completed_day)


# 根据已恢复的状态决定返回晨间读报、工作台、日报还是下班地图。
func get_resume_phase() -> String:
	if records.is_empty() and read_string(newspaper_read_history, str(day_number)).is_empty():
		return "pre_work"
	if records.size() < target_case_count:
		return "workbench"
	if settled_day_number == day_number:
		return "evening"
	return "daily_report"


# 从存档字典恢复运行时状态。
func _apply_state(state: Dictionary) -> void:
	day_number = maxi(1, read_int(state, "day_number", 1))
	records.assign(read_array(state, "records"))
	current_level_id = read_string(state, "current_level_id", "day_1")
	target_case_count = maxi(1, read_int(state, "target_case_count", CASES_PER_DAY))
	report_title = read_string(state, "report_title", "工作日处理回执")
	player_name = read_string(state, "player_name")
	reinstatement_date = read_string(state, "reinstatement_date")
	player_signature = read_array(state, "player_signature")
	workday_duration = maxf(1.0, read_float(state, "workday_duration", workday_duration))
	seconds_remaining = clampf(read_float(state, "seconds_remaining", workday_duration), 0.0, workday_duration)
	base_salary = read_int(state, "base_salary", base_salary)
	living_expenses = read_dictionary(state, "living_expenses", living_expenses)
	decision_by_case_id = read_dictionary(state, "decision_by_case_id")
	balance = read_int(state, "balance")
	political_credit = read_int(state, "political_credit")
	delayed_consequences.assign(read_array(state, "delayed_consequences"))
	settled_day_number = read_int(state, "settled_day_number")
	machine_capacity = maxi(1, read_int(state, "machine_capacity", 2))
	archived_cases.assign(read_array(state, "archived_cases"))
	next_archive_serial = maxi(1, read_int(state, "next_archive_serial", archived_cases.size() + 1))
	desk_item_layout = read_dictionary(state, "desk_item_layout")
	evening_day_number = read_int(state, "evening_day_number")
	evening_actions_remaining = clampi(read_int(state, "evening_actions_remaining", 2), 0, 2)
	evening_location_id = read_string(state, "evening_location_id", "LOCATION-OFFICE")
	personal_form_inventory.assign(read_array(state, "personal_form_inventory"))
	next_inventory_serial = maxi(1, read_int(state, "next_inventory_serial", personal_form_inventory.size() + 1))
	water_covered_until_day = read_int(state, "water_covered_until_day", 1)
	water_deprived = read_bool(state, "water_deprived")
	last_personal_review_results.assign(read_array(state, "last_personal_review_results"))
	newspaper_subscriptions = read_dictionary(state, "newspaper_subscriptions")
	newspaper_read_history = read_dictionary(state, "newspaper_read_history")
	last_newspaper_submission_result = read_dictionary(state, "last_newspaper_submission_result")


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
	settled_day_number = 0
	machine_capacity = 2
	archived_cases.clear()
	next_archive_serial = 1
	desk_item_layout.clear()
	evening_day_number = 0
	evening_actions_remaining = 2
	evening_location_id = "LOCATION-OFFICE"
	personal_form_inventory.clear()
	next_inventory_serial = 1
	water_covered_until_day = 1
	water_deprived = false
	last_personal_review_results.clear()
	newspaper_subscriptions.clear()
	newspaper_read_history.clear()
	last_newspaper_submission_result.clear()
	resume_loaded = false
	persistence_enabled = false
