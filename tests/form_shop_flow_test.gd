extends SceneTree

const CLAIM_FORM := "PERSONAL-FORM-LOST-PROPERTY-C01"
const ARCHIVE_FORM := "PERSONAL-FORM-ARCHIVE-EXTRACT-A02"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.player_name = "测试职员"
	state.balance = 30
	state.manager.begin_evening()
	state.evening_location_id = "LOCATION-FORM-SHOP"

	var error := change_scene_to_file("res://scenes/form_shop.tscn")
	assert(error == OK, "form shop scene must load")
	await process_frame
	await process_frame
	var shop = current_scene
	assert(shop.dialogue_label.text.contains("测试职员"), "proprietor must address the entered player name")
	assert(shop.dialogue_box.visible, "shop greeting must use the shared bottom dialogue box")
	assert(shop.dialogue_box.z_index >= 4000, "shop dialogue must render in front of all form cards")
	assert(shop.dialogue_label.visible_characters >= 0, "shop greeting must begin with typewriter reveal")
	shop.purchase_form(CLAIM_FORM)
	shop.purchase_form(ARCHIVE_FORM)
	assert(state.manager.get_personal_form_count(CLAIM_FORM, "blank") == 1, "shop must issue the selected claim form")
	assert(state.manager.get_personal_form_count(ARCHIVE_FORM, "blank") == 1, "shop must issue the selected archive form")
	assert(state.balance == 20, "shop must charge configured form fees")

	state.evening_location_id = "LOCATION-FORMS"
	error = change_scene_to_file("res://scenes/application_office.tscn")
	assert(error == OK, "application office scene must load")
	await process_frame
	await process_frame
	var office = current_scene
	assert(office.blank_forms.size() == 2, "application office must list blank forms from the dossier")
	office.applicant_input.text = "测试职员"
	office.residence_input.text = "第十二区 · 职员宿舍 12-C"
	office.reason_input.text = "认领与本人身份记录有关的旧物"
	office.truth_check.button_pressed = true
	office.submit_selected_form()
	assert(state.manager.get_personal_form_count(CLAIM_FORM, "pending") == 1, "submitted form must enter pending status")
	assert(state.manager.get_personal_form_count(ARCHIVE_FORM, "blank") == 1, "unsubmitted forms must remain blank")

	state.manager.begin_next_day()
	assert(state.manager.get_personal_form_count(CLAIM_FORM, "effective") == 1, "approved application must become effective next day")
	assert(state.manager.get_personal_form_count(ARCHIVE_FORM, "blank") == 1, "unsubmitted form must survive the night")
	var delivered: Dictionary = state.personal_form_inventory[0]
	assert(String(delivered.get("fulfillment_id", "")) == "FULFILLMENT-OLD-TOOLBOX", "approved form must preserve configured fulfillment")
	print("FORMOCRACY_FORM_SHOP_FLOW_TEST_OK")
	quit(0)
