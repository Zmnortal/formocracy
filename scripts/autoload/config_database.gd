extends Node

# 配置数据库。
# 加载并索引 CSV 配置（角色、案件、关卡）与 JSON 本体数据（人物、目的、材料类型、规则、违规、后果、案件、工作日），
# 提供统一的查询接口与规则评估入口。

const RULE_EVALUATOR := preload("res://scripts/rules/rule_evaluator.gd")
const CONFIG_DIR := "res://data/config"
const CONTENT_PACK_PATH := "res://data/narrative/content_pack.json"

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
	"proprietors": "res://data/ontology/proprietors.json",
	"cases_v2": "res://data/cases/day_01_cases.json",
	"workdays": "res://data/levels/day_01.json",
}
# CSV 表配置：路径与必填列
const TABLES := {
	"characters":
	{
		"path": CONFIG_DIR + "/characters.csv",
		"required": ["character_id", "display_name", "citizen_id", "portrait_path", "character_type", "tags", "notes"],
	},
	"cases":
	{
		"path": CONFIG_DIR + "/cases.csv",
		"required": ["case_id", "character_id", "department", "form_code", "request_text", "check_1", "check_2", "check_3", "correct_decision", "pool_tags"],
	},
	"levels":
	{
		"path": CONFIG_DIR + "/levels.csv",
		"required": ["level_id", "day_number", "case_count", "normal_pool_tag", "random_seed", "report_title"],
	},
	"level_slots":
	{
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
var content_pack: Dictionary = {}
var ontology_files: Dictionary = {}


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
	content_pack.clear()
	ontology_files = ONTOLOGY_FILES.duplicate(true)

	var rows_by_table: Dictionary = {}
	for table_name_value: Variant in TABLES:
		var table_name := WorkdayContext.stringify_value(table_name_value)
		var table := WorkdayContext.read_dictionary(TABLES, table_name)
		rows_by_table[table_name] = _read_csv(WorkdayContext.read_string(table, "path"), WorkdayContext.read_array(table, "required"), table_name)

	_index_rows(_read_dictionaries(rows_by_table, "characters"), "character_id", characters, "characters")
	_index_rows(_read_dictionaries(rows_by_table, "cases"), "case_id", cases, "cases")
	_index_rows(_read_dictionaries(rows_by_table, "levels"), "level_id", levels, "levels")
	_index_slots(_read_dictionaries(rows_by_table, "level_slots"))
	_normalize_values()
	_validate_relations()
	_load_content_pack()
	_load_ontology()
	_validate_ontology()
	loaded = errors.is_empty()
	if not loaded:
		for message in errors:
			push_error("配置错误：" + message)
	for message in warnings:
		push_warning("配置警告：" + message)
	return loaded


# 读取内容包清单，并用清单中的分表路径覆盖内置兼容路径。
func _load_content_pack() -> void:
	if not FileAccess.file_exists(CONTENT_PACK_PATH):
		warnings.append("叙事内容包不存在，继续使用内置 Day 1 配置：%s" % CONTENT_PACK_PATH)
		return
	var file := FileAccess.open(CONTENT_PACK_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not parsed is Dictionary:
		errors.append("叙事内容包必须是 JSON 对象：%s" % CONTENT_PACK_PATH)
		return
	@warning_ignore("unsafe_cast")
	content_pack = parsed
	if WorkdayContext.read_string(content_pack, "id").is_empty():
		errors.append("叙事内容包缺少稳定 id")
	var files := WorkdayContext.read_dictionary(content_pack, "files")
	if files.is_empty():
		errors.append("叙事内容包 files 必须是对象")
		return
	for table_name_value: Variant in files:
		var table_name := WorkdayContext.stringify_value(table_name_value)
		var path := WorkdayContext.stringify_value(files[table_name_value])
		if path.is_empty():
			errors.append("叙事内容包 %s 的路径为空" % table_name)
		else:
			ontology_files[table_name] = path


# 加载所有 JSON 本体文件，按 id 字段索引并校验重复 ID。
func _load_ontology() -> void:
	for table_name_value: Variant in ontology_files:
		var table_name := WorkdayContext.stringify_value(table_name_value)
		var path := WorkdayContext.stringify_value(ontology_files[table_name_value])
		if not FileAccess.file_exists(path):
			errors.append("本体 %s 缺少文件：%s" % [table_name, path])
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		var rows: Array = []
		if table_name == "workdays" and parsed is Dictionary:
			rows.append(parsed)
		elif parsed is Array:
			@warning_ignore("unsafe_cast")
			rows = parsed
		else:
			errors.append("本体 %s 必须是 JSON 数组或工作日对象" % table_name)
			continue
		var index: Dictionary = {}
		for row_value: Variant in rows:
			if not row_value is Dictionary:
				errors.append("本体 %s 含有缺少稳定 ID 的对象" % table_name)
				continue
			@warning_ignore("unsafe_cast")
			var row: Dictionary = row_value
			var object_id := WorkdayContext.read_string(row, "id")
			if object_id.is_empty():
				errors.append("本体 %s 含有缺少稳定 ID 的对象" % table_name)
				continue
			if index.has(object_id):
				errors.append("本体 %s 存在重复 ID：%s" % [table_name, object_id])
			else:
				index[object_id] = row
		ontology[table_name] = index


# 校验本体之间的引用关系：案件引用的人物、目的、后果、材料类型、规则等必须存在。
func _validate_ontology() -> void:
	var cases_table := _ontology_table("cases_v2")
	var people_table := _ontology_table("people")
	var document_types_table := _ontology_table("document_types")
	var rules_table := _ontology_table("rules")
	var violations_table := _ontology_table("violations")
	var workdays_table := _ontology_table("workdays")
	var storylines_table := _ontology_table("storylines")
	var personal_forms_table := _ontology_table("personal_forms")
	var locations_table := _ontology_table("locations")
	for type_id_value: Variant in document_types_table:
		var type_id := WorkdayContext.stringify_value(type_id_value)
		var type_data := WorkdayContext.read_dictionary(document_types_table, type_id)
		var visual_language := WorkdayContext.read_dictionary(type_data, "visual_language")
		if WorkdayContext.read_string(visual_language, "category").is_empty():
			errors.append("材料类型 %s 缺少 visual_language.category 功能分类" % type_id)
		if WorkdayContext.read_string(visual_language, "icon").is_empty():
			errors.append("材料类型 %s 缺少 visual_language.icon 像素图标" % type_id)
		var accent := WorkdayContext.read_string(visual_language, "accent")
		if accent.is_empty() or not Color.html_is_valid(accent):
			errors.append("材料类型 %s 的 visual_language.accent 不是有效颜色" % type_id)
	for case_id_value: Variant in cases_table:
		var case_id := WorkdayContext.stringify_value(case_id_value)
		var case_data := WorkdayContext.read_dictionary(cases_table, case_id)
		_require_reference(case_id, "person_id", case_data, "people")
		_require_reference(case_id, "purpose_id", case_data, "purposes")
		_require_reference(case_id, "consequence_correct_id", case_data, "consequences")
		_require_reference(case_id, "consequence_wrong_id", case_data, "consequences")
		var document_ids: Dictionary = {}
		var documents := _read_dictionaries(case_data, "documents")
		for document: Dictionary in documents:
			var document_id := WorkdayContext.read_string(document, "id")
			if document_id.is_empty() or document_ids.has(document_id):
				errors.append("案件 %s 的材料 ID 为空或重复：%s" % [case_id, document_id])
			document_ids[document_id] = true
			if not document_types_table.has(WorkdayContext.read_string(document, "document_type_id")):
				errors.append("案件 %s 的材料 %s 引用了不存在的材料类型" % [case_id, document_id])
		for document_id_value: Variant in WorkdayContext.read_array(case_data, "document_ids"):
			var document_id := WorkdayContext.stringify_value(document_id_value)
			if not document_ids.has(document_id):
				errors.append("案件 %s 引用了不存在的材料 %s" % [case_id, document_id])
		for type_id_value: Variant in WorkdayContext.read_array(case_data, "required_document_type_ids"):
			var type_id := WorkdayContext.stringify_value(type_id_value)
			if not document_types_table.has(type_id):
				errors.append("案件 %s 引用了不存在的必需材料类型 %s" % [case_id, type_id])
		for rule_id_value: Variant in WorkdayContext.read_array(case_data, "rule_ids"):
			var rule_id := WorkdayContext.stringify_value(rule_id_value)
			if not rules_table.has(rule_id):
				errors.append("案件 %s 引用了不存在的规则 %s" % [case_id, rule_id])
		var primary_count := 0
		if documents.size() > 6:
			errors.append("案件 %s 超过文件袋可展示的 6 份材料上限" % case_id)
		for document: Dictionary in documents:
			var type_data := WorkdayContext.read_dictionary(document_types_table, WorkdayContext.read_string(document, "document_type_id"))
			if WorkdayContext.read_bool(type_data, "is_primary"):
				primary_count += 1
		if primary_count != 1:
			errors.append("案件 %s 必须且只能包含一份主申请表，当前为 %d 份" % [case_id, primary_count])
		var storyline_id := WorkdayContext.read_string(case_data, "storyline_id")
		if WorkdayContext.read_string(case_data, "content_kind", "general") == "story" and not storylines_table.has(storyline_id):
			errors.append("剧情案件 %s 引用了不存在的故事线 %s" % [case_id, storyline_id])
	for rule_id_value: Variant in rules_table:
		var rule_id := WorkdayContext.stringify_value(rule_id_value)
		var rule := WorkdayContext.read_dictionary(rules_table, rule_id)
		if not violations_table.has(WorkdayContext.read_string(rule, "violation_id")):
			errors.append("规则 %s 引用了不存在的违规类型" % rule_id)
	for workday_id_value: Variant in workdays_table:
		var workday_id := WorkdayContext.stringify_value(workday_id_value)
		var workday := WorkdayContext.read_dictionary(workdays_table, workday_id)
		for case_id_value: Variant in WorkdayContext.read_array(workday, "case_ids"):
			var case_id := WorkdayContext.stringify_value(case_id_value)
			if not cases_table.has(case_id):
				errors.append("工作日 %s 引用了不存在的案件 %s" % [workday_id, case_id])
		var seen_slots: Dictionary = {}
		var slots := WorkdayContext.read_array(workday, "slots")
		for slot_value: Variant in slots:
			if not slot_value is Dictionary:
				errors.append("工作日 %s 含有非对象槽位" % workday_id)
				continue
			@warning_ignore("unsafe_cast")
			var slot: Dictionary = slot_value
			var slot_number := WorkdayContext.read_int(slot, "slot")
			if slot_number <= 0 or seen_slots.has(slot_number):
				errors.append("工作日 %s 的槽位编号无效或重复：%d" % [workday_id, slot_number])
			seen_slots[slot_number] = true
			var fixed_case_id := WorkdayContext.read_string(slot, "case_id")
			if not fixed_case_id.is_empty() and not cases_table.has(fixed_case_id):
				errors.append("工作日 %s 的槽位 %d 引用了不存在的案件 %s" % [workday_id, slot_number, fixed_case_id])
			var pool_tag := WorkdayContext.read_string(slot, "pool_tag")
			if fixed_case_id.is_empty() and pool_tag.is_empty():
				errors.append("工作日 %s 的槽位 %d 既无固定案件也无普通池" % [workday_id, slot_number])
			for condition: Dictionary in _read_dictionaries(slot, "conditions"):
				var condition_case_id := WorkdayContext.read_string(condition, "case_id")
				if not condition_case_id.is_empty():
					if not cases_table.has(condition_case_id):
						errors.append("工作日 %s 的槽位条件引用了不存在的案件 %s" % [workday_id, condition_case_id])
		var configured_count := WorkdayContext.read_int(workday, "case_count", slots.size())
		if not slots.is_empty() and configured_count != slots.size():
			errors.append("工作日 %s 的 case_count 与槽位数量不一致" % workday_id)
	for storyline_id_value: Variant in storylines_table:
		var storyline_id := WorkdayContext.stringify_value(storyline_id_value)
		var storyline := WorkdayContext.read_dictionary(storylines_table, storyline_id)
		for person_id_value: Variant in WorkdayContext.read_array(storyline, "character_ids"):
			var person_id := WorkdayContext.stringify_value(person_id_value)
			if not people_table.has(person_id):
				errors.append("故事线 %s 引用了不存在的人物 %s" % [storyline_id, person_id])
		for case_id_value: Variant in WorkdayContext.read_array(storyline, "case_ids"):
			var case_id := WorkdayContext.stringify_value(case_id_value)
			if not cases_table.has(case_id):
				errors.append("故事线 %s 引用了不存在的案件 %s" % [storyline_id, case_id])
	for form_id_value: Variant in personal_forms_table:
		var form_id := WorkdayContext.stringify_value(form_id_value)
		var form := WorkdayContext.read_dictionary(personal_forms_table, form_id)
		_require_reference(form_id, "issuer_location_id", form, "locations")
		if WorkdayContext.read_int(form, "fee", -1) < 0:
			errors.append("个人表单 %s 的工本费不能小于零" % form_id)
	for location_id_value: Variant in locations_table:
		var location_id := WorkdayContext.stringify_value(location_id_value)
		var location := WorkdayContext.read_dictionary(locations_table, location_id)
		for form_id_value: Variant in WorkdayContext.read_array(location, "sells_form_ids"):
			var form_id := WorkdayContext.stringify_value(form_id_value)
			if not personal_forms_table.has(form_id):
				errors.append("地点 %s 引用了不存在的个人表单 %s" % [location_id, form_id])


# 辅助：校验 source 对象中的 field 是否指向目标本体表中的有效 ID。
func _require_reference(owner_id: String, field: String, source: Dictionary, target_table: String) -> void:
	var reference_id := WorkdayContext.read_string(source, field)
	if not _ontology_table(target_table).has(reference_id):
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
	for required_value: Variant in required_headers:
		var required := WorkdayContext.stringify_value(required_value)
		if not headers.has(required):
			errors.append("%s 缺少必填列：%s" % [table_name, required])
	var rows: Array[Dictionary] = []
	var line_number := 1
	while not file.eof_reached():
		line_number += 1
		var values := file.get_csv_line()
		if values.size() == 1 and WorkdayContext.stringify_value(values[0]).strip_edges().is_empty():
			continue
		var row: Dictionary = {}
		for index in headers.size():
			var header := WorkdayContext.stringify_value(headers[index]).strip_edges()
			var value: Variant = values[index] if index < values.size() else ""
			row[header] = WorkdayContext.stringify_value(value).strip_edges()
		row["_line"] = line_number
		rows.append(row)
	return rows


# 将 CSV 行按 id 字段索引到 target 字典中，并检测重复 ID。
func _index_rows(rows: Array[Dictionary], id_field: String, target: Dictionary, table_name: String) -> void:
	for row: Dictionary in rows:
		var id := WorkdayContext.read_string(row, id_field)
		if id.is_empty():
			(
				errors
				. append(
					(
						"%s 第 %d 行的 %s 为空"
						% [
							table_name,
							WorkdayContext.read_int(row, "_line"),
							id_field,
						]
					)
				)
			)
		elif target.has(id):
			errors.append("%s 存在重复 ID：%s" % [table_name, id])
		else:
			target[id] = row


# 将 level_slots 行按 level_id 与 slot 组合索引，并检测重复槽位。
func _index_slots(rows: Array[Dictionary]) -> void:
	for row: Dictionary in rows:
		var level_id := WorkdayContext.read_string(row, "level_id")
		var slot := WorkdayContext.read_string(row, "slot").to_int()
		if level_id.is_empty() or slot <= 0:
			errors.append("level_slots 第 %d 行缺少有效 level_id 或 slot" % WorkdayContext.read_int(row, "_line"))
			continue
		var key := _slot_key(level_id, slot)
		if level_slots.has(key):
			errors.append("level_slots 存在重复槽位：%s / %d" % [level_id, slot])
		else:
			level_slots[key] = row


# 统一转换 CSV 字符串字段为运行时类型（标签数组、整数、布尔值等）。
func _normalize_values() -> void:
	for character_id_value: Variant in characters:
		var character_id := WorkdayContext.stringify_value(character_id_value)
		var character := WorkdayContext.read_dictionary(characters, character_id)
		character["tags"] = _split_tags(WorkdayContext.read_string(character, "tags"))
		characters[character_id] = character
	for case_id_value: Variant in cases:
		var case_id := WorkdayContext.stringify_value(case_id_value)
		var case_data := WorkdayContext.read_dictionary(cases, case_id)
		case_data["pool_tags"] = _split_tags(WorkdayContext.read_string(case_data, "pool_tags"))
		case_data["checks"] = [
			WorkdayContext.read_string(case_data, "check_1"),
			WorkdayContext.read_string(case_data, "check_2"),
			WorkdayContext.read_string(case_data, "check_3"),
		]
		cases[case_id] = case_data
	for level_id_value: Variant in levels:
		var level_id := WorkdayContext.stringify_value(level_id_value)
		var level := WorkdayContext.read_dictionary(levels, level_id)
		level["day_number"] = WorkdayContext.read_string(level, "day_number").to_int()
		level["case_count"] = WorkdayContext.read_string(level, "case_count").to_int()
		level["random_seed"] = WorkdayContext.read_string(level, "random_seed").to_int()
		levels[level_id] = level
	for slot_key_value: Variant in level_slots:
		var slot_key := WorkdayContext.stringify_value(slot_key_value)
		var slot_data := WorkdayContext.read_dictionary(level_slots, slot_key)
		slot_data["slot"] = WorkdayContext.read_string(slot_data, "slot").to_int()
		slot_data["is_story"] = (WorkdayContext.read_string(slot_data, "is_story").to_lower() in ["true", "1", "yes"])
		level_slots[slot_key] = slot_data


# 校验 CSV 配置之间的引用关系（角色、关卡、槽位等）。
func _validate_relations() -> void:
	for case_id_value: Variant in cases:
		var case_id := WorkdayContext.stringify_value(case_id_value)
		var case_data := WorkdayContext.read_dictionary(cases, case_id)
		var character_id := WorkdayContext.read_string(case_data, "character_id")
		if not characters.has(character_id):
			errors.append("案件 %s 引用了不存在的角色 %s" % [case_id, character_id])
		if WorkdayContext.read_string(case_data, "correct_decision") not in ["批准", "驳回"]:
			errors.append("案件 %s 的 correct_decision 必须是批准或驳回" % case_id)
	for level_id_value: Variant in levels:
		var level_id := WorkdayContext.stringify_value(level_id_value)
		var level := WorkdayContext.read_dictionary(levels, level_id)
		if WorkdayContext.read_int(level, "case_count") <= 0:
			errors.append("关卡 %s 的 case_count 必须大于 0" % level_id)
	for slot_value: Variant in level_slots.values():
		if not slot_value is Dictionary:
			continue
		@warning_ignore("unsafe_cast")
		var slot_data: Dictionary = slot_value
		var level_id := WorkdayContext.read_string(slot_data, "level_id")
		var case_id := WorkdayContext.read_string(slot_data, "case_id")
		var required_case_id := WorkdayContext.read_string(slot_data, "required_case_id")
		var required_decision := WorkdayContext.read_string(slot_data, "required_decision")
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
	return WorkdayContext.read_dictionary(characters, character_id)


# 按 ID 获取案件配置，并合并申请人身份信息与显示文本。
func get_case(case_id: String) -> Dictionary:
	if not cases.has(case_id):
		return {}
	var result := WorkdayContext.read_dictionary(cases, case_id)
	var character := get_character(WorkdayContext.read_string(result, "character_id"))
	result.character = character.duplicate(true)
	result.applicant = (
		"%s，公民序号 %s"
		% [
			WorkdayContext.read_string(character, "display_name", "身份受限"),
			WorkdayContext.read_string(character, "citizen_id", "未登记"),
		]
	)
	result.code = WorkdayContext.read_string(result, "form_code", "未编号事项")
	result.request = WorkdayContext.read_string(result, "request_text", "事项内容受限")
	return result


# 按 ID 获取关卡配置。
func get_level(level_id: String) -> Dictionary:
	return WorkdayContext.read_dictionary(levels, level_id)


# 按关卡 ID 与槽位号获取固定槽位配置。
func get_slot(level_id: String, slot: int) -> Dictionary:
	return WorkdayContext.read_dictionary(level_slots, _slot_key(level_id, slot))


# 按普通池标签获取所有案件 ID。
func get_cases_by_pool(pool_tag: String) -> Array[String]:
	var result: Array[String] = []
	for case_id_value: Variant in cases:
		var case_id := WorkdayContext.stringify_value(case_id_value)
		var case_data := WorkdayContext.read_dictionary(cases, case_id)
		var tags := WorkdayContext.read_array(case_data, "pool_tags")
		if tags.has(pool_tag):
			result.append(case_id)
	result.sort()
	return result


# 返回所有已加载的关卡 ID 列表。
func get_level_ids() -> Array[String]:
	var result: Array[String] = []
	for level_id_value: Variant in levels:
		result.append(WorkdayContext.stringify_value(level_id_value))
	result.sort()
	return result


# 按表名和 ID 获取本体对象。
func get_ontology(table_name: String, object_id: String) -> Dictionary:
	return WorkdayContext.read_dictionary(_ontology_table(table_name), object_id)


# 按 ID 获取工作日本体对象；默认返回 WORKDAY-001。
func get_workday(workday_id: String = "WORKDAY-001") -> Dictionary:
	return get_ontology("workdays", workday_id)


# 按游戏日查找工作日配置；超出战役范围时停留在最后一天。
func get_workday_for_day(day_number: int) -> Dictionary:
	var ordered: Array[Dictionary] = []
	for workday_value: Variant in _ontology_table("workdays").values():
		if workday_value is Dictionary:
			@warning_ignore("unsafe_cast")
			var workday: Dictionary = workday_value
			ordered.append(workday)
	ordered.sort_custom(_sort_workdays)
	if ordered.is_empty():
		return {}
	for workday: Dictionary in ordered:
		if WorkdayContext.read_int(workday, "day_number") == day_number:
			return workday.duplicate(true)
	return ordered[0].duplicate(true) if day_number < WorkdayContext.read_int(ordered[0], "day_number", 1) else ordered[-1].duplicate(true)


# 返回内容包声明的最后一个工作日序号；配置缺失时回退到已加载工作日的最大值。
func get_last_workday_day() -> int:
	var last_workday_id := WorkdayContext.read_string(content_pack, "last_workday_id")
	var configured := get_workday(last_workday_id)
	if not configured.is_empty():
		return maxi(1, WorkdayContext.read_int(configured, "day_number", 7))
	var last_day := 1
	for workday_value: Variant in _ontology_table("workdays").values():
		if workday_value is Dictionary:
			@warning_ignore("unsafe_cast")
			var workday: Dictionary = workday_value
			last_day = maxi(last_day, WorkdayContext.read_int(workday, "day_number", 1))
	return last_day


# 判断当前日期是否已经抵达七日内容包的硬终局。
func is_final_workday(day_number: int) -> bool:
	return day_number >= get_last_workday_day()


# 返回内容包声明的默认工作日。
func get_default_workday_id() -> String:
	return WorkdayContext.read_string(content_pack, "default_workday_id", "WORKDAY-001")


# 按标签返回 JSON 玩法案件 ID，供工作日普通槽随机抽取。
func get_gameplay_cases_by_pool(pool_tag: String, content_kind: String = "") -> Array[String]:
	var result: Array[String] = []
	var case_table := _ontology_table("cases_v2")
	for case_id_value: Variant in case_table:
		var case_id := WorkdayContext.stringify_value(case_id_value)
		var case_data := WorkdayContext.read_dictionary(case_table, case_id)
		var tags := WorkdayContext.read_array(case_data, "pool_tags")
		if tags.has(pool_tag) and (content_kind.is_empty() or WorkdayContext.read_string(case_data, "content_kind", "general") == content_kind):
			result.append(case_id)
	result.sort()
	return result


# 按 ID 获取故事线配置。
func get_storyline(storyline_id: String) -> Dictionary:
	return get_ontology("storylines", storyline_id)


# 返回内容包规模摘要，供测试和开发控制台显示。
func get_content_summary() -> Dictionary:
	var general_count := 0
	var story_count := 0
	for case_value: Variant in _ontology_table("cases_v2").values():
		if not case_value is Dictionary:
			continue
		@warning_ignore("unsafe_cast")
		var case_data: Dictionary = case_value
		if WorkdayContext.read_string(case_data, "content_kind", "general") == "story":
			story_count += 1
		else:
			general_count += 1
	return {
		"content_pack_id": WorkdayContext.read_string(content_pack, "id"),
		"people": _ontology_table("people").size(),
		"cases": _ontology_table("cases_v2").size(),
		"general_cases": general_count,
		"story_cases": story_count,
		"workdays": _ontology_table("workdays").size(),
		"storylines": _ontology_table("storylines").size(),
	}


# 按 ID 获取游戏玩法案件，合并人物、目的与主材料信息。
func get_gameplay_case(case_id: String) -> Dictionary:
	var result := get_ontology("cases_v2", case_id)
	if result.is_empty():
		return result
	var person := get_ontology("people", WorkdayContext.read_string(result, "person_id"))
	var purpose := get_ontology("purposes", WorkdayContext.read_string(result, "purpose_id"))
	result.person = person
	result.purpose = purpose
	result.character_id = WorkdayContext.read_string(result, "person_id")
	result.applicant = (
		"%s，公民序号 %s"
		% [
			WorkdayContext.read_string(person, "display_name", "身份受限"),
			WorkdayContext.read_string(person, "citizen_id", "未登记"),
		]
	)
	result.department = WorkdayContext.read_string(purpose, "department", "未标明部门")
	result.code = WorkdayContext.read_string(result, "form_code", "未编号事项")
	var primary := _find_primary_document(WorkdayContext.read_array(result, "documents"))
	var primary_fields := WorkdayContext.read_dictionary(primary, "fields")
	result.request = WorkdayContext.read_string(primary_fields, "request", WorkdayContext.read_string(purpose, "name", "事项内容受限"))
	result.checks = ["核验必需材料", "对照字段与适用规定", "作出审批决定"]
	result.case_id = case_id
	return result


# 使用规则评估器判断案件是否应批准或驳回。
func evaluate_gameplay_case(case_data: Dictionary) -> Dictionary:
	return RULE_EVALUATOR.evaluate(case_data, _ontology_table("rules"))


# 在案件材料中查找主材料；若不存在则返回第一份材料。
func _find_primary_document(documents: Array) -> Dictionary:
	var first: Dictionary = {}
	for document_value: Variant in documents:
		if not document_value is Dictionary:
			continue
		@warning_ignore("unsafe_cast")
		var document: Dictionary = document_value
		if first.is_empty():
			first = document
		var type_data := get_ontology("document_types", WorkdayContext.read_string(document, "document_type_id"))
		if WorkdayContext.read_bool(type_data, "is_primary"):
			return document
	return first


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


# 返回指定本体表的强类型字典。
func _ontology_table(table_name: String) -> Dictionary:
	return WorkdayContext.read_dictionary(ontology, table_name)


# 从动态字段读取字典列表。
func _read_dictionaries(source: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in WorkdayContext.read_array(source, key):
		if value is Dictionary:
			@warning_ignore("unsafe_cast")
			var entry: Dictionary = value
			result.append(entry)
	return result


# 按工作日序号升序排列配置。
func _sort_workdays(left: Dictionary, right: Dictionary) -> bool:
	return WorkdayContext.read_int(left, "day_number") < WorkdayContext.read_int(right, "day_number")
