class_name WorkbenchBriefingDirector
extends RefCounted

const DAY_ONE_PATH := "res://data/briefings/day_01.json"

var workday_state: WorkdayContext


# 初始化简报导演，绑定工作日状态。
func _init(state: WorkdayContext) -> void:
	workday_state = state


# 根据配置与当前状态构建每日简报台词列表。
func build_lines() -> Array[String]:
	var data := _load_config(DAY_ONE_PATH)
	var lines: Array[String] = []
	var workday := ConfigDatabase.get_workday_for_day(workday_state.day_number)
	if workday.is_empty():
		for line: Variant in WorkdayContext.read_array(data, "fixed"):
			lines.append(WorkdayContext.stringify_value(line))
	else:
		var configured_day := WorkdayContext.read_int(workday, "day_number", workday_state.day_number)
		lines.append("内部广播。第十二区，第 %02d 工作日。" % configured_day)
		lines.append(WorkdayContext.read_string(workday, "briefing_title", "今日行政指导"))
		for policy: Variant in WorkdayContext.read_array(workday, "policy_cards"):
			lines.append("今日规则：%s" % WorkdayContext.stringify_value(policy))
	var fragments := _read_dictionaries(data, "conditional")
	fragments.sort_custom(_sort_by_priority_descending)
	var seen := _read_meta_dictionary("briefing_seen")
	for fragment: Dictionary in fragments:
		var fragment_id := WorkdayContext.read_string(fragment, "id")
		var once := WorkdayContext.read_bool(fragment, "once")
		if once and seen.has(fragment_id):
			continue
		if not _matches(WorkdayContext.read_dictionary(fragment, "condition")):
			continue
		for line: Variant in WorkdayContext.read_array(fragment, "lines"):
			lines.append(WorkdayContext.stringify_value(line))
		if once and not fragment_id.is_empty():
			seen[fragment_id] = true
	workday_state.set_meta("briefing_seen", seen)
	if not lines.is_empty() and not lines[-1].contains("召唤铃"):
		lines.append("简报结束。请按下召唤铃，传唤第一位申请人。")
	return lines


# 判断条件片段是否对应当前工作日状态。
func _matches(condition: Dictionary) -> bool:
	if condition.has("water_deprived") and WorkdayContext.read_bool(condition, "water_deprived") != workday_state.water_deprived:
		return false
	if WorkdayContext.read_bool(condition, "has_incorrect_record"):
		var found := false
		for record: Dictionary in workday_state.records:
			if not WorkdayContext.read_bool(record, "correct", true):
				found = true
				break
		if not found:
			return false
	return true


# 加载每日简报 JSON 配置；缺失时返回兜底文案。
func _load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"fixed": ["内部广播。今日流程配置缺失。请按铃开始工作。"]}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		@warning_ignore("unsafe_cast")
		var config: Dictionary = parsed
		return config
	return {"fixed": ["内部广播。简报读取失败。请按铃开始工作。"]}


# 从字典字段收窄强类型字典列表。
func _read_dictionaries(source: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in WorkdayContext.read_array(source, key):
		if value is Dictionary:
			@warning_ignore("unsafe_cast")
			var entry: Dictionary = value
			result.append(entry)
	return result


# 按简报片段优先级降序排列。
func _sort_by_priority_descending(a: Dictionary, b: Dictionary) -> bool:
	return WorkdayContext.read_int(a, "priority") > WorkdayContext.read_int(b, "priority")


# 从工作日状态的元数据读取字典。
func _read_meta_dictionary(key: String) -> Dictionary:
	var value: Variant = workday_state.get_meta(key, {})
	if value is Dictionary:
		@warning_ignore("unsafe_cast")
		var result: Dictionary = value
		return result.duplicate(true)
	return {}
