extends SceneTree

const FORM_ID := "PERSONAL-FORM-NEWSPAPER-S01"
const MORNING_ID := "NEWSPAPER-DISTRICT-12-MORNING"
const GAZETTE_ID := "NEWSPAPER-ADMIN-GAZETTE"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.player_name = "测试职员"
	state.balance = 10

	var day_one_papers: Array[Dictionary] = state.manager.get_available_newspapers()
	assert(day_one_papers.size() == 1, "official newspaper must be the free fallback")
	assert(String(day_one_papers[0].get("id", "")) == "NEWSPAPER-HENGCHUAN-DAILY", "free fallback must be 衡川日报")

	assert(state.manager.purchase_personal_form(FORM_ID), "subscription form must be purchasable")
	assert(state.balance == 9, "blank subscription form must cost one point")
	var rejected: Dictionary = state.manager.submit_newspaper_subscription(
		{
			"publisher_id": MORNING_ID,
			"duration_days": 3,
			"delivery_address": "第十二区 · 职员宿舍 12-C",
			"identity_number": "错误身份号",
			"signature": "测试职员",
			"truth_declared": true,
		}
	)
	assert(not bool(rejected.get("approved", true)), "wrong identity must be rejected")
	assert(bool(rejected.get("form_consumed", false)), "rejected submission must consume the form")
	assert(state.balance == 8, "rejected submission must still charge one processing point")
	assert(state.manager.get_personal_form_count(FORM_ID, "blank") == 0, "rejected form must never return to blank inventory")

	assert(state.manager.purchase_personal_form(FORM_ID), "a rejected form must require a fresh purchase")
	var approved: Dictionary = state.manager.submit_newspaper_subscription(
		{
			"publisher_id": GAZETTE_ID,
			"duration_days": 3,
			"delivery_address": "第十二区 · 职员宿舍 12-C",
			"identity_number": state.manager.get_player_identity_number(),
			"signature": "测试职员",
			"truth_declared": true,
		}
	)
	assert(bool(approved.get("approved", false)), "valid subscription must be accepted")
	assert(state.balance == 6, "successful purchase and submission must each cost one point")
	var subscription: Dictionary = state.newspaper_subscriptions.get(GAZETTE_ID, {})
	assert(int(subscription.get("start_day", 0)) == 2, "accepted subscription must begin next morning")
	assert(int(subscription.get("end_day", 0)) == 4, "three-day subscription must include exactly days two through four")
	assert(state.manager.get_available_newspapers(1).size() == 1, "paid newspaper must not appear on submission day")
	assert(state.manager.get_available_newspapers(2).size() == 2, "paid newspaper must appear on its first active day")

	assert(state.manager.mark_newspaper_read(GAZETTE_ID, 2), "an available paid paper must be readable")
	assert(not state.manager.mark_newspaper_read("NEWSPAPER-HENGCHUAN-DAILY", 2), "a second paper must be locked after the daily choice")
	assert(state.manager.get_read_newspaper(2) == GAZETTE_ID, "daily read history must preserve the first selection")
	assert(state.manager.get_available_newspapers(4).size() == 2, "subscription must remain active through its inclusive end day")
	assert(state.manager.get_available_newspapers(5).size() == 1, "expired subscription must disappear after its end day")
	var snapshot: Dictionary = state._capture_state().duplicate(true)
	state.reset_for_tests()
	state._apply_state(snapshot)
	assert(state.newspaper_subscriptions.has(GAZETTE_ID), "subscription must survive save-state restoration")
	assert(state.manager.get_read_newspaper(2) == GAZETTE_ID, "daily reading choice must survive save-state restoration")

	print("FORMOCRACY_NEWSPAPER_SUBSCRIPTION_TEST_OK")
	quit(0)
