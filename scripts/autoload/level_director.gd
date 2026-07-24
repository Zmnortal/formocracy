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
var active_gameplay_workday: Dictionary = {}
var gameplay_used_case_ids: Dictionary = {}


# 启动指定关卡，按种子生成随机队列，并根据 preserve_progress 保留已处理记录。
# 返回是否成功启动。
func start_level(level_id: String, custom_seed: int = -1, preserve_progress: bool = false) -> bool:
	runtime_errors.clear()
	var level := ConfigDatabase.get_level(level_id)
	if level.is_empty():
		runtime_errors.append("关卡不存在：%s" % level_id)
		return false
	active_level_id = level_id
	active_level = level
	seed_override = custom_seed
	var chosen_seed := custom_seed if custom_seed >= 0 else WorkdayContext.read_int(level, "random_seed")
	rng.seed = chosen_seed
	current_slot = WorkdayState.records.size() if preserve_progress else 0
	used_case_ids.clear()
	if preserve_progress:
		for record: Dictionary in WorkdayState.records:
			var saved_case_id := WorkdayContext.read_string(record, "case_id")
			if not saved_case_id.is_empty():
				used_case_ids[saved_case_id] = true
	else:
		WorkdayState.configure_level(
			level_id, WorkdayContext.read_int(level, "day_number", 1), WorkdayContext.read_int(level, "case_count", 1), WorkdayContext.read_string(level, "report_title", "工作日处理回执")
		)
	last_case_id = ""
	return true


# 确保已有激活关卡；若未激活则根据 WorkdayState 当前关卡启动。
func ensure_active_level() -> bool:
	if not active_level.is_empty():
		return true
	var level_id := WorkdayState.current_level_id
	if level_id.is_empty():
		level_id = DEFAULT_LEVEL_ID
	return start_level(level_id, -1, not WorkdayState.records.is_empty())


# 获取下一个关卡案件。
# 优先按槽位配置的故事案件填充；无可用固定案件时从普通池中随机抽取。
func get_next_case() -> Dictionary:
	if not ensure_active_level():
		return {}
	var case_count := WorkdayContext.read_int(active_level, "case_count")
	if current_slot >= case_count:
		return {}
	current_slot += 1
	var slot_data := ConfigDatabase.get_slot(active_level_id, current_slot)
	var selected_case_id := ""
	if not slot_data.is_empty() and _slot_condition_matches(slot_data):
		var fixed_case_id := WorkdayContext.read_string(slot_data, "case_id")
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
	var required_case_id := WorkdayContext.read_string(slot_data, "required_case_id")
	if required_case_id.is_empty():
		return true
	var required_decision := WorkdayContext.read_string(slot_data, "required_decision")
	return WorkdayState.get_case_decision(required_case_id) == required_decision


# 判断案件是否可用：ID 有效、未被使用且存在于配置中。
func _is_available_case(case_id: String) -> bool:
	return not case_id.is_empty() and not used_case_ids.has(case_id) and not ConfigDatabase.get_case(case_id).is_empty()


# 从当前关卡的普通池标签中随机抽取一个可用案件。
func _draw_normal_case() -> String:
	var pool_tag := WorkdayContext.read_string(active_level, "normal_pool_tag")
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
		"case_count": WorkdayContext.read_int(active_level, "case_count"),
		"last_case_id": last_case_id,
		"used_case_ids": used_case_ids.keys(),
		"runtime_errors": runtime_errors.duplicate(),
	}


# 启动基于 JSON 内容包的游戏玩法工作日。
# 未指定 ID 时按存档中的当前游戏日选择 Day 1—7，并根据槽位配置组装案件队列。
func start_gameplay_workday(workday_id: String = "") -> bool:
	var workday := ConfigDatabase.get_workday(workday_id) if not workday_id.is_empty() else ConfigDatabase.get_workday_for_day(WorkdayState.day_number)
	if workday.is_empty():
		runtime_errors.append("工作日不存在：%s" % (workday_id if not workday_id.is_empty() else "第 %d 日" % WorkdayState.day_number))
		return false
	active_gameplay_workday = workday
	gameplay_case_ids.clear()
	gameplay_used_case_ids.clear()
	var chosen_seed := WorkdayContext.read_int(workday, "random_seed")
	rng.seed = chosen_seed
	var slots := _read_dictionaries(workday, "slots")
	if slots.is_empty():
		gameplay_case_ids = _read_string_list(workday, "case_ids")
	else:
		slots.sort_custom(_sort_gameplay_slots)
		for slot: Dictionary in slots:
			var selected_case_id := _resolve_gameplay_slot(slot)
			if selected_case_id.is_empty():
				(
					runtime_errors
					. append(
						(
							"工作日 %s 的槽位 %d 无可用案件"
							% [
								WorkdayContext.read_string(workday, "id"),
								WorkdayContext.read_int(slot, "slot"),
							]
						)
					)
				)
				return false
			gameplay_case_ids.append(selected_case_id)
			gameplay_used_case_ids[selected_case_id] = true
	gameplay_index = WorkdayState.records.size()
	WorkdayState.configure_workday(workday)
	return true


# 解析一个配置化玩法槽位。满足条件时优先使用固定剧情案件，否则从指定普通池抽取。
func _resolve_gameplay_slot(slot: Dictionary) -> String:
	var fixed_case_id := WorkdayContext.read_string(slot, "case_id")
	if _gameplay_conditions_match(WorkdayContext.read_array(slot, "conditions")) and _is_available_gameplay_case(fixed_case_id):
		return fixed_case_id
	var fallback_case_id := WorkdayContext.read_string(slot, "fallback_case_id")
	if _is_available_gameplay_case(fallback_case_id):
		return fallback_case_id
	var pool_tag := WorkdayContext.read_string(slot, "pool_tag")
	if pool_tag.is_empty():
		return ""
	var content_kind := WorkdayContext.read_string(slot, "kind", "general")
	var available: Array[String] = []
	for case_id in ConfigDatabase.get_gameplay_cases_by_pool(pool_tag, content_kind):
		if _is_available_gameplay_case(case_id):
			available.append(case_id)
	if available.is_empty():
		return ""
	return available[rng.randi_range(0, available.size() - 1)]


# 判断 JSON 槽位条件。条件读取跨日归档，而不是仅查看当天已经清空的记录。
func _gameplay_conditions_match(raw_conditions: Array) -> bool:
	for condition_value: Variant in raw_conditions:
		if not condition_value is Dictionary:
			return false
		@warning_ignore("unsafe_cast")
		var condition: Dictionary = condition_value
		var case_id := WorkdayContext.read_string(condition, "case_id")
		var historical_decision := _historical_case_decision(case_id)
		match WorkdayContext.read_string(condition, "kind", "case_seen"):
			"case_seen":
				if historical_decision.is_empty():
					return false
			"case_not_seen":
				if not historical_decision.is_empty():
					return false
			"decision_is":
				if historical_decision != WorkdayContext.read_string(condition, "decision"):
					return false
			_:
				return false
	return true


# 返回指定案件最近一次归档决定，支持跨日回访条件。
func _historical_case_decision(case_id: String) -> String:
	if case_id.is_empty():
		return ""
	for index in range(WorkdayState.archived_cases.size() - 1, -1, -1):
		var archive: Dictionary = WorkdayState.archived_cases[index]
		if WorkdayContext.read_string(archive, "case_id") == case_id:
			return WorkdayContext.read_string(archive, "decision")
	return WorkdayState.get_case_decision(case_id)


# 判断玩法案件是否存在且尚未进入当前队列。
func _is_available_gameplay_case(case_id: String) -> bool:
	return not case_id.is_empty() and not gameplay_used_case_ids.has(case_id) and not ConfigDatabase.get_gameplay_case(case_id).is_empty()


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
	result.level_id = WorkdayContext.read_string(active_gameplay_workday, "id", ConfigDatabase.get_default_workday_id())
	return result


# 返回尚未处理的剩余案件 ID 列表，用于队列显示。
func get_gameplay_queue() -> Array[String]:
	return gameplay_case_ids.slice(gameplay_index)


# 从动态配置字段读取字符串列表。
func _read_string_list(source: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in WorkdayContext.read_array(source, key):
		var text := WorkdayContext.stringify_value(value)
		if not text.is_empty():
			result.append(text)
	return result


# 从动态配置字段读取字典列表。
func _read_dictionaries(source: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in WorkdayContext.read_array(source, key):
		if value is Dictionary:
			@warning_ignore("unsafe_cast")
			var entry: Dictionary = value
			result.append(entry)
	return result


# 按玩法槽位编号升序排列。
func _sort_gameplay_slots(left: Dictionary, right: Dictionary) -> bool:
	return WorkdayContext.read_int(left, "slot") < WorkdayContext.read_int(right, "slot")
