extends SceneTree

const CAPTURES := [
	{
		"scene": "res://scenes/application_office.tscn",
		"output": "res://output/life-assets/runtime-application-office.png",
	},
	{
		"scene": "res://scenes/newspaper_kiosk.tscn",
		"output": "res://output/life-assets/runtime-newspaper-kiosk.png",
	},
]


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState")
	state.reset_for_tests()
	state.player_name = "测试职员"
	state.balance = 42
	state.manager.begin_evening()
	assert(state.manager.purchase_personal_form("PERSONAL-FORM-LOST-PROPERTY-C01"))
	assert(state.manager.purchase_personal_form("PERSONAL-FORM-NEWSPAPER-S01"))
	for capture in CAPTURES:
		assert(change_scene_to_file(String(capture.scene)) == OK)
		await process_frame
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		if DisplayServer.get_name() != "headless":
			var image := root.get_viewport().get_texture().get_image()
			assert(image.save_png(String(capture.output)) == OK)
	print("FORMOCRACY_LIFE_ASSETS_RENDER_OK")
	quit(0)
