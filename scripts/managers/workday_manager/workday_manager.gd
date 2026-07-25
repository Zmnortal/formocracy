class_name WorkdayManager
extends RefCounted

# 工作日功能域的唯一公开入口。
# 场景只调用这里的 methods；具体规则由同目录的原子模块实现。

const ClockModule := preload("res://scripts/managers/workday_manager/workday_clock_module.gd")
const SettlementModule := preload("res://scripts/managers/workday_manager/workday_settlement_module.gd")
const ArchiveModule := preload("res://scripts/managers/workday_manager/workday_archive_module.gd")
const PersonalFormModule := preload("res://scripts/managers/workday_manager/workday_personal_form_module.gd")
const NewspaperModule := preload("res://scripts/managers/workday_manager/workday_newspaper_module.gd")
const ConsequenceModule := preload("res://scripts/managers/workday_manager/workday_consequence_module.gd")
const DeskLayoutModule := preload("res://scripts/managers/workday_manager/workday_desk_layout_module.gd")
const ConfigGateway := preload("res://scripts/managers/workday_manager/workday_config_gateway.gd")
const DU_CHUNMEI_CASE_ID := "CASE-S-M52-D5"
const DU_CHUNMEI_EVENT_DAY := 6

var _state: WorkdayContext
var _config: WorkdayConfigGateway
var _clock: WorkdayClockModule
var _settlement: WorkdaySettlementModule
var _archive: WorkdayArchiveModule
var _personal_forms: WorkdayPersonalFormModule
var _newspapers: WorkdayNewspaperModule
var _consequences: WorkdayConsequenceModule
var _desk_layout: WorkdayDeskLayoutModule


func _init(state: WorkdayContext) -> void:
	_state = state
	_config = ConfigGateway.new(state)
	_clock = ClockModule.new(state)
	_settlement = SettlementModule.new(state)
	_archive = ArchiveModule.new(state)
	_personal_forms = PersonalFormModule.new(state, _config)
	_newspapers = NewspaperModule.new(state, _config)
	_consequences = ConsequenceModule.new(state, _config)
	_desk_layout = DeskLayoutModule.new(state)


# 记录案件判断、经济后果与归档条目。
func record_case_result(
	case_data: Dictionary,
	stamp_type: String,
	procedure_errors: Array = [],
	elapsed_seconds: float = 0.0,
	packed_document_ids: Array = [],
	document_stamps: Array = [],
	envelope_snapshot: Dictionary = {}
) -> void:
	var recorded := _consequences.record_case_result(case_data, stamp_type, procedure_errors, elapsed_seconds, packed_document_ids, document_stamps, envelope_snapshot)
	_archive.archive_record(recorded)
	if _state.persistence_enabled:
		_state.save_progress()


# 完成结算、积压老化、个人申请审核和跨日检查点创建。
func begin_next_day() -> void:
	var completed_day := _state.day_number
	var completed_settlement := _settlement.get_settlement()
	var completed_credit_delta := _consequences.get_credit_delta(_state.records)
	_settlement.settle_current_day()
	_archive.age_pending_archives()
	_evaluate_campaign_events(completed_day)
	if ConfigDatabase.is_final_workday(completed_day):
		complete_campaign()
		return
	_state.day_number += 1
	_state.records.clear()
	_state.evening_day_number = _state.day_number
	_state.evening_actions_remaining = 2
	_state.evening_location_id = "LOCATION-OFFICE"
	_personal_forms.process_due_forms()
	_clock.prepare_new_workday()
	_consequences.send_workday_consequences(completed_day, completed_settlement, completed_credit_delta)
	_consequences.send_due_delayed_consequences()
	if _state.persistence_enabled:
		_state.create_checkpoint(completed_day)


# 完成七日试玩并保持日数停留在最后一个工作日，避免重复载入第七日内容。
func complete_campaign() -> void:
	_settlement.settle_current_day()
	_state.narrative_flags["trial_completed"] = true
	_state.narrative_flags["trial_completed_day"] = _state.day_number
	if _state.persistence_enabled:
		_state.create_checkpoint(_state.day_number)
		_state.save_progress()


# 在第六夜结算杜春梅的资源申请：只有“批准且机器已验收”才能避免死亡。
func _evaluate_campaign_events(completed_day: int) -> void:
	if completed_day != DU_CHUNMEI_EVENT_DAY:
		return
	if WorkdayContext.read_bool(_state.narrative_flags, "du_chunmei_event_resolved"):
		return
	var latest_archive: Dictionary = {}
	for archive_value: Variant in _state.archived_cases:
		if not archive_value is Dictionary:
			continue
		@warning_ignore("unsafe_cast")
		var archive: Dictionary = archive_value
		if WorkdayContext.read_string(archive, "case_id") == DU_CHUNMEI_CASE_ID:
			latest_archive = archive
	var approved_and_effective := (
		not latest_archive.is_empty()
		and WorkdayContext.read_string(latest_archive, "decision") == "批准"
		and WorkdayContext.read_string(latest_archive, "status") == "EFFECTIVE"
	)
	_state.narrative_flags["du_chunmei_event_resolved"] = true
	_state.narrative_flags["du_chunmei_protected"] = approved_and_effective
	_state.narrative_flags["du_chunmei_deceased"] = not approved_and_effective
	_state.narrative_flags["du_chunmei_death_day"] = DU_CHUNMEI_EVENT_DAY if not approved_and_effective else 0
	_state.narrative_flags["du_chunmei_death_reason"] = (
		"连续用药与净水配额未在第六夜前生效" if not approved_and_effective else ""
	)


# 初始化当前工作日的夜间地图状态。
func begin_evening() -> void:
	_settlement.settle_current_day()
	if _state.evening_day_number != _state.day_number:
		_state.evening_day_number = _state.day_number
		_state.evening_actions_remaining = 2
		_state.evening_location_id = "LOCATION-OFFICE"
	if _state.persistence_enabled:
		_state.save_progress()


# 审核当前日期已经到期的个人表单。
func process_due_personal_forms() -> void:
	_personal_forms.process_due_forms()


# 根据个人生活状态准备工作日计时。
func prepare_new_workday() -> void:
	_clock.prepare_new_workday()


# 推进工作日倒计时。
func tick(delta: float) -> void:
	_clock.tick(delta)


# 判断工作时间是否耗尽。
func is_time_up() -> bool:
	return _clock.is_time_up()


# 返回当前工作日经济结算。
func get_settlement() -> Dictionary:
	return _settlement.get_settlement()


# 判断是否应进入日报。
func should_show_report() -> bool:
	return _settlement.should_show_report()


# 返回日报统计摘要。
func get_summary() -> Dictionary:
	return _settlement.get_summary()


# 返回等待机器验收的归档。
func get_pending_archives() -> Array[Dictionary]:
	return _archive.get_pending_archives()


# 验收容量允许范围内的一批归档。
func validate_archive_batch(archive_ids: Array) -> bool:
	return _archive.validate_archive_batch(archive_ids)


# 购买一份空白个人表单。
func purchase_personal_form(form_type_id: String) -> bool:
	return _personal_forms.purchase(form_type_id)


# 返回指定类型和状态的个人表单数量。
func get_personal_form_count(form_type_id: String, status: String = "") -> int:
	return _personal_forms.get_count(form_type_id, status)


# 填写并送交一份个人表单。
func submit_personal_form(form_type_id: String, fields: Dictionary) -> bool:
	return _personal_forms.submit(form_type_id, fields)


# 返回全部空白个人表单。
func get_blank_personal_forms() -> Array[Dictionary]:
	return _personal_forms.get_blank_forms()


# 返回最近一次个人表单审核摘要。
func get_personal_review_summary() -> Dictionary:
	return _personal_forms.get_review_summary()


# 返回报刊亭核验使用的玩家本市身份证明号。
func get_player_identity_number() -> String:
	return _newspapers.get_player_identity_number()


# 向报刊亭送交一张订阅表；表单被吞入后才返回核验结果。
func submit_newspaper_subscription(fields: Dictionary) -> Dictionary:
	return _newspapers.submit_subscription(fields)


# 返回当前日期所有可展示的报纸。
func get_available_newspapers(day: int = -1) -> Array[Dictionary]:
	return _newspapers.get_available_newspapers(day)


# 登记当天唯一精读的报纸。
func mark_newspaper_read(publisher_id: String, day: int = -1) -> bool:
	return _newspapers.mark_newspaper_read(publisher_id, day)


# 返回当天已经精读的报纸编号。
func get_read_newspaper(day: int = -1) -> String:
	return _newspapers.get_read_newspaper(day)


# 返回最近一次报刊亭处理结果。
func get_last_newspaper_submission_result() -> Dictionary:
	return _newspapers.get_last_submission_result()


# 返回当前拖拽响应倍率。
func get_drag_response_multiplier() -> float:
	return _clock.get_drag_response_multiplier()


# 保存桌面物件的稳定落点。
func set_desk_item_layout(item_id: String, item_position: Vector2, layer: int) -> void:
	_desk_layout.set_item_layout(item_id, item_position, layer)


# 返回桌面物件的保存位置。
func get_desk_item_layout(item_id: String) -> Dictionary:
	return _desk_layout.get_item_layout(item_id)
