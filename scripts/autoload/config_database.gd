extends Node

# 配置数据库。
# 加载并索引 CSV 配置（角色、案件、关卡）与 JSON 本体数据（人物、目的、材料类型、规则、违规、后果、案件、工作日），
# 提供统一的查询接口与规则评估入口。

const RULE_EVALUATOR := preload("res://scripts/rules/rule_evaluator.gd")
const CONFIG_DIR := "res://data/config"

# 本体 JSON 文件路径表
const ONTOLOGY_FILES := {
	"people": "res://data/ontology/people.json",
	"purposes": "res://data/ontology/purposes.json",
	"document_types": "res://data/ontology/document_types.json",
	"rules": "res://data/ontology/rules.json",
	"violations": "res://data/ontology/violations.json",
	"consequences": "res://data/ontology/consequences.json",
	"locations": "res://data/ontology/locations.json",
	"personal_forms": "res://data/ontology/personal_forms.json",
	"cases_v2": "res://data/cases/day_01_cases.json",
	"workdays": "res://data/levels/day_01.json",
}
# CSV 表配置：路径与必填列
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

# 已加载的数据表与错误信息
var characters: Dictionary = {}
var cases: Dictionary = {}
var levels: Dictionary = {}
var level_slots: Dictionary = {}
var errors: Array[String] = []
var warnings: Array[String] = []
var loaded := false
var ontology: Dictionary = {}


# 节点就绪时自动重载所有配置。
func _ready() -> void:
	reload()


# 重载全部配置数据，清空旧数据后依次读取 CSV、索引、校验并加载本体。
# 返回 true 表示没有错误，配置可正常使用。
func reload() -> bool:
	characters.clear()
	cases.clear()
	levels.clear()
	level_slots.clear()
	errors.clear()
	warnings.clear()
	ontology.clear()

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
	_load_ontology()
	_validate_ontology()
	loaded = errors.is_empty()
	if not loaded:
		for message in errors:
			push_error("配置错误：" + message)
	for message in warnings:
		push_warning("配置警告：" + message)
	return loaded


# 加载所有 JSON 本体文件，按 id 字段索引并校验重复 ID。
func _load_ontology() -> void:
	for table_name in ONTOLOGY_FILES:
		var path := String(ONTOLOGY_FILES[table_name])
		if not FileAccess.file_exists(path):
			errors.append("本体 %s 缺少文件：%s" % [table_name, path])
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		var rows: Array = [parsed] if table_name == "workdays" and parsed is Dictionary else parsed
		if not rows is Array:
			errors.append("本体 %s 必须是 JSON 数组或工作日对象" % table_name)
			continue
		var index := {}
		for row in rows:
			if not row is Dictionary or String(row.get("id", "")).is_empty():
				errors.append("本体 %s 含有缺少稳定 ID 的对象" % table_name)
				continue
			var object_id := String(row.id)
			if index.has(object_id):
				errors.append("本体 %s 存在重复 ID：%s" % [table_name, object_id])
			else:
				index[object_id] = row
		ontology[table_name] = index


# 校验本体之间的引用关系：案件引用的人物、目的、后果、材料类型、规则等必须存在。
func _validate_ontology() -> void:
	for case_id in ontology.get("cases_v2", {}):
		var case_data: Dictionary = ontology.cases_v2[case_id]
		_require_reference(case_id, "person_id", case_data, "people")
		_require_reference(case_id, "purpose_id", case_data, "purposes")
		_require_reference(case_id, "consequence_correct_id", case_data, "consequences")
		_require_reference(case_id, "consequence_wrong_id", case_data, "consequences")
		var document_ids := {}
		for document in case_data.get("documents", []):
			var document_id := String(document.get("id", ""))
			if document_id.is_empty() or document_ids.has(document_id):
				errors.append("案件 %s 的材料 ID 为空或重复：%s" % [case_id, document_id])
			document_ids[document_id] = true
			if not ontology.get("document_types", {}).has(String(document.get("document_type_id", ""))):
				errors.append("案件 %s 的材料 %s 引用了不存在的材料类型" % [case_id, document_id])
		for document_id in case_data.get("document_ids", []):
			if not document_ids.has(String(document_id)):
				errors.append("案件 %s 引用了不存在的材料 %s" % [case_id, document_id])
		for type_id in case_data.get("required_document_type_ids", []):
			if not ontology.get("document_types", {}).has(String(type_id)):
				errors.append("案件 %s 引用了不存在的必需材料类型 %s" % [case_id, type_id])
		for rule_id in case_data.get("rule_ids", []):
			if not ontology.get("rules", {}).has(String(rule_id)):
				errors.append("案件 %s 引用了不存在的规则 %s" % [case_id, rule_id])
	for rule_id in ontology.get("rules", {}):
		var rule: Dictionary = ontology.rules[rule_id]
		if not ontology.get("violations", {}).has(String(rule.get("violation_id", ""))):
			errors.append("规则 %s 引用了不存在的违规类型" % rule_id)
	for workday_id in ontology.get("workdays", {}):
		for case_id in ontology.workdays[workday_id].get("case_ids", []):
			if not ontology.get("cases_v2", {}).has(String(case_id)):
				errors.append("工作日 %s 引用了不存在的案件 %s" % [workday_id, case_id])
	for form_id in ontology.get("personal_forms", {}):
		var form: Dictionary = ontology.personal_forms[form_id]
		_require_reference(form_id, "issuer_location_id", form, "locations")
		if int(form.get("fee", -1)) < 0:
			errors.append("个人表单 %s 的工本费不能小于零" % form_id)
	for location_id in ontology.get("locations", {}):
		for form_id in ontology.locations[location_id].get("sells_form_ids", []):
			if not ontology.get("personal_forms", {}).has(String(form_id)):
				errors.append("地点 %s 引用了不存在的个人表单 %s" % [location_id, form_id])


# 辅助：校验 source 对象中的 field 是否指向目标本体表中的有效 ID。
func _require_reference(owner_id: String, field: String, source: Dictionary, target_table: String) -> void:
	var reference_id := String(source.get(field, ""))
	if not ontology.get(target_table, {}).has(reference_id):
		errors.append("%s 的 %s 引用了不存在的 %s：%s" % [owner_id, field, target_table, reference_id])


# 读取 CSV 文件并返回字典数组；若文件缺失或列缺失会记录错误。
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


# 将 CSV 行按 id 字段索引到 target 字典中，并检测重复 ID。
func _index_rows(rows: Array, id_field: String, target: Dictionary, table_name: String) -> void:
	for row in rows:
		var id := String(row.get(id_field, ""))
		if id.is_empty():
			errors.append("%s 第 %d 行的 %s 为空" % [table_name, int(row.get("_line", 0)), id_field])
		elif target.has(id):
			errors.append("%s 存在重复 ID：%s" % [table_name, id])
		else:
			target[id] = row


# 将 level_slots 行按 level_id 与 slot 组合索引，并检测重复槽位。
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


# 统一转换 CSV 字符串字段为运行时类型（标签数组、整数、布尔值等）。
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


# 校验 CSV 配置之间的引用关系（角色、关卡、槽位等）。
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


# 按 ID 获取角色配置。
func get_character(character_id: String) -> Dictionary:
	return characters.get(character_id, {})


# 按 ID 获取案件配置，并合并申请人身份信息与显示文本。
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


# 按 ID 获取关卡配置。
func get_level(level_id: String) -> Dictionary:
	return levels.get(level_id, {}).duplicate(true)


# 按关卡 ID 与槽位号获取固定槽位配置。
func get_slot(level_id: String, slot: int) -> Dictionary:
	return level_slots.get(_slot_key(level_id, slot), {}).duplicate(true)


# 按普通池标签获取所有案件 ID。
func get_cases_by_pool(pool_tag: String) -> Array[String]:
	var result: Array[String] = []
	for case_id in cases:
		var tags: Array = cases[case_id].get("pool_tags", [])
		if tags.has(pool_tag):
			result.append(String(case_id))
	result.sort()
	return result


# 返回所有已加载的关卡 ID 列表。
func get_level_ids() -> Array[String]:
	var result: Array[String] = []
	for level_id in levels:
		result.append(String(level_id))
	result.sort()
	return result


# 按表名和 ID 获取本体对象。
func get_ontology(table_name: String, object_id: String) -> Dictionary:
	return ontology.get(table_name, {}).get(object_id, {}).duplicate(true)


# 按 ID 获取工作日本体对象；默认返回 WORKDAY-001。
func get_workday(workday_id := "WORKDAY-001") -> Dictionary:
	return get_ontology("workdays", workday_id)


# 按 ID 获取游戏玩法案件，合并人物、目的与主材料信息。
func get_gameplay_case(case_id: String) -> Dictionary:
	var result := get_ontology("cases_v2", case_id)
	if result.is_empty():
		return result
	var person := get_ontology("people", String(result.get("person_id", "")))
	var purpose := get_ontology("purposes", String(result.get("purpose_id", "")))
	result.person = person
	result.purpose = purpose
	result.character_id = String(result.get("person_id", ""))
	result.applicant = "%s，公民序号 %s" % [person.get("display_name", "身份受限"), person.get("citizen_id", "未登记")]
	result.department = String(purpose.get("department", "未标明部门"))
	result.code = String(result.get("form_code", "未编号事项"))
	var primary := _find_primary_document(result.get("documents", []))
	result.request = String(primary.get("fields", {}).get("request", purpose.get("name", "事项内容受限")))
	result.checks = ["核验必需材料", "对照字段与适用规定", "作出审批决定"]
	result.case_id = case_id
	return result


# 使用规则评估器判断案件是否应批准或驳回。
func evaluate_gameplay_case(case_data: Dictionary) -> Dictionary:
	return RULE_EVALUATOR.evaluate(case_data, ontology.get("rules", {}))


# 在案件材料中查找主材料；若不存在则返回第一份材料。
func _find_primary_document(documents: Array) -> Dictionary:
	for document in documents:
		var type_data := get_ontology("document_types", String(document.get("document_type_id", "")))
		if bool(type_data.get("is_primary", false)):
			return document
	return documents[0] if not documents.is_empty() else {}


# 生成 level_id 与 slot 的组合键。
func _slot_key(level_id: String, slot: int) -> String:
	return "%s:%d" % [level_id, slot]


# 将竖线分隔的标签字符串拆分为数组并去除空项。
func _split_tags(raw: String) -> Array[String]:
	var result: Array[String] = []
	for item in raw.split("|", false):
		var clean := item.strip_edges()
		if not clean.is_empty():
			result.append(clean)
	return result
