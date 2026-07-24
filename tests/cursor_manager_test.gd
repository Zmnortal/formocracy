extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var cursor_manager := preload("res://scripts/autoload/cursor_manager.gd").new()
	root.add_child(cursor_manager)
	await process_frame

	var form := Control.new()
	root.add_child(form)
	cursor_manager.request_cursor(cursor_manager.Cursor.GRAB, form)
	assert(cursor_manager.current_cursor == cursor_manager.Cursor.GRAB)

	cursor_manager.begin_drag(form)
	cursor_manager.request_cursor(cursor_manager.Cursor.POINT, form)
	assert(cursor_manager.current_cursor == cursor_manager.Cursor.GRABBING)

	cursor_manager.set_drag_cursor(cursor_manager.Cursor.DROP_VALID)
	assert(cursor_manager.current_cursor == cursor_manager.Cursor.DROP_VALID)

	cursor_manager.end_drag()
	assert(cursor_manager.current_cursor == cursor_manager.Cursor.POINT)

	cursor_manager.release_cursor(form)
	assert(cursor_manager.current_cursor == cursor_manager.Cursor.DEFAULT)

	var button := Button.new()
	root.add_child(button)
	cursor_manager.watch(button, cursor_manager.Cursor.POINT)
	button.mouse_entered.emit()
	assert(cursor_manager.current_cursor == cursor_manager.Cursor.POINT)
	button.mouse_exited.emit()
	assert(cursor_manager.current_cursor == cursor_manager.Cursor.DEFAULT)

	cursor_manager.begin_drag(form, cursor_manager.Cursor.STAMP)
	assert(cursor_manager.current_cursor == cursor_manager.Cursor.STAMP)
	cursor_manager.reset()
	assert(cursor_manager.current_cursor == cursor_manager.Cursor.DEFAULT)

	form.queue_free()
	button.queue_free()
	cursor_manager.queue_free()
	print("FORMOCRACY_CURSOR_MANAGER_TEST_OK")
	quit()
