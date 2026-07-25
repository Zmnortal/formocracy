extends SceneTree

# 文件袋三态渲染快照：桌面侧平躺、查验层封闭、查验层拆封。

const DESK_OUTPUT := "/tmp/formocracy-envelope-desk-side.png"
const CLOSED_OUTPUT := "/tmp/formocracy-envelope-billboard-closed.png"
const OPEN_OUTPUT := "/tmp/formocracy-envelope-billboard-open.png"
const REPACK_PREVIEW_OUTPUT := "/tmp/formocracy-envelope-repack-preview.png"
const REPACKED_STACK_OUTPUT := "/tmp/formocracy-envelope-repacked-stack.png"
const DOCUMENT_EXTRACTED_OUTPUT := "/tmp/formocracy-document-extracted-state.png"
const DOCUMENT_DESK_OUTPUT := "/tmp/formocracy-document-desk-state.png"
const DOCUMENT_RAISED_OUTPUT := "/tmp/formocracy-document-raised-state.png"


func _init() -> void:
	call_deferred("run")


# 进入主工作台并逐一截取文件袋的三种实际游戏状态。
func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	assert(change_scene_to_file("res://main.tscn") == OK)
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_ENVELOPE_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return

	current_scene.manager.start_first_case_for_tests()
	await create_timer(0.2).timeout
	current_scene.manager.npc_performance.skip_current_performance()
	await create_timer(0.5).timeout
	var presenter = current_scene.manager.presenter
	presenter.set_envelope_on_desk(true)
	await process_frame
	_save_snapshot(DESK_OUTPUT)

	presenter.expand_envelope_billboard()
	await create_timer(0.3).timeout
	_save_snapshot(CLOSED_OUTPUT)

	presenter.open_envelope()
	await create_timer(0.3).timeout
	_save_snapshot(OPEN_OUTPUT)
	presenter._set_repack_preview(true)
	await process_frame
	_save_snapshot(REPACK_PREVIEW_OUTPUT)
	presenter._set_repack_preview(false)

	presenter.open_document(presenter.primary_document_id)
	await create_timer(0.3).timeout
	_save_snapshot(DOCUMENT_EXTRACTED_OUTPUT)
	presenter.form.position = Vector2(320, 350)
	presenter.place_document_on_desk(presenter.primary_document_id)
	presenter.collapse_envelope_billboard()
	await create_timer(0.3).timeout
	_save_snapshot(DOCUMENT_DESK_OUTPUT)
	presenter.open_document(presenter.primary_document_id)
	await create_timer(0.25).timeout
	_save_snapshot(DOCUMENT_RAISED_OUTPUT)
	presenter.expand_envelope_billboard()
	await create_timer(0.3).timeout
	presenter.pack_all_documents()
	await create_timer(0.2).timeout
	_save_snapshot(REPACKED_STACK_OUTPUT)
	print(
		(
			"FORMOCRACY_ENVELOPE_SNAPSHOT_OK %s %s %s %s %s %s %s %s"
			% [
				DESK_OUTPUT,
				CLOSED_OUTPUT,
				OPEN_OUTPUT,
				REPACK_PREVIEW_OUTPUT,
				REPACKED_STACK_OUTPUT,
				DOCUMENT_EXTRACTED_OUTPUT,
				DOCUMENT_DESK_OUTPUT,
				DOCUMENT_RAISED_OUTPUT,
			]
		)
	)
	quit(0)


# 保存当前视口，供实际画面比例检查。
func _save_snapshot(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(path) == OK)
