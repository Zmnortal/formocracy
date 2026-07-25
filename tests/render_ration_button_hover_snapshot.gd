extends SceneTree

const OUTPUT := "/tmp/formocracy-ration-button-hover.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	root.get_node("WorkdayState").reset_for_tests()
	var error := change_scene_to_file("res://scenes/ration_depot_scene.tscn")
	assert(error == OK)
	await process_frame
	await process_frame
	await process_frame
	var scene = current_scene
	var hovered_button := scene.right_actions.get_child(1).get_node("ActionButton") as Button
	scene._animate_button(hovered_button, true)
	hovered_button.grab_focus()
	await create_timer(0.2).timeout
	var image := root.get_viewport().get_texture().get_image()
	assert(image.save_png(OUTPUT) == OK)
	print("FORMOCRACY_RATION_BUTTON_HOVER_RENDER_OK %s" % OUTPUT)
	quit()
