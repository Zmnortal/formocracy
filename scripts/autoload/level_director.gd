extends Node

# 关卡导演。
# 负责根据 CSV 配置和本体数据组装每日案件队列，支持故事槽位条件分支与随机池补位。
const DEFAULT_LEVEL_ID := "day_1"

# 当前激活关卡与运行时状态
var active_level_id := ""
var active_level: Dictionary = {}
var current_slot := 0
var used_case_ids: Dictionary = {}
var last_case_id := ""
var seed_override := -1
var rng := RandomNumberGenerator.new()
var runtime_errors: Array[String] = []

# 游戏玩法模式（基于 workday 配置）的案件队列
var gameplay_case_ids: Array[String] = []
var gameplay_index := 0


# 启动指定关卡，按种子生成随机队列，并根据 preserve_progress 保留已处理记录。
# 返回是否成功启动。
func start_level(level_id: String, custom_seed := -1, preserve_progress := false) -> bool:
	runtime_errors.clear()
	var level := ConfigDatabase.get_level(level_id)
	if level.is_empty():
		runtime_errors.append("关卡不存在：%s" % level_id)
		return false
	active_level_id = level_id
	active_level = level
	seed_override = custom_seed
	var chosen_seed := custom_seed if custom_seed >= 0 else int(level.get("random_seed", 0))
	rng.seed = chosen_seed
	current_slot = WorkdayState.records.size() if preserve_progress else 0
	used_case_ids.clear()
	if preserve_progress:
		for record in WorkdayState.records:
			var saved_case_id := String(record.get("case_id", ""))
			if not saved_case_id.is_empty():
				used_case_ids[saved_case_id] = true
	else:
		WorkdayState.configure_level(
			level_id,
			int(level.get("day_number", 1)),
			int(level.get("case_count", 1)),
			String(level.get("report_title", "工作日处理回执"))
		)
	last_case_id = ""
	return true


# 确保已有激活关卡；若未激活则根据 WorkdayState 当前关卡启动。
func ensure_active_level() -> bool:
	if not active_level.is_empty():
		return true
	var level_id: String = String(WorkdayState.current_level_id)
	if level_id.is_empty():
		level_id = DEFAULT_LEVEL_ID
	return start_level(level_id, -1, not WorkdayState.records.is_empty())


# 获取下一个关卡案件。
# 优先按槽位配置的故事案件填充；无可用固定案件时从普通池中随机抽取。
func get_next_case() -> Dictionary:
	if not ensure_active_level():
		return {}
	var case_count := int(active_level.get("case_count", 0))
	if current_slot >= case_count:
		return {}
	current_slot += 1
	var slot_data := ConfigDatabase.get_slot(active_level_id, current_slot)
	var selected_case_id := ""
	if not slot_data.is_empty() and _slot_condition_matches(slot_data):
		var fixed_case_id := String(slot_data.get("case_id", ""))
		if _is_available_case(fixed_case_id):
			selected_case_id = fixed_case_id
	if selected_case_id.is_empty():
		selected_case_id = _draw_normal_case()
	if selected_case_id.is_empty():
		var message := "关卡 %s 的槽位 %d 无可用案件" % [active_level_id, current_slot]
		runtime_errors.append(message)
		push_error(message)
		return {}
	used_case_ids[selected_case_id] = true
	last_case_id = selected_case_id
	var result := ConfigDatabase.get_case(selected_case_id)
	result.slot = current_slot
	result.level_id = active_level_id
	return result


# 检查槽位的前置案件条件是否满足。
func _slot_condition_matches(slot_data: Dictionary) -> bool:
	var required_case_id := String(slot_data.get("required_case_id", ""))
	if required_case_id.is_empty():
		return true
	var required_decision := String(slot_data.get("required_decision", ""))
	return WorkdayState.get_case_decision(required_case_id) == required_decision


# 判断案件是否可用：ID 有效、未被使用且存在于配置中。
func _is_available_case(case_id: String) -> bool:
	return not case_id.is_empty() and not used_case_ids.has(case_id) and not ConfigDatabase.get_case(case_id).is_empty()


# 从当前关卡的普通池标签中随机抽取一个可用案件。
func _draw_normal_case() -> String:
	var pool_tag := String(active_level.get("normal_pool_tag", ""))
	var available: Array[String] = []
	for case_id in ConfigDatabase.get_cases_by_pool(pool_tag):
		if _is_available_case(case_id):
			available.append(case_id)
	if available.is_empty():
		return ""
	return available[rng.randi_range(0, available.size() - 1)]


# 重新加载配置并重置当前关卡。
func reload_configs() -> bool:
	if not ConfigDatabase.reload():
		return false
	var level_id := active_level_id if not active_level_id.is_empty() else DEFAULT_LEVEL_ID
	return start_level(level_id, seed_override)


# 获取导演器当前运行状态摘要，用于调试与日志。
func get_state_summary() -> Dictionary:
	return {
		"level_id": active_level_id,
		"current_slot": current_slot,
		"case_count": int(active_level.get("case_count", 0)),
		"last_case_id": last_case_id,
		"used_case_ids": used_case_ids.keys(),
		"runtime_errors": runtime_errors.duplicate(),
	}


# 启动基于 workday 配置的游戏玩法工作日。
# 读取工作日的案件 ID 列表并初始化 WorkdayState。
func start_gameplay_workday(workday_id := "WORKDAY-001") -> bool:
	var workday := ConfigDatabase.get_workday(workday_id)
	if workday.is_empty():
		runtime_errors.append("工作日不存在：%s" % workday_id)
		return false
	gameplay_case_ids.assign(workday.get("case_ids", []))
	gameplay_index = WorkdayState.records.size()
	WorkdayState.configure_workday(workday)
	return true


# 获取游戏玩法队列中的下一个案件。
# 若队列未初始化会自动启动默认工作日。
func get_next_gameplay_case() -> Dictionary:
	if gameplay_case_ids.is_empty() and not start_gameplay_workday():
		return {}
	if gameplay_index >= gameplay_case_ids.size():
		return {}
	var case_id := gameplay_case_ids[gameplay_index]
	gameplay_index += 1
	var result := ConfigDatabase.get_gameplay_case(case_id)
	result.slot = gameplay_index
	result.level_id = String(ConfigDatabase.get_workday().get("id", "WORKDAY-001"))
	return result


# 返回尚未处理的剩余案件 ID 列表，用于队列显示。
func get_gameplay_queue() -> Array[String]:
	return gameplay_case_ids.slice(gameplay_index)
