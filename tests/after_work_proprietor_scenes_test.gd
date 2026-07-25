extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.player_name = "测试职员"
	state.balance = 20
	state.manager.begin_evening()

	await _assert_scene(
		"res://scenes/central_forms_scene.tscn",
		"CentralFormsScene",
		"袁科员",
	)
	await _assert_scene(
		"res://scenes/ration_depot_scene.tscn",
		"RationDepotScene",
		"马姐",
	)
	var ration = current_scene
	var old_balance: int = state.balance
	ration._handle_action("buy_form")
	assert(state.balance < old_balance, "ration proprietor action must charge the configured form fee")
	assert(
		state.manager.get_personal_form_count("PERSONAL-FORM-WATER-R01", "blank") == 1,
		"ration proprietor must deliver one blank water form",
	)
	assert(ration.proprietor.texture == ration.proprietor_textures.success, "successful purchase must use success state")

	await _assert_scene(
		"res://scenes/home_12c_scene.tscn",
		"Home12CScene",
		"秦叔",
	)
	assert(current_scene.left_actions.get_child_count() == 2, "home scene must expose two left actions")
	assert(current_scene.right_actions.get_child_count() == 2, "home scene must expose two right actions")
	print("FORMOCRACY_AFTER_WORK_PROPRIETOR_SCENES_TEST_OK")
	quit(0)


func _assert_scene(path: String, expected_name: String, expected_proprietor: String) -> void:
	var error := change_scene_to_file(path)
	assert(error == OK, "%s must load" % path)
	await process_frame
	await process_frame
	var scene = current_scene
	assert(scene != null and scene.name == expected_name, "%s must be current" % expected_name)
	assert(scene.proprietor_name == expected_proprietor, "scene must configure proprietor identity")
	assert(scene.shade.visible, "proprietor focus mode must dim the background")
	assert(scene.proprietor.texture != null, "proprietor focus mode must show a character state")
	assert(scene.left_actions.get_child_count() > 0, "scene must expose left-side actions")
	assert(scene.right_actions.get_child_count() > 0, "scene must expose right-side actions")
	assert(scene.dialogue_box.visible, "scene must open with proprietor dialogue")

