extends SceneTree

# 验证材料选中框、限定区域滚轮缩放、中心锚点与原生材料字号。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState") as WorkdayContext
	state.call("reset_for_tests")
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	var controller := DeskItemController.new(scene_root)
	var type_data: Dictionary = root.get_node("ConfigDatabase").get_ontology("document_types", "DOCTYPE-IDENTITY")
	var document := DocumentView.new()
	document.configure(
		{
			"id": "TEST-ZOOM-IDENTITY",
			"document_type_id": "DOCTYPE-IDENTITY",
			"title": "本市身份证明",
			"fields": {"name": "林默", "citizen_id": "74-119-02", "address": "第十二区 17-4", "valid": true},
		},
		type_data,
		{"display_name": "林默", "citizen_id": "74-119-02"},
		"R-12/ZOOM"
	)
	document.position = Vector2(280, 120)
	document.scale = Vector2(0.36, 0.36)
	scene_root.add_child(document)
	controller.register_item(document, "document_zoom_test")

	var title := document.content_layer.get_node("DocumentTitle") as Label
	assert(title.get_theme_font_size("font_size") == DocumentView.NATIVE_TITLE_FONT_SIZE, "native material title must use the enlarged font")
	for node: Node in document.content_layer.find_children("DocumentField_*", "Label", true, false):
		var field := node as Label
		assert(field.get_theme_font_size("font_size") >= DocumentView.NATIVE_FIELD_FONT_MINIMUM, "native material fields must use the enlarged minimum font")

	controller._begin_press(document, document.size * 0.5)
	controller._end_press(document)
	assert(document.selection_outline.visible, "clicking a material must show its selection border")

	var center_before := document.get_global_transform() * (document.size * 0.5)
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	wheel_up.global_position = center_before
	controller._on_item_input(wheel_up, document)
	assert(is_equal_approx(document.user_zoom, 1.1), "one upward wheel step must enlarge the selected material by ten percent")
	assert(document.scale.is_equal_approx(Vector2(0.396, 0.396)), "wheel zoom must update the material's stable desk scale")
	var center_after := document.get_global_transform() * (document.size * 0.5)
	assert(center_after.is_equal_approx(center_before), "option B must keep the material center fixed while zooming")

	var outside_wheel := InputEventMouseButton.new()
	outside_wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	outside_wheel.pressed = true
	outside_wheel.global_position = Vector2(12, 12)
	controller._on_item_input(outside_wheel, document)
	assert(is_equal_approx(document.user_zoom, 1.1), "wheel input outside the selected border must not zoom the material")

	var other_item := Control.new()
	other_item.position = Vector2(40, 40)
	other_item.size = Vector2(80, 80)
	scene_root.add_child(other_item)
	controller.register_item(other_item, "document_zoom_other_item")
	controller._begin_press(other_item, Vector2(20, 20))
	controller._end_press(other_item)
	assert(not document.selection_outline.visible, "selecting another desk item must clear the material border")

	print("FORMOCRACY_DOCUMENT_SELECTION_ZOOM_TEST_OK")
	quit(0)
