extends SceneTree

# 渲染快照测试。
# 进入主工作台场景、拆封文件袋并保存视口截图，用于人工或自动验证画面。

const SNAPSHOT_PATH := "/tmp/formocracy-core-gameplay.png"
const INGESTION_SNAPSHOT_PATH := "/tmp/formocracy-machine-ingestion.png"
const NPC_SNAPSHOT_PATH := "/tmp/formocracy-npc-performance.png"
const BRIEFING_SNAPSHOT_PATH := "/tmp/formocracy-daily-briefing.png"


func _init() -> void:
	call_deferred("run")


# 运行渲染快照测试流程。
func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	var error := change_scene_to_file("res://main.tscn")
	assert(error == OK, "main scene must open for render verification")
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_RENDER_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return
	# 晨间广播会先压低大厅环境声；等待真正出现秘书台词再截屏，
	# 避免把尚未开始播报的空工作台误当成简报快照。
	for _frame in 180:
		var box: DialogueBox = current_scene.manager.dialogue_box
		if box.visible and (box.dialogue_label.visible_characters == -1 or box.dialogue_label.visible_characters >= 12):
			break
		await process_frame
	assert(current_scene.manager.dialogue_box.visible, "daily briefing dialogue must appear before its snapshot")
	assert(current_scene.manager.dialogue_box.speaker_label.text == "秘书", "daily briefing snapshot must visibly identify the secretary")
	var briefing_image := root.get_viewport().get_texture().get_image()
	assert(not briefing_image.is_empty(), "daily briefing must produce a rendered frame")
	assert(briefing_image.save_png(BRIEFING_SNAPSHOT_PATH) == OK, "daily briefing screenshot must be saved")
	current_scene.manager.start_first_case_for_tests()
	await process_frame
	await create_timer(0.9).timeout
	var npc_image := root.get_viewport().get_texture().get_image()
	assert(not npc_image.is_empty(), "NPC entrance must produce a rendered frame")
	assert(npc_image.save_png(NPC_SNAPSHOT_PATH) == OK, "NPC performance screenshot must be saved")
	current_scene.manager.npc_performance.skip_current_performance()
	await create_timer(0.4).timeout
	current_scene.manager.presenter.set_envelope_on_desk(true)
	current_scene.manager.presenter.open_envelope()
	current_scene.manager.presenter.open_document(current_scene.manager.presenter.primary_document_id)
	if not current_scene.manager.presenter.document_panels.is_empty():
		var supporting = current_scene.manager.presenter.document_panels[0]
		current_scene.manager.presenter.open_document(String(supporting.get_meta("document_id")))
		current_scene.manager.presenter.apply_stamp("驳回", String(supporting.get_meta("document_id")), Vector2(310, 238))
	current_scene.manager.presenter.apply_stamp("批准", Vector2(430, 350))
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "rendered viewport must produce an image")
	assert(image.save_png(SNAPSHOT_PATH) == OK, "render verification screenshot must be saved")
	current_scene.manager.presenter.pack_all_documents()
	current_scene.manager.submission.submit(current_scene.manager.presenter, current_scene.manager.current_case)
	await create_timer(0.75).timeout
	var ingestion_image := root.get_viewport().get_texture().get_image()
	assert(not ingestion_image.is_empty(), "machine ingestion must produce a rendered frame")
	assert(ingestion_image.save_png(INGESTION_SNAPSHOT_PATH) == OK, "machine ingestion screenshot must be saved")
	print("FORMOCRACY_RENDER_SNAPSHOT_OK %s %s %s %s" % [BRIEFING_SNAPSHOT_PATH, NPC_SNAPSHOT_PATH, SNAPSHOT_PATH, INGESTION_SNAPSHOT_PATH])
	quit(0)
