extends SceneTree

const REQUIRED_ASSETS := [
	"res://assets/life/interiors/central_forms_department.png",
	"res://assets/life/interiors/ration_depot.png",
	"res://assets/life/interiors/home_12c.png",
	"res://assets/life/newspaper_kiosk/interior.png",
	"res://assets/life/newspaper_kiosk/acceptance_machine.png",
	"res://assets/life/application_office/intake_machine.png",
	"res://assets/shop/background/form_shop_interior.png",
	"res://assets/shop/characters/zhou_proprietor.png",
	"res://assets/shop/items/form_transaction_tray.png",
]

const PROPRIETOR_SCENES := [
	"res://scenes/central_forms_scene.tscn",
	"res://scenes/ration_depot_scene.tscn",
	"res://scenes/home_12c_scene.tscn",
]


func _init() -> void:
	call_deferred("run")


func run() -> void:
	for asset_path in REQUIRED_ASSETS:
		assert(FileAccess.file_exists(asset_path), "missing production life asset: %s" % asset_path)

	for script_path in [
		"res://scripts/scenes/central_forms_scene.gd",
		"res://scripts/scenes/ration_depot_scene.gd",
		"res://scripts/scenes/home_12c_scene.gd",
	]:
		var script_text := FileAccess.get_file_as_string(script_path)
		assert(
			not script_text.contains("assets/concepts/after_work_interiors"),
			"life scenes must not load concept-path placeholders: %s" % script_path,
		)

	var map_text := FileAccess.get_file_as_string("res://scenes/evening_map.tscn")
	assert(not map_text.contains("name=\"Clinic\""), "unused clinic placeholder must be removed")
	assert(not map_text.contains("name=\"Transit\""), "unused transit placeholder must be removed")
	assert(not map_text.contains("locked_stamp.png"), "placeholder lock stamp must not remain in the map")

	var state := root.get_node("WorkdayState")
	state.reset_for_tests()
	state.manager.begin_evening()
	for scene_path in PROPRIETOR_SCENES:
		assert(change_scene_to_file(scene_path) == OK)
		await process_frame
		await process_frame
		var location_background := current_scene.find_child("LocationBackground", true, false) as TextureRect
		assert(location_background != null and location_background.texture != null)
		assert(
			location_background.texture.resource_path.begins_with("res://assets/life/interiors/"),
			"proprietor scene must use a production interior: %s" % scene_path,
		)

	assert(change_scene_to_file("res://scenes/newspaper_kiosk.tscn") == OK)
	await process_frame
	await process_frame
	var kiosk_machine := current_scene.find_child("AcceptanceMachineAsset", true, false) as Sprite2D
	assert(kiosk_machine != null and kiosk_machine.texture != null, "newspaper kiosk needs a real machine asset")

	assert(change_scene_to_file("res://scenes/application_office.tscn") == OK)
	await process_frame
	await process_frame
	var intake_machine := current_scene.find_child("IntakeMachineAsset", true, false) as Sprite2D
	assert(intake_machine != null and intake_machine.texture != null, "application office needs a real intake machine asset")

	print("FORMOCRACY_LIFE_ASSETS_NO_PLACEHOLDER_TEST_OK")
	quit(0)
