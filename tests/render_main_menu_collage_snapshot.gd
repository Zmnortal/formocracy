extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_MAIN_MENU_COLLAGE_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return
	var viewport_size := get_requested_size()
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	var menu := packed.instantiate()
	viewport.add_child(menu)
	await process_frame
	await process_frame
	menu.settle_collage_for_snapshot()
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	var output_path := "user://main-menu-collage-%dx%d.png" % [viewport_size.x, viewport_size.y]
	assert(image.save_png(output_path) == OK, "main menu collage snapshot must save")
	print("FORMOCRACY_MAIN_MENU_COLLAGE=%s" % ProjectSettings.globalize_path(output_path))
	print("FORMOCRACY_MAIN_MENU_COLLAGE_SNAPSHOT_OK")
	quit(0)


func get_requested_size() -> Vector2i:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--render-size="):
			continue
		var dimensions := argument.trim_prefix("--render-size=").split("x")
		if dimensions.size() == 2:
			return Vector2i(int(dimensions[0]), int(dimensions[1]))
	return Vector2i(1280, 720)
