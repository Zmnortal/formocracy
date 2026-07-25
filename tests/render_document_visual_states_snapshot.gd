extends SceneTree

const POCKET_OUTPUT := "user://document-visual-pocket.png"
const APPLICATION_OUTPUT := "user://document-visual-application-prefill.png"
const MIXED_OUTPUT := "user://document-visual-states.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState")
	state.reset_for_tests()
	var packed: PackedScene = load("res://main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	main.manager.start_first_case_for_tests()
	await process_frame

	var presenter: Variant = main.manager.presenter
	main.manager.dialogue_box.visible = false
	presenter.set_envelope_on_desk(true)
	presenter.open_envelope()
	await create_timer(0.3).timeout
	main.manager.npc_performance.speech_bubble.close()
	await _capture(POCKET_OUTPUT)

	var application: Variant = presenter.form
	var identity: Variant = presenter.document_panels[0]
	presenter.open_document(application.document_id)
	await create_timer(0.32).timeout
	main.manager.npc_performance.speech_bubble.close()
	await _capture(APPLICATION_OUTPUT)
	presenter.place_document_on_desk(application.document_id)
	application.position = Vector2(300, 545)
	application.scale = presenter.DOCUMENT_DESK_SCALE
	application.pivot_offset = Vector2.ZERO
	presenter.open_document(identity.document_id)
	await create_timer(0.32).timeout
	presenter.bring_document_to_front(identity.document_id)
	await process_frame
	await process_frame
	main.manager.npc_performance.speech_bubble.close()

	await _capture(MIXED_OUTPUT)
	print("FORMOCRACY_DOCUMENT_VISUAL_POCKET_SNAPSHOT=%s" % ProjectSettings.globalize_path(POCKET_OUTPUT))
	print("FORMOCRACY_DOCUMENT_VISUAL_APPLICATION_SNAPSHOT=%s" % ProjectSettings.globalize_path(APPLICATION_OUTPUT))
	print("FORMOCRACY_DOCUMENT_VISUAL_STATES_SNAPSHOT=%s" % ProjectSettings.globalize_path(MIXED_OUTPUT))
	quit(0)


func _capture(output_path: String) -> void:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	assert(image.save_png(output_path) == OK)
