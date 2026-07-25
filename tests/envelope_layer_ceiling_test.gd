extends SceneTree

# 文件袋层级回归测试：封皮及全部袋内内容必须作为一个原子层，
# 即使文件袋父节点被抓到 999，也绝对不能触及或超过 999。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	@warning_ignore_start("unsafe_property_access")
	var state := root.get_node("WorkdayState") as WorkdayContext
	state.call("reset_for_tests")
	var packed := load("res://main.tscn") as PackedScene
	var desk := packed.instantiate() as Node2D
	root.add_child(desk)
	await process_frame
	var manager: Variant = desk.get("manager")
	manager.start_first_case_for_tests()
	await process_frame
	var presenter: Variant = manager.presenter

	presenter.envelope.z_index = DeskItemController.HELD_LAYER
	assert(presenter.envelope.z_index == 999, "the grabbed envelope parent must retain the normal held layer")
	for child_node: Node in presenter.envelope.get_children():
		if not child_node is CanvasItem:
			continue
		var child := child_node as CanvasItem
		assert(manager.desk_items._effective_z_index(child) < DeskItemController.HELD_LAYER, "envelope child %s must remain strictly below 999" % child.name)
	assert(manager.desk_items._effective_z_index(presenter.envelope_front_cover) <= 997, "the envelope cover must leave layer 998 free for the next ordinary desk item")
	for thumbnail_value: Variant in presenter.thumbnail_by_id.values():
		var thumbnail := thumbnail_value as Button
		assert(thumbnail.z_index == 0, "pocket previews must use scene order instead of adding their slot to Z-index")
		assert(manager.desk_items._effective_z_index(thumbnail) < DeskItemController.HELD_LAYER, "nested pocket previews must also remain strictly below 999")

	# 透明封皮拖拽区即使先收到 Godot GUI 事件，也必须把按下交给真正位于
	# 最前面的桌面物件，不能因为场景树创建顺序而抢走表单交互。
	var front_document := presenter.form as DocumentView
	front_document.visible = true
	front_document.set_meta("document_state", "INSPECTION")
	presenter.envelope.position = presenter.ENVELOPE_BILLBOARD_POSITION
	presenter.envelope.size = presenter.ENVELOPE_BILLBOARD_SIZE
	presenter.envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presenter.envelope_drag_handle.position = Vector2(48, 278)
	presenter.envelope_drag_handle.size = Vector2(405, 310)
	presenter.envelope_drag_handle.visible = true
	assert(not presenter.envelope_drag_handle.call("_has_point", Vector2(200, -100)), "the lower drag handle must not claim the upper flap outside its own rectangle")
	front_document.position = presenter.envelope.position + presenter.envelope_drag_handle.position + Vector2(20, 20)
	manager.desk_items.focus_item(front_document)
	var overlap_point: Vector2 = front_document.get_global_transform() * Vector2(10, 10)
	var cover_press := InputEventMouseButton.new()
	cover_press.button_index = MOUSE_BUTTON_LEFT
	cover_press.pressed = true
	cover_press.global_position = overlap_point
	manager.input._on_envelope_drag_handle_input(cover_press, presenter)
	assert(manager.desk_items.active_item == front_document, "the transparent envelope cover must forward the press to the frontmost document")
	front_document.set_meta("desk_pressed", false)
	manager.desk_items.active_item = null

	print("FORMOCRACY_ENVELOPE_LAYER_CEILING_TEST_OK")
	quit()
