extends SceneTree

# 捕捉人物向左退场、正在进入墙柱遮挡区的中间帧。

const OUTPUT_PATH := "/tmp/formocracy-npc-exit-occlusion.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	@warning_ignore_start("unsafe_property_access")
	var state := root.get_node("WorkdayState") as WorkdayContext
	state.call("reset_for_tests")
	assert(change_scene_to_file("res://main.tscn") == OK)
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_NPC_EXIT_OCCLUSION_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return

	current_scene.manager.start_first_case_for_tests()
	await process_frame
	var performance: Variant = current_scene.manager.npc_performance
	performance.skip_current_performance()
	performance.promote_after_departure = false
	performance.performance_token += 1
	var token: int = performance.performance_token
	performance._walk_current_actor_out("walk_out_angry", token)
	await create_timer(0.55).timeout

	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(OUTPUT_PATH) == OK)
	@warning_ignore_restore("unsafe_property_access")
	@warning_ignore_restore("unsafe_method_access")
	print("FORMOCRACY_NPC_EXIT_OCCLUSION_SNAPSHOT_OK %s" % OUTPUT_PATH)
	quit(0)
