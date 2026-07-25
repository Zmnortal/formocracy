extends SceneTree

const FORM_ID := "PERSONAL-FORM-NEWSPAPER-S01"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	var pause_menu = root.get_node("PauseMenu")
	state.reset_for_tests()
	state.player_name = "测试职员"
	state.balance = 10
	assert(state.manager.purchase_personal_form(FORM_ID), "kiosk flow requires a purchased blank form")
	state.evening_location_id = "LOCATION-NEWSSTAND"

	var error := change_scene_to_file("res://scenes/newspaper_kiosk.tscn")
	assert(error == OK, "newspaper kiosk scene must load")
	await process_frame
	await process_frame
	var kiosk = current_scene
	assert(kiosk.publishers.size() == 3, "kiosk must offer the three paid publishers")
	assert(kiosk.dialogue_box is DialogueBox, "kiosk result must reuse the shared DialogueBox")
	assert(pause_menu.is_scene_allowed_path("res://scenes/newspaper_kiosk.tscn"), "kiosk must allow the shared pause menu")
	assert(kiosk.form_count_label.text.contains("1"), "kiosk must show the blank form in the dossier")
	assert(kiosk.submit_button.disabled, "destruction declaration must be required before submission")

	kiosk.declaration.button_pressed = true
	kiosk._refresh_state()
	assert(not kiosk.submit_button.disabled, "valid dossier and balance must enable the machine")
	kiosk._submit()
	assert(state.balance == 8, "shop form and kiosk processing must cost one point each")
	assert(state.manager.get_personal_form_count(FORM_ID, "blank") == 0, "machine must swallow the submitted form")
	assert(not state.newspaper_subscriptions.is_empty(), "valid kiosk submission must register a subscription")
	assert(kiosk.dialogue_box.visible, "machine result must be manually acknowledged")

	error = change_scene_to_file("res://scenes/evening_map.tscn")
	assert(error == OK, "evening map must load after leaving the kiosk")
	await process_frame
	await process_frame
	var map = current_scene
	assert(map.kiosk_button != null, "evening map must expose an independent newspaper kiosk location")
	assert(map.LOCATION_NAMES.has("LOCATION-NEWSSTAND"), "kiosk must participate in map routing")
	var kiosk_button_size: Vector2 = map.kiosk_button.size
	map.kiosk_button.mouse_entered.emit()
	await process_frame
	assert(map.kiosk_button.scale == Vector2.ONE, "location hover must not scale or crop the button")
	assert(map.kiosk_button.size == kiosk_button_size, "location hover must preserve the button rectangle")

	print("FORMOCRACY_NEWSPAPER_KIOSK_FLOW_TEST_OK")
	quit(0)
