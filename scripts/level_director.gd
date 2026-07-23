extends Node

const DEFAULT_LEVEL_ID := "day_1"

var active_level_id := ""
var active_level: Dictionary = {}
var current_slot := 0
var used_case_ids: Dictionary = {}
var last_case_id := ""
var seed_override := -1
var rng := RandomNumberGenerator.new()
var runtime_errors: Array[String] = []


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


func ensure_active_level() -> bool:
	if not active_level.is_empty():
		return true
	var level_id: String = String(WorkdayState.current_level_id)
	if level_id.is_empty():
		level_id = DEFAULT_LEVEL_ID
	return start_level(level_id, -1, not WorkdayState.records.is_empty())


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


func _slot_condition_matches(slot_data: Dictionary) -> bool:
	var required_case_id := String(slot_data.get("required_case_id", ""))
	if required_case_id.is_empty():
		return true
	var required_decision := String(slot_data.get("required_decision", ""))
	return WorkdayState.get_case_decision(required_case_id) == required_decision


func _is_available_case(case_id: String) -> bool:
	return not case_id.is_empty() and not used_case_ids.has(case_id) and not ConfigDatabase.get_case(case_id).is_empty()


func _draw_normal_case() -> String:
	var pool_tag := String(active_level.get("normal_pool_tag", ""))
	var available: Array[String] = []
	for case_id in ConfigDatabase.get_cases_by_pool(pool_tag):
		if _is_available_case(case_id):
			available.append(case_id)
	if available.is_empty():
		return ""
	return available[rng.randi_range(0, available.size() - 1)]


func reload_configs() -> bool:
	if not ConfigDatabase.reload():
		return false
	var level_id := active_level_id if not active_level_id.is_empty() else DEFAULT_LEVEL_ID
	return start_level(level_id, seed_override)


func get_state_summary() -> Dictionary:
	return {
		"level_id": active_level_id,
		"current_slot": current_slot,
		"case_count": int(active_level.get("case_count", 0)),
		"last_case_id": last_case_id,
		"used_case_ids": used_case_ids.keys(),
		"runtime_errors": runtime_errors.duplicate(),
	}
