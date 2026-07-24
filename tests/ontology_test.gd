extends SceneTree

# 本体与配置数据库测试。
# 验证 CSV 配置加载、JSON 本体索引、案件引用解析与规则评估。


func _init() -> void:
	call_deferred("run")


# 运行本体与配置完整测试流程。
func run() -> void:
	await process_frame
	var database = root.get_node("ConfigDatabase")
	assert(database.loaded, "ontology and legacy configuration must load")
	assert(database.errors.is_empty(), "ontology references must be valid")
	assert(database.ontology.people.size() == 7, "all seven production characters must use indexed stable IDs")
	for person_id in [
		"PERSON-LIN",
		"PERSON-ZHOU",
		"PERSON-XU",
		"PERSON-MENG",
		"PERSON-HE",
		"PERSON-DU",
		"PERSON-GU",
	]:
		var person: Dictionary = database.get_ontology("people", person_id)
		assert(not person.is_empty(), "production character must resolve: %s" % person_id)
		var actor_texture := String(person.get("actor_texture", ""))
		var portrait_texture := String(person.get("portrait_texture", ""))
		assert(
			ResourceLoader.exists(actor_texture, "Texture2D"),
			"full-body texture must import for %s: %s" % [person_id, actor_texture]
		)
		assert(
			ResourceLoader.exists(portrait_texture, "Texture2D"),
			"portrait texture must import for %s: %s" % [person_id, portrait_texture]
		)
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
