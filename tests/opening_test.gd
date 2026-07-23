extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var opening = load("res://scenes/opening.tscn").instantiate()
	root.add_child(opening)
	await process_frame
	await create_timer(0.55).timeout
	assert(opening.slide_index == 0, "opening must begin on the first slide")
	assert(opening.slide_texture.texture != null, "opening must display a texture")
	assert(not opening.start_panel.visible, "start action must remain hidden before the final slide")
	var start_button := opening.start_panel.get_node("StartDayButton") as Button
	assert(start_button.get_theme_font("font").resource_path.contains("ark-pixel"), "opening UI must use Ark Pixel explicitly")
	opening.show_slide(2, false)
	await create_timer(0.55).timeout
	assert(opening.slide_index == 2, "opening must support jumping to the final slide")
	assert(opening.start_panel.visible, "final slide must show the start-day action")
	assert(opening.auto_timer.is_stopped(), "final slide must not auto-advance")
	print("FORMOCRACY_OPENING_TEST_OK")
	quit(0)
