extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	await process_frame
	var database = root.get_node("ConfigDatabase")
	assert(database.loaded, "ontology and legacy configuration must load")
	assert(database.errors.is_empty(), "ontology references must be valid")
	assert(database.ontology.people.size() == 3, "people must use indexed stable IDs")
	assert(database.ontology.document_types.size() == 5, "document types must be reusable ontology objects")
	var valid_case: Dictionary = database.get_gameplay_case("CASE-001")
	var invalid_case: Dictionary = database.get_gameplay_case("CASE-002")
	assert(valid_case.person.id == "PERSON-LIN", "case must resolve its person reference")
	assert(database.evaluate_gameplay_case(valid_case).decision == "批准", "matching facts must derive approval")
	var evaluation: Dictionary = database.evaluate_gameplay_case(invalid_case)
	assert(evaluation.decision == "驳回", "a violation must derive rejection")
	assert(evaluation.violation_ids.has("VIOLATION-ADDRESS-MISMATCH"), "failed rule must expose its violation ID")
	var workday: Dictionary = database.get_workday()
	assert(workday.case_ids.size() == 3, "workday must reference its queue by stable case IDs")
	print("FORMOCRACY_ONTOLOGY_TEST_OK")
	quit(0)
