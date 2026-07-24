extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.base_salary = 20
	state.day_number = 1
	state.manager.begin_evening()
	assert(state.balance == 20, "daily settlement must reach the account before evening purchases")
	state.manager.begin_evening()
	assert(state.balance == 20, "daily settlement must not be applied twice")
	var form: Dictionary = root.get_node("ConfigDatabase").get_ontology("personal_forms", "PERSONAL-FORM-WATER-R01")
	assert(form.get("issuer_location_id") == "LOCATION-RATION", "water form must be issued by ration depot")
	assert(int(form.get("fee")) == 5, "water form fee must come from ontology")
	var error := change_scene_to_file("res://scenes/evening_map.tscn")
	assert(error == OK, "evening map must open")
	await process_frame
	await process_frame
	var map = current_scene
	map.select_location(map.LOCATION_RATION)
	await create_timer(1.1).timeout
	assert(map.ration_window.visible, "arriving at ration depot must open its catalog")
	map.purchase_water_form()
	await create_timer(0.7).timeout
	assert(state.balance == 15, "purchase must deduct configured fee")
	assert(state.manager.get_personal_form_count(map.WATER_FORM_ID, "blank") == 1, "purchase must create one blank inventory item")
	assert(map.dossier_button.text.contains("× 1"), "dossier counter must update")
	assert(map.notice_label.text.contains("购买完成"), "purchase must confirm delivery")
	state.balance = 0
	map.purchase_water_form()
	await process_frame
	assert(state.manager.get_personal_form_count(map.WATER_FORM_ID, "blank") == 1, "insufficient balance must not add inventory")
	print("FORMOCRACY_PERSONAL_FORM_PURCHASE_TEST_OK")
	quit(0)
