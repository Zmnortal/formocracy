extends SceneTree

const SHOP_OUTPUT := "user://form-shop-snapshot.png"
const OFFICE_OUTPUT := "user://application-office-snapshot.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.player_name = "测试职员"
	state.balance = 42
	state.begin_evening()
	state.evening_location_id = "LOCATION-FORM-SHOP"
	var error := change_scene_to_file("res://scenes/form_shop.tscn")
	assert(error == OK)
	await process_frame
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_FORM_SHOP_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return
	var shop_image := root.get_viewport().get_texture().get_image()
	assert(shop_image.save_png(SHOP_OUTPUT) == OK)
	current_scene.purchase_form("PERSONAL-FORM-LOST-PROPERTY-C01")
	error = change_scene_to_file("res://scenes/application_office.tscn")
	assert(error == OK)
	await process_frame
	await process_frame
	await process_frame
	var office_image := root.get_viewport().get_texture().get_image()
	assert(office_image.save_png(OFFICE_OUTPUT) == OK)
	print("FORMOCRACY_FORM_SHOP_SNAPSHOT=%s" % ProjectSettings.globalize_path(SHOP_OUTPUT))
	print("FORMOCRACY_APPLICATION_OFFICE_SNAPSHOT=%s" % ProjectSettings.globalize_path(OFFICE_OUTPUT))
	quit(0)
