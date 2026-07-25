extends SceneTree

const SCENES := [
	{
		"path": "res://scenes/central_forms_scene.tscn",
		"output": "res://output/after-work-proprietors/runtime-central-forms.png",
		"hover_output": "res://output/after-work-proprietors/runtime-central-forms-paper-tags.png",
	},
	{
		"path": "res://scenes/ration_depot_scene.tscn",
		"output": "res://output/after-work-proprietors/runtime-ration-depot.png",
		"hover_output": "res://output/after-work-proprietors/runtime-ration-depot-paper-tags.png",
	},
	{
		"path": "res://scenes/home_12c_scene.tscn",
		"output": "res://output/after-work-proprietors/runtime-home-12c.png",
		"hover_output": "res://output/after-work-proprietors/runtime-home-12c-paper-tags.png",
	},
]


func _init() -> void:
	call_deferred("run")


func run() -> void:
	root.get_node("WorkdayState").reset_for_tests()
	for entry in SCENES:
		var error := change_scene_to_file(String(entry.path))
		assert(error == OK)
		await process_frame
		await process_frame
		await process_frame
		if DisplayServer.get_name() == "headless":
			continue
		var image := root.get_viewport().get_texture().get_image()
		assert(image.save_png(String(entry.output)) == OK)
		var scene = current_scene
		scene._animate_button(scene.left_actions.get_child(0).get_node("ActionButton"), true)
		scene._animate_button(scene.right_actions.get_child(0).get_node("ActionButton"), true)
		await create_timer(0.2).timeout
		image = root.get_viewport().get_texture().get_image()
		assert(image.save_png(String(entry.hover_output)) == OK)
	print("FORMOCRACY_AFTER_WORK_PROPRIETOR_RENDER_OK")
	quit(0)
