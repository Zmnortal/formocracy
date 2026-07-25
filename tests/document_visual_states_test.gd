extends SceneTree

# 验证首批三种正式文档使用独立袋内、桌面与查验素材，并在切换时保持数据和印章。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var person := {
		"display_name": "林默",
		"citizen_id": "74-119-02",
		"portrait_texture": "res://assets/characters/portraits_8bit/person_lin.png",
		"standard_portrait_texture": "res://assets/characters/portraits_standard/person_lin.png",
	}
	var database := root.get_node("ConfigDatabase")
	var cases := [
		{
			"type_id": "DOCTYPE-APPLICATION",
			"folder": "application",
			"portrait": false,
			"portrait_mode": "vertical",
		},
		{
			"type_id": "DOCTYPE-IDENTITY",
			"folder": "identity",
			"portrait": true,
			"portrait_mode": "horizontal",
		},
		{
			"type_id": "DOCTYPE-RESIDENCE",
			"folder": "residence",
			"portrait": false,
			"portrait_mode": "vertical",
		},
	]
	for fixture: Dictionary in cases:
		var type_id := WorkdayContext.read_string(fixture, "type_id")
		var folder := WorkdayContext.read_string(fixture, "folder")
		var type_data: Dictionary = database.get_ontology("document_types", type_id)
		var view := DocumentView.new()
		(
			view
			. configure(
				{
					"id": "TEST-%s" % folder.to_upper(),
					"document_type_id": type_id,
					"title": "状态测试文件",
					"fields":
					{
						"name": "林默",
						"citizen_id": "74-119-02",
						"address": "第十二区 17-4",
						"valid": true,
					},
				},
				type_data,
				person,
				"TEST-12"
			)
		)
		root.add_child(view)

		var pocket_path := "res://assets/documents/types/%s/pocket.png" % folder
		var desk_path := "res://assets/documents/types/%s/desk.png" % folder
		var inspection_path := "res://assets/documents/types/%s/inspection.png" % folder
		assert(view.visual_texture(DocumentView.VISUAL_POCKET).resource_path == pocket_path, "%s must have an independent pocket asset" % type_id)
		assert(view.visual_texture(DocumentView.VISUAL_DESK).resource_path == desk_path, "%s must have an independent desk asset" % type_id)
		assert(view.visual_texture(DocumentView.VISUAL_INSPECTION).resource_path == inspection_path, "%s must have an independent inspection asset" % type_id)
		assert(view.visual_size(DocumentView.VISUAL_POCKET) != view.visual_size(DocumentView.VISUAL_DESK), "pocket and desk geometry must differ")
		assert(view.visual_size(DocumentView.VISUAL_DESK) != view.visual_size(DocumentView.VISUAL_INSPECTION), "desk and inspection geometry must differ")
		if WorkdayContext.read_string(fixture, "portrait_mode") == "horizontal":
			assert(view.inspection_size.x > view.inspection_size.y, "identity card inspection state must remain horizontal")
		else:
			assert(view.inspection_size.y > view.inspection_size.x, "%s inspection state must remain vertical" % type_id)

		assert(view.visual_state == DocumentView.VISUAL_INSPECTION, "documents must begin with the readable inspection visual prepared")
		assert(view.background.texture.resource_path == inspection_path, "inspection texture must be active after configuration")
		assert(view.content_layer.visible, "dynamic fields must be visible in inspection state")
		assert(not view.content_layer.has_node("ReadablePaper"), "native three-state materials must keep their own inspection artwork visible")
		assert(not view.content_layer.has_node("DocumentChrome"), "native inspection artwork must not be covered by a second generic visual language")
		assert(not view.content_layer.find_children("DocumentField_*", "Label", true, false).is_empty(), "native inspection artwork must receive prefilled document fields")
		var title := view.content_layer.get_node("DocumentTitle") as Label
		assert(title.get_theme_font_size("font_size") >= 20, "native document titles must remain legible without overpowering the source artwork")
		for descendant: Node in view.content_layer.find_children("*", "Label", true, false):
			if descendant.get_meta("document_font_role", "") == "field_value":
				var field_value := descendant as Label
				assert(field_value.get_theme_font_size("font_size") >= 24, "field values must remain legible after workbench scaling")
		assert(view.content_layer.has_node("DocumentPortrait") == WorkdayContext.read_bool(fixture, "portrait"), "only configured card types may render a portrait")
		if type_id == "DOCTYPE-IDENTITY":
			var portrait := view.content_layer.get_node("DocumentPortrait") as TextureRect
			assert(portrait.texture.resource_path == person.standard_portrait_texture, "identity proof must prefer the standardized full-body head crop")
			assert(portrait.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "standard identity portraits must use smooth texture sampling")
		if type_id == "DOCTYPE-APPLICATION":
			assert(view.content_layer.get_child_count() >= 10, "the primary form must include prefilled filing metadata in addition to case fields")
		view.add_stamp("批准", view.inspection_size * 0.75)
		assert(view.stamp_records.size() == 1, "stamp data must be recorded before a visual transition")

		view.apply_visual_state(DocumentView.VISUAL_DESK)
		assert(view.visual_state == DocumentView.VISUAL_DESK, "desk transition must update the semantic visual state")
		assert(view.background.texture.resource_path == desk_path, "desk transition must use the flat-paper asset")
		assert(not view.content_layer.visible, "tiny desk state must not duplicate readable overlay text")
		assert(view.stamp_records.size() == 1 and view.stamp_layer.get_child_count() == 1, "desk transition must preserve stamp data and its visual node")

		view.apply_visual_state(DocumentView.VISUAL_INSPECTION)
		assert(view.size == view.inspection_size, "inspection transition must restore the configured readable geometry")
		assert(view.background.texture.resource_path == inspection_path, "inspection transition must restore its source asset")
		assert(view.content_layer.visible, "inspection transition must restore dynamic content")
		assert(view.stamp_records.size() == 1, "round-trip visual changes must not mutate document facts")
		view.queue_free()

	print("FORMOCRACY_DOCUMENT_VISUAL_STATES_TEST_OK")
	quit(0)
