class_name RuleEvaluator
extends RefCounted

# 规则评估器。
# 根据案件材料和规则集合判断案件是否合规：无违规返回“批准”，否则返回“驳回”并列出违规 ID。


# 评估案件。支持 required_documents、fields_equal 与 field_equals 三种规则类型。
static func evaluate(case_data: Dictionary, rules_by_id: Dictionary) -> Dictionary:
	var violations: Array[String] = []
	var rule_ids := WorkdayContext.read_array(case_data, "rule_ids")
	var documents := _documents_by_id(WorkdayContext.read_array(case_data, "documents"))
	for rule_id_value: Variant in rule_ids:
		var rule_id := WorkdayContext.stringify_value(rule_id_value)
		var rule := WorkdayContext.read_dictionary(rules_by_id, rule_id)
		if rule.is_empty():
			continue
		var failed := false
		match WorkdayContext.read_string(rule, "kind"):
			"required_documents":
				var present_types: Dictionary = {}
				for document_value: Variant in documents.values():
					if not document_value is Dictionary:
						continue
					@warning_ignore("unsafe_cast")
					var document: Dictionary = document_value
					present_types[WorkdayContext.read_string(document, "document_type_id")] = true
				for type_id_value: Variant in WorkdayContext.read_array(case_data, "required_document_type_ids"):
					var type_id := WorkdayContext.stringify_value(type_id_value)
					if not present_types.has(type_id):
						failed = true
			"fields_equal":
				failed = (_resolve_field(documents, WorkdayContext.read_string(rule, "left")) != _resolve_field(documents, WorkdayContext.read_string(rule, "right")))
			"field_equals":
				failed = (_resolve_field(documents, WorkdayContext.read_string(rule, "field")) != rule.get("value"))
		if failed:
			violations.append(WorkdayContext.read_string(rule, "violation_id"))
	return {
		"decision": "批准" if violations.is_empty() else "驳回",
		"violation_ids": violations,
		"rules_checked": rule_ids.size(),
	}


# 将材料数组按 ID 索引为字典，便于按 document_id 查找。
static func _documents_by_id(raw_documents: Array) -> Dictionary:
	var result: Dictionary = {}
	for document_value: Variant in raw_documents:
		if not document_value is Dictionary:
			continue
		@warning_ignore("unsafe_cast")
		var document: Dictionary = document_value
		var document_id := WorkdayContext.read_string(document, "id")
		if not document_id.is_empty():
			result[document_id] = document
	return result


# 解析 field_path（如 "doc_01.address"），返回对应材料字段值。
# 若按 ID 找不到材料，会尝试按 document_type_id 匹配。
static func _resolve_field(documents: Dictionary, path: String) -> Variant:
	var separator := path.find(".")
	if separator < 0:
		return null
	var document_id := path.left(separator)
	var field_name := path.substr(separator + 1)
	var document := WorkdayContext.read_dictionary(documents, document_id)
	if document.is_empty():
		for candidate_value: Variant in documents.values():
			if not candidate_value is Dictionary:
				continue
			@warning_ignore("unsafe_cast")
			var candidate: Dictionary = candidate_value
			if WorkdayContext.read_string(candidate, "document_type_id") == document_id:
				document = candidate
				break
	var fields := WorkdayContext.read_dictionary(document, "fields")
	return fields.get(field_name)
