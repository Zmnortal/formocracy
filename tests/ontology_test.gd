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
	var summary: Dictionary = database.get_content_summary()
	assert(summary.content_pack_id == "FORMOCRACY-DEMO-7D", "the configured narrative content pack must load")
	assert(summary.people == 18, "all eighteen dossier characters must use indexed stable IDs")
	for person_id in [
		"PERSON-LIN",
		"PERSON-ZHOU",
		"PERSON-XU",
		"PERSON-MENG",
		"PERSON-HE",
		"PERSON-DU",
		"PERSON-GU",
		"PERSON-SHEN",
		"PERSON-TANG",
		"PERSON-LUO",
		"PROPRIETOR-ZHOU",
		"PROPRIETOR-HE",
		"PERSON-FANG",
		"PERSON-LI",
		"PERSON-WEI",
		"PERSON-JIANG",
		"PERSON-SONG",
		"PERSON-YE",
	]:
		var person: Dictionary = database.get_ontology("people", person_id)
		assert(not person.is_empty(), "production character must resolve: %s" % person_id)
		var actor_texture := String(person.get("actor_texture", ""))
		var portrait_texture := String(person.get("portrait_texture", ""))
		assert(ResourceLoader.exists(actor_texture, "Texture2D"), "full-body texture must import for %s: %s" % [person_id, actor_texture])
		assert(ResourceLoader.exists(portrait_texture, "Texture2D"), "portrait texture must import for %s: %s" % [person_id, portrait_texture])
	assert(summary.cases == 35, "the demo must expose thirty-five configured cases")
	assert(summary.general_cases == 24 and summary.story_cases == 11, "the weekly mix must remain approximately seventy/thirty")
	assert(summary.workdays == 7 and summary.storylines == 4, "the full seven-day campaign and four storylines must load")
	assert(database.ontology.document_types.size() == 12, "document types must cover the expanded proof system")
	var valid_case: Dictionary = database.get_gameplay_case("CASE-G-D3-01")
	var invalid_case: Dictionary = database.get_gameplay_case("CASE-G-D3-02")
	assert(valid_case.person.id == "PERSON-TANG", "case must resolve its person reference")
	assert(database.evaluate_gameplay_case(valid_case).decision == "批准", "matching facts must derive approval")
	var evaluation: Dictionary = database.evaluate_gameplay_case(invalid_case)
	assert(evaluation.decision == "驳回", "a violation must derive rejection")
	assert(evaluation.violation_ids.has("VIOLATION-ADDRESS-MISMATCH"), "failed rule must expose its violation ID")
	var workday: Dictionary = database.get_workday()
	assert(workday.slots.size() == 5, "day one must configure five data-authored slots")
	assert(database.get_workday_for_day(7).id == "WORKDAY-007", "day lookup must resolve the final demo workday")
	print("FORMOCRACY_ONTOLOGY_TEST_OK")
	quit(0)
