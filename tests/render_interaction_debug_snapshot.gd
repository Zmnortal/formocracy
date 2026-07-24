extends SceneTree

const SNAPSHOT_PATH := "/tmp/formocracy-interaction-debug.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	var error := change_scene_to_file("res://main.tscn")
	assert(error == OK, "gameplay scene must load")
	await process_frame
	await process_frame
	var console = root.get_node("DeveloperConsole")
	if not console.interaction_overlay.visible:
		console.toggle_collision_debug()
	await process_frame
	await create_timer(0.2).timeout
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "debug viewport must produce an image")
	assert(image.save_png(SNAPSHOT_PATH) == OK, "interaction debug snapshot must save")
	print("FORMOCRACY_INTERACTION_DEBUG_RENDER_OK %s" % SNAPSHOT_PATH)
	quit(0)
