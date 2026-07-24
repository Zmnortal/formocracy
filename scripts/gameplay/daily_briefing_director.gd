class_name DailyBriefingDirector
extends RefCounted

const DAY_ONE_PATH := "res://data/briefings/day_01.json"

var workday_state: Node


func _init(state: Node) -> void:
	workday_state = state


func build_lines() -> Array[String]:
	var data := _load_config(DAY_ONE_PATH)
	var lines: Array[String] = []
	for line in data.get("fixed", []):
		lines.append(String(line))
	var fragments: Array = data.get("conditional", []).duplicate(true)
	fragments.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	var seen: Dictionary = workday_state.get_meta("briefing_seen", {})
	for fragment in fragments:
		var fragment_id := String(fragment.get("id", ""))
		if bool(fragment.get("once", false)) and seen.has(fragment_id):
			continue
		if not _matches(fragment.get("condition", {})):
			continue
		for line in fragment.get("lines", []):
			lines.append(String(line))
		if bool(fragment.get("once", false)) and not fragment_id.is_empty():
			seen[fragment_id] = true
	workday_state.set_meta("briefing_seen", seen)
	return lines


func _matches(condition: Dictionary) -> bool:
	if condition.has("water_deprived") and bool(condition.water_deprived) != bool(workday_state.water_deprived):
		return false
	if bool(condition.get("has_incorrect_record", false)):
		var found := false
		for record in workday_state.records:
			if not bool(record.get("correct", true)):
				found = true
				break
		if not found:
			return false
	return true


func _load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"fixed": ["内部广播。今日流程配置缺失。请按铃开始工作。"]}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {"fixed": ["内部广播。简报读取失败。请按铃开始工作。"]}
