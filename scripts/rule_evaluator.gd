class_name RuleEvaluator
extends RefCounted


static func evaluate(case_data: Dictionary, rules_by_id: Dictionary) -> Dictionary:
	var violations: Array[String] = []
	var documents := _documents_by_id(case_data.get("documents", []))
	for rule_id in case_data.get("rule_ids", []):
		var rule: Dictionary = rules_by_id.get(String(rule_id), {})
		if rule.is_empty():
			continue
		var failed := false
		match String(rule.get("kind", "")):
			"required_documents":
				var present_types := {}
				for document in documents.values():
					present_types[String(document.get("document_type_id", ""))] = true
				for type_id in case_data.get("required_document_type_ids", []):
					if not present_types.has(String(type_id)):
						failed = true
			"fields_equal":
				failed = _resolve_field(documents, String(rule.get("left", ""))) != _resolve_field(documents, String(rule.get("right", "")))
			"field_equals":
				failed = _resolve_field(documents, String(rule.get("field", ""))) != rule.get("value")
		if failed:
			violations.append(String(rule.get("violation_id", "")))
	return {
		"decision": "批准" if violations.is_empty() else "驳回",
		"violation_ids": violations,
		"rules_checked": case_data.get("rule_ids", []).size(),
	}


static func _documents_by_id(raw_documents: Array) -> Dictionary:
	var result := {}
	for document in raw_documents:
		result[String(document.get("id", ""))] = document
	return result


static func _resolve_field(documents: Dictionary, path: String) -> Variant:
	var separator := path.find(".")
	if separator < 0:
		return null
	var document_id := path.left(separator)
	var field_name := path.substr(separator + 1)
	var document: Dictionary = documents.get(document_id, {})
	if document.is_empty():
		for candidate in documents.values():
			if String(candidate.get("document_type_id", "")) == document_id:
				document = candidate
				break
	return document.get("fields", {}).get(field_name)
