extends Node

const CONFIG_DIR := "res://data/config"
const TABLES := {
	"characters": {
		"path": CONFIG_DIR + "/characters.csv",
		"required": ["character_id", "display_name", "citizen_id", "portrait_path", "character_type", "tags", "notes"],
	},
	"cases": {
		"path": CONFIG_DIR + "/cases.csv",
		"required": ["case_id", "character_id", "department", "form_code", "request_text", "check_1", "check_2", "check_3", "correct_decision", "pool_tags"],
	},
	"levels": {
		"path": CONFIG_DIR + "/levels.csv",
		"required": ["level_id", "day_number", "case_count", "normal_pool_tag", "random_seed", "report_title"],
	},
	"level_slots": {
		"path": CONFIG_DIR + "/level_slots.csv",
		"required": ["level_id", "slot", "case_id", "is_story", "required_case_id", "required_decision"],
	},
}

var characters: Dictionary = {}
var cases: Dictionary = {}
var levels: Dictionary = {}
var level_slots: Dictionary = {}
var errors: Array[String] = []
var warnings: Array[String] = []
var loaded := false


func _ready() -> void:
	reload()


func reload() -> bool:
	characters.clear()
	cases.clear()
	levels.clear()
	level_slots.clear()
	errors.clear()
	warnings.clear()

	var rows_by_table := {}
	for table_name in TABLES:
		var table: Dictionary = TABLES[table_name]
		rows_by_table[table_name] = _read_csv(
			String(table.path),
			table.required as Array,
			table_name
		)

	_index_rows(rows_by_table.get("characters", []), "character_id", characters, "characters")
	_index_rows(rows_by_table.get("cases", []), "case_id", cases, "cases")
	_index_rows(rows_by_table.get("levels", []), "level_id", levels, "levels")
	_index_slots(rows_by_table.get("level_slots", []))
	_normalize_values()
	_validate_relations()
	loaded = errors.is_empty()
	if not loaded:
		for message in errors:
			push_error("配置错误：" + message)
	for message in warnings:
		push_warning("配置警告：" + message)
	return loaded


func _read_csv(path: String, required_headers: Array, table_name: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		errors.append("%s 缺少文件：%s" % [table_name, path])
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("%s 无法读取：%s" % [table_name, path])
		return []
	var headers := file.get_csv_line()
	for required in required_headers:
		if not headers.has(String(required)):
			errors.append("%s 缺少必填列：%s" % [table_name, required])
	var rows: Array[Dictionary] = []
	var line_number := 1
	while not file.eof_reached():
		line_number += 1
		var values := file.get_csv_line()
		if values.size() == 1 and String(values[0]).strip_edges().is_empty():
			continue
		var row := {}
		for index in headers.size():
			row[String(headers[index]).strip_edges()] = String(values[index] if index < values.size() else "").strip_edges()
		row["_line"] = line_number
		rows.append(row)
	return rows


func _index_rows(rows: Array, id_field: String, target: Dictionary, table_name: String) -> void:
	for row in rows:
		var id := String(row.get(id_field, ""))
		if id.is_empty():
			errors.append("%s 第 %d 行的 %s 为空" % [table_name, int(row.get("_line", 0)), id_field])
		elif target.has(id):
			errors.append("%s 存在重复 ID：%s" % [table_name, id])
		else:
			target[id] = row


func _index_slots(rows: Array) -> void:
	for row in rows:
		var level_id := String(row.get("level_id", ""))
		var slot := String(row.get("slot", "")).to_int()
		if level_id.is_empty() or slot <= 0:
			errors.append("level_slots 第 %d 行缺少有效 level_id 或 slot" % int(row.get("_line", 0)))
			continue
		var key := _slot_key(level_id, slot)
		if level_slots.has(key):
			errors.append("level_slots 存在重复槽位：%s / %d" % [level_id, slot])
		else:
			level_slots[key] = row


func _normalize_values() -> void:
	for character in characters.values():
		character.tags = _split_tags(String(character.get("tags", "")))
	for case_data in cases.values():
		case_data.pool_tags = _split_tags(String(case_data.get("pool_tags", "")))
		case_data.checks = [
			String(case_data.get("check_1", "")),
			String(case_data.get("check_2", "")),
			String(case_data.get("check_3", "")),
		]
	for level in levels.values():
		level.day_number = String(level.get("day_number", "0")).to_int()
		level.case_count = String(level.get("case_count", "0")).to_int()
		level.random_seed = String(level.get("random_seed", "0")).to_int()
	for slot_data in level_slots.values():
		slot_data.slot = String(slot_data.get("slot", "0")).to_int()
		slot_data.is_story = String(slot_data.get("is_story", "")).to_lower() in ["true", "1", "yes"]


func _validate_relations() -> void:
	for case_id in cases:
		var case_data: Dictionary = cases[case_id]
		var character_id := String(case_data.get("character_id", ""))
		if not characters.has(character_id):
			errors.append("案件 %s 引用了不存在的角色 %s" % [case_id, character_id])
		if String(case_data.get("correct_decision", "")) not in ["批准", "驳回"]:
			errors.append("案件 %s 的 correct_decision 必须是批准或驳回" % case_id)
	for level_id in levels:
		var level: Dictionary = levels[level_id]
		if int(level.case_count) <= 0:
			errors.append("关卡 %s 的 case_count 必须大于 0" % level_id)
	for slot_data in level_slots.values():
		var level_id := String(slot_data.get("level_id", ""))
		var case_id := String(slot_data.get("case_id", ""))
		var required_case_id := String(slot_data.get("required_case_id", ""))
		var required_decision := String(slot_data.get("required_decision", ""))
		if not levels.has(level_id):
			errors.append("槽位引用了不存在的关卡：%s" % level_id)
		if not case_id.is_empty() and not cases.has(case_id):
			errors.append("槽位引用了不存在的案件：%s" % case_id)
		if not required_case_id.is_empty() and not cases.has(required_case_id):
			errors.append("槽位前置案件不存在：%s" % required_case_id)
		if not required_decision.is_empty() and required_decision not in ["批准", "驳回"]:
			errors.append("槽位前置决定必须是批准或驳回：%s" % required_decision)


func get_character(character_id: String) -> Dictionary:
	return characters.get(character_id, {})


func get_case(case_id: String) -> Dictionary:
	if not cases.has(case_id):
		return {}
	var result: Dictionary = cases[case_id].duplicate(true)
	var character: Dictionary = get_character(String(result.get("character_id", "")))
	result.character = character.duplicate(true)
	result.applicant = "%s，公民序号 %s" % [
		String(character.get("display_name", "身份受限")),
		String(character.get("citizen_id", "未登记")),
	]
	result.code = String(result.get("form_code", "未编号事项"))
	result.request = String(result.get("request_text", "事项内容受限"))
	return result


func get_level(level_id: String) -> Dictionary:
	return levels.get(level_id, {}).duplicate(true)


func get_slot(level_id: String, slot: int) -> Dictionary:
	return level_slots.get(_slot_key(level_id, slot), {}).duplicate(true)


func get_cases_by_pool(pool_tag: String) -> Array[String]:
	var result: Array[String] = []
	for case_id in cases:
		var tags: Array = cases[case_id].get("pool_tags", [])
		if tags.has(pool_tag):
			result.append(String(case_id))
	result.sort()
	return result


func get_level_ids() -> Array[String]:
	var result: Array[String] = []
	for level_id in levels:
		result.append(String(level_id))
	result.sort()
	return result


func _slot_key(level_id: String, slot: int) -> String:
	return "%s:%d" % [level_id, slot]


func _split_tags(raw: String) -> Array[String]:
	var result: Array[String] = []
	for item in raw.split("|", false):
		var clean := item.strip_edges()
		if not clean.is_empty():
			result.append(clean)
	return result
