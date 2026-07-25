class_name WorkdayNewspaperModule
extends RefCounted

# 管理报纸订阅表的送交、一次性核验、订阅有效期与每日唯一精读记录。

const CONFIG_PATH := "res://data/narrative/newspapers.json"
const SUBSCRIPTION_FORM_ID := "PERSONAL-FORM-NEWSPAPER-S01"
const OFFICIAL_PUBLISHER_ID := "NEWSPAPER-HENGCHUAN-DAILY"
const PROCESSING_FEE := 1
const VALID_DURATIONS := [3, 7]
const PLAYER_IDENTITY_NUMBER := "HC-12-12001"

var state: WorkdayContext
var config: WorkdayConfigGateway
var _newspaper_config: Dictionary = {}


func _init(owner_state: WorkdayContext, config_gateway: WorkdayConfigGateway) -> void:
	state = owner_state
	config = config_gateway


# 返回玩家登记身份号；报刊亭会用它核对订阅表。
func get_player_identity_number() -> String:
	return PLAYER_IDENTITY_NUMBER


# 送交一张订阅表。机器先收费、吞表，再核验，因此退件不会退费或退表。
func submit_subscription(fields: Dictionary) -> Dictionary:
	var blank_form := _find_blank_subscription_form()
	if blank_form.is_empty():
		return _result(false, "档案袋中没有空白《报刊订阅通行申请》。", false)
	if state.balance < PROCESSING_FEE:
		return _result(false, "送件手续费不足，机器尚未吞入表单。", false)

	state.balance -= PROCESSING_FEE
	blank_form.status = "consumed"
	blank_form.fields = fields.duplicate(true)
	blank_form.submitted_day = state.day_number
	blank_form.processed_day = state.day_number

	var validation := _validate_subscription_fields(fields)
	var approved := WorkdayContext.read_bool(validation, "approved")
	var reason := WorkdayContext.read_string(validation, "reason")
	blank_form.review_result = "订阅登记完成" if approved else "退件销毁"
	blank_form.review_reason = reason

	if approved:
		var publisher_id := WorkdayContext.read_string(fields, "publisher_id")
		var duration_days := WorkdayContext.read_int(fields, "duration_days")
		var start_day := state.day_number + 1
		state.newspaper_subscriptions[publisher_id] = {
			"publisher_id": publisher_id,
			"start_day": start_day,
			"end_day": start_day + duration_days - 1,
			"duration_days": duration_days,
			"submitted_day": state.day_number,
			"delivery_address": WorkdayContext.read_string(fields, "delivery_address"),
		}

	state.last_newspaper_submission_result = {
		"approved": approved,
		"reason": reason,
		"publisher_id": WorkdayContext.read_string(fields, "publisher_id"),
		"processed_day": state.day_number,
		"form_consumed": true,
		"fee_charged": PROCESSING_FEE,
	}
	if state.persistence_enabled:
		state.save_progress()
	return _result(approved, reason, true)


# 返回当前工作日可见的全部报纸。单位配发的官方报永远在第一位。
func get_available_newspapers(day: int = -1) -> Array[Dictionary]:
	var target_day := state.day_number if day < 0 else day
	var result: Array[Dictionary] = []
	var publishers := _get_publishers()
	for publisher in publishers:
		var publisher_id := WorkdayContext.read_string(publisher, "id")
		if publisher_id != OFFICIAL_PUBLISHER_ID and not _is_subscription_active(publisher_id, target_day):
			continue
		var issue := _issue_for_day(publisher, target_day)
		var merged := publisher.duplicate(true)
		merged["issue"] = issue
		result.append(merged)
	return result


# 记录当天唯一一份精读报纸；同一天已经读过另一份时拒绝改选。
func mark_newspaper_read(publisher_id: String, day: int = -1) -> bool:
	var target_day := state.day_number if day < 0 else day
	var key := str(target_day)
	var existing := WorkdayContext.read_string(state.newspaper_read_history, key)
	if not existing.is_empty():
		return existing == publisher_id
	var available := get_available_newspapers(target_day)
	for newspaper in available:
		if WorkdayContext.read_string(newspaper, "id") == publisher_id:
			state.newspaper_read_history[key] = publisher_id
			if state.persistence_enabled:
				state.save_progress()
			return true
	return false


# 返回当天已经精读的发行商编号。
func get_read_newspaper(day: int = -1) -> String:
	var target_day := state.day_number if day < 0 else day
	return WorkdayContext.read_string(state.newspaper_read_history, str(target_day))


# 返回最近一次报刊亭处理结果。
func get_last_submission_result() -> Dictionary:
	return state.last_newspaper_submission_result.duplicate(true)


func _find_blank_subscription_form() -> Dictionary:
	for item in state.personal_form_inventory:
		if (
			WorkdayContext.read_string(item, "form_type_id") == SUBSCRIPTION_FORM_ID
			and WorkdayContext.read_string(item, "status") == "blank"
		):
			return item
	return {}


func _validate_subscription_fields(fields: Dictionary) -> Dictionary:
	var publisher_id := WorkdayContext.read_string(fields, "publisher_id")
	var duration_days := WorkdayContext.read_int(fields, "duration_days")
	if not _is_paid_publisher(publisher_id):
		return {"approved": false, "reason": "发行商编号无效，或该报纸不接受个人订阅。"}
	if duration_days not in VALID_DURATIONS:
		return {"approved": false, "reason": "订阅期限必须为 3 日或 7 日。"}
	if WorkdayContext.read_string(fields, "delivery_address") != "第十二区 · 职员宿舍 12-C":
		return {"approved": false, "reason": "投递地址与现行居住登记不一致。"}
	if WorkdayContext.read_string(fields, "identity_number") != PLAYER_IDENTITY_NUMBER:
		return {"approved": false, "reason": "本市身份证明号核验失败。"}
	var expected_signature := state.player_name if not state.player_name.is_empty() else "经办员"
	if WorkdayContext.read_string(fields, "signature") != expected_signature:
		return {"approved": false, "reason": "签名与登记姓名不一致。"}
	if not WorkdayContext.read_bool(fields, "truth_declared"):
		return {"approved": false, "reason": "缺少真实性与退件销毁声明。"}
	return {"approved": true, "reason": "登记通过；报纸将从第 %02d 工作日开始投递。" % (state.day_number + 1)}


func _is_paid_publisher(publisher_id: String) -> bool:
	for publisher in _get_publishers():
		if (
			WorkdayContext.read_string(publisher, "id") == publisher_id
			and not WorkdayContext.read_bool(publisher, "free")
		):
			return true
	return false


func _is_subscription_active(publisher_id: String, day: int) -> bool:
	var subscription := WorkdayContext.read_dictionary(state.newspaper_subscriptions, publisher_id)
	if subscription.is_empty():
		return false
	return day >= WorkdayContext.read_int(subscription, "start_day") and day <= WorkdayContext.read_int(subscription, "end_day")


func _issue_for_day(publisher: Dictionary, day: int) -> Dictionary:
	var issues := WorkdayContext.read_array(publisher, "issues")
	for issue in issues:
		if WorkdayContext.read_int(issue, "day") == day:
			return issue.duplicate(true)
	if not issues.is_empty():
		return issues[(day - 1) % issues.size()].duplicate(true)
	return {
		"day": day,
		"headline": "本日未收到可公开稿件",
		"teaser": "印刷系统保留了空白版面。",
		"article": "没有更多内容。",
		"reflection": "空白也算一种消息。",
	}


func _get_publishers() -> Array[Dictionary]:
	if _newspaper_config.is_empty() and FileAccess.file_exists(CONFIG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			@warning_ignore("unsafe_cast")
			_newspaper_config = parsed
	var result: Array[Dictionary] = []
	for value: Variant in WorkdayContext.read_array(_newspaper_config, "publishers"):
		if value is Dictionary:
			@warning_ignore("unsafe_cast")
			var publisher: Dictionary = value
			result.append(publisher)
	return result


func _result(approved: bool, reason: String, consumed: bool) -> Dictionary:
	return {
		"approved": approved,
		"reason": reason,
		"form_consumed": consumed,
		"fee_charged": PROCESSING_FEE if consumed else 0,
	}
