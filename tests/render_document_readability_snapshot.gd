extends SceneTree

# 在同一张实际 Godot 画面中检查竖版申请表、横版身份证明与竖版居住证明。

const OUTPUT_PATH := "/tmp/formocracy-document-readability.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_DOCUMENT_READABILITY_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return

	var backdrop := ColorRect.new()
	backdrop.color = Color("171b1a")
	backdrop.size = Vector2(1280, 720)
	root.add_child(backdrop)

	var database := root.get_node("ConfigDatabase")
	var person := {
		"display_name": "林默",
		"citizen_id": "74-119-02",
		"portrait_texture": "res://assets/characters/portraits_8bit/person_lin.png",
		"standard_portrait_texture": "res://assets/characters/portraits_standard/person_lin.png",
	}
	var fixtures := [
		{"type_id": "DOCTYPE-APPLICATION", "position": Vector2(34, 40), "scale": Vector2(0.42, 0.42)},
		{"type_id": "DOCTYPE-IDENTITY", "position": Vector2(352, 40), "scale": Vector2(0.46, 0.46)},
		{"type_id": "DOCTYPE-RESIDENCE", "position": Vector2(820, 40), "scale": Vector2(0.42, 0.42)},
	]
	for fixture: Dictionary in fixtures:
		var type_id := WorkdayContext.read_string(fixture, "type_id")
		var type_data: Dictionary = database.get_ontology("document_types", type_id)
		var fields: Dictionary = {}
		for raw_key: Variant in WorkdayContext.read_dictionary(type_data, "fields"):
			var key := WorkdayContext.stringify_value(raw_key)
			fields[key] = _sample_value(key)
		var view := DocumentView.new()
		(
			view
			. configure(
				{
					"id": "READABILITY-%s" % type_id,
					"document_type_id": type_id,
					"title": WorkdayContext.read_string(type_data, "name"),
					"fields": fields,
				},
				type_data,
				person,
				"R-12/READABILITY"
			)
		)
		view.position = fixture["position"]
		view.scale = fixture["scale"]
		backdrop.add_child(view)

	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "readability snapshot must render")
	assert(image.save_png(OUTPUT_PATH) == OK, "readability snapshot must save")
	print("FORMOCRACY_DOCUMENT_READABILITY_SNAPSHOT_OK %s" % OUTPUT_PATH)
	quit(0)


func _sample_value(key: String) -> Variant:
	var result: Variant = "第十二区登记记录"
	match key:
		"request":
			result = "申请共同居住配额变更"
		"address":
			result = "第十二区 17-4"
		"name":
			result = "林默"
		"citizen_id":
			result = "74-119-02"
		"signed", "valid", "certified", "sealed", "authorized", "paid":
			result = true
		"note":
			result = "材料需要与身份档案交叉核验"
	return result
