extends SceneTree

const QUEUE_SNAPSHOT_PATH := "/tmp/formocracy-npc-staged-queue.png"
const PROMOTED_SNAPSHOT_PATH := "/tmp/formocracy-npc-promoted-front.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	var error := change_scene_to_file("res://main.tscn")
	assert(error == OK, "main scene must open for queue render verification")
	await process_frame
	await process_frame
	current_scene.manager.start_first_case_for_tests()
	await create_timer(0.25).timeout
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_NPC_QUEUE_RENDER_OK (skipped on headless display)")
		quit(0)
		return

	var queue_image := root.get_viewport().get_texture().get_image()
	assert(not queue_image.is_empty(), "staged queue must produce a rendered frame")
	assert(queue_image.save_png(QUEUE_SNAPSHOT_PATH) == OK, "staged queue screenshot must be saved")

	current_scene.manager.npc_performance.skip_current_performance()
	await create_timer(0.25).timeout
	current_scene.manager.npc_performance.skip_requested = false
	current_scene.manager.npc_performance.react_and_leave("批准")
	# 气泡约五秒后，人物还会完整走出画面并完成队列补位。
	var deadline := Time.get_ticks_msec() + 8500
	while current_scene.manager.npc_performance.state != "FRONT_STAGED" and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(current_scene.manager.npc_performance.state == "FRONT_STAGED", "first queued applicant must finish promotion")
	var promoted_image := root.get_viewport().get_texture().get_image()
	assert(not promoted_image.is_empty(), "promoted front applicant must render")
	assert(promoted_image.save_png(PROMOTED_SNAPSHOT_PATH) == OK, "promoted front screenshot must be saved")
	print("FORMOCRACY_NPC_QUEUE_RENDER_OK %s %s" % [QUEUE_SNAPSHOT_PATH, PROMOTED_SNAPSHOT_PATH])
	quit(0)
