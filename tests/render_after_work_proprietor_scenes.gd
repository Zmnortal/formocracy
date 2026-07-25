extends SceneTree

const SCENES := [
	{
		"path": "res://scenes/central_forms_scene.tscn",
		"output": "res://output/after-work-proprietors/runtime-central-forms.png",
	},
	{
		"path": "res://scenes/ration_depot_scene.tscn",
		"output": "res://output/after-work-proprietors/runtime-ration-depot.png",
	},
	{
		"path": "res://scenes/home_12c_scene.tscn",
		"output": "res://output/after-work-proprietors/runtime-home-12c.png",
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
	print("FORMOCRACY_AFTER_WORK_PROPRIETOR_RENDER_OK")
	quit(0)

