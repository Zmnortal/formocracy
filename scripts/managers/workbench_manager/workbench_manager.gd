class_name WorkbenchManager
extends RefCounted

# 主工作台功能域的唯一公开入口。
# 场景只转发生命周期；案件、文件、输入、印章、归档和 NPC 流程由本 Manager 统一编排。

const CasePresenterModule := preload("res://scripts/managers/workbench_manager/workbench_case_presenter.gd")
const CaseSequenceModule := preload("res://scripts/managers/workbench_manager/workbench_case_sequence.gd")
const InputModule := preload("res://scripts/managers/workbench_manager/workbench_input_module.gd")
const StampModule := preload("res://scripts/managers/workbench_manager/workbench_stamp_module.gd")
const SubmissionModule := preload("res://scripts/managers/workbench_manager/workbench_submission_module.gd")
const BatchValidationModule := preload("res://scripts/managers/workbench_manager/workbench_batch_validation_module.gd")
const CallBellModule := preload("res://scripts/managers/workbench_manager/workbench_call_bell_module.gd")
const BriefingModule := preload("res://scripts/managers/workbench_manager/workbench_briefing_module.gd")
const BriefingDirector := preload("res://scripts/managers/workbench_manager/workbench_briefing_director.gd")
const NpcPerformanceModule := preload("res://scripts/managers/workbench_manager/workbench_npc_performance_module.gd")
const FilingCabinetModule := preload("res://scripts/managers/workbench_manager/workbench_filing_cabinet_module.gd")

var root: Node2D
var desk: DeskNodes
var presenter: WorkbenchCasePresenter
var stamp: WorkbenchStampModule
var input: WorkbenchInputModule
var submission: WorkbenchSubmissionModule
var sequence: WorkbenchCaseSequence
var npc_performance: WorkbenchNpcPerformanceModule
var briefing: WorkbenchBriefingModule
var dialogue_box: DialogueBox
var call_bell: WorkbenchCallBellModule
var batch_validation: WorkbenchBatchValidationModule
var desk_items: DeskItemController
var filing_cabinet: WorkbenchFilingCabinetModule

var current_case: Dictionary = {}
var accepting_new_cases := true
var flow_state := "BRIEFING"
var workday_started := false
var case_index := -1


func _init(owner_root: Node2D) -> void:
	root = owner_root


# 构建并启动完整工作台功能域。
func start() -> void:
	OpeningMusic.stop_opening(1.2)
	Sfx.start_ambience()

	desk = DeskBuilder.new().build(root)
	desk_items = DeskItemController.new(root)
	filing_cabinet = FilingCabinetModule.new(root, desk, desk_items)
	presenter = CasePresenterModule.new(root, desk, desk_items)
	stamp = StampModule.new(root, desk, presenter, desk_items)
	input = InputModule.new(root, desk, desk_items)
	submission = SubmissionModule.new(root, desk)
	sequence = CaseSequenceModule.new()
	dialogue_box = DialogueBox.new()
	root.add_child(dialogue_box)
	npc_performance = NpcPerformanceModule.new(root)
	briefing = BriefingModule.new(root, dialogue_box)
	call_bell = CallBellModule.new(root)
	batch_validation = BatchValidationModule.new(root)
	desk_items.register_item(desk.number_machine, "number_machine")
	desk_items.register_item(desk.slot, "archive_tray")
	call_bell.enable_desk_movement(desk_items)

	sequence.case_started.connect(presenter.start_case)
	sequence.case_started.connect(_bind_presenter_input)
	sequence.case_started.connect(_on_case_started)
	stamp.stamp_applied.connect(presenter.apply_stamp)
	input.envelope_submitted.connect(_on_envelope_submitted)
	submission.submission_finished.connect(_on_submission_finished)
	npc_performance.delivery_finished.connect(_on_npc_delivery_finished)
	npc_performance.departure_finished.connect(_on_npc_departed)
	briefing.finished.connect(_on_briefing_finished)
	call_bell.called.connect(_on_call_bell)
	batch_validation.finished.connect(_open_daily_report)
	sequence.day_finished.connect(_on_day_finished)

	root.get_viewport().size_changed.connect(fit_to_window)
	(
		GameStateSync
		. scene_changed(
			"workbench",
			"briefing",
			{
				"day": WorkdayState.day_number,
				"levelId": WorkdayState.current_level_id,
			}
		)
	)
	sequence.start_day(accepting_new_cases, false)
	_update_need_status()
	fit_to_window()
	briefing.play(BriefingDirector.new(WorkdayState).build_lines())


# 每帧推进工作日计时；超时后停止接收新案件。
func process(delta: float) -> void:
	if not workday_started or root.get_tree().paused or not accepting_new_cases:
		return
	WorkdayState.manager.tick(delta)
	if is_instance_valid(desk.timer_label):
		var remaining := ceili(WorkdayState.seconds_remaining)
		desk.timer_label.text = "剩余 %02d:%02d" % [remaining / 60, remaining % 60]
	if WorkdayState.manager.is_time_up():
		accepting_new_cases = false
		if is_instance_valid(desk.status_label):
			desk.status_label.text = "工作时间结束：完成当前案件后停止接待。"


# 仅处理没有被文件或桌面工具消费的点击，用于关闭查验层且不抢占其他交互。
func handle_unhandled_input(event: InputEvent) -> void:
	if filing_cabinet != null and filing_cabinet.handle_unhandled_input(event):
		return
	if presenter == null:
		return
	presenter.handle_unhandled_input(event)


# 释放工作台功能域持有的输入、语音和环境音资源。
func shutdown() -> void:
	if root == null:
		return
	CursorManager.reset()
	if filing_cabinet != null:
		filing_cabinet.shutdown()
	if npc_performance != null:
		npc_performance.shutdown()
	if briefing != null:
		briefing.shutdown()
	if is_instance_valid(dialogue_box):
		dialogue_box.queue_free()
	Sfx.stop_ambience()
	Sfx.stop_conveyor()
	if root.get_viewport().size_changed.is_connected(fit_to_window):
		root.get_viewport().size_changed.disconnect(fit_to_window)
	presenter = null
	stamp = null
	input = null
	submission = null
	sequence = null
	npc_performance = null
	briefing = null
	dialogue_box = null
	call_bell = null
	batch_validation = null
	filing_cabinet = null
	desk_items = null
	desk = null
	root = null


# 测试辅助：跳过简报并直接触发召唤铃开始第一个案件。
func start_first_case_for_tests() -> void:
	briefing.skip()
	call_bell.trigger(true)
	dialogue_box.reveal_current_line()
	dialogue_box._handle_manual_advance()


# 将 1280×720 设计画布适配到当前窗口。
func fit_to_window() -> void:
	var viewport_size := root.get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	root.scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	root.position = Vector2.ZERO


# 根据个人饮水状态更新工作台提示。
func _update_need_status() -> void:
	if WorkdayState.water_deprived:
		desk.need_status_label.text = "生活状态：缺水 / 工作时间 -20 秒 / 拖拽响应 72%"
		desk.need_status_label.add_theme_color_override("font_color", Color("d98463"))
		desk.status_label.text = "个人饮水配额未生效。今日操作响应受到影响。"
	else:
		desk.need_status_label.text = "生活状态：饮水正常 / 配额有效至第 %02d 工作日" % WorkdayState.water_covered_until_day


# 新案件创建后将输入模块绑定到本次表单展示器。
func _bind_presenter_input(_case_data: Dictionary) -> void:
	input.bind_case(presenter)


# 新案件开始时记录数据并启动申请人表演。
func _on_case_started(case_data: Dictionary) -> void:
	flow_state = "NPC_PERFORMANCE"
	current_case = case_data
	case_index = sequence.case_index
	(
		GameStateSync
		. publish_state(
			{
				"phase": "npc_at_counter",
				"metadata":
				{
					"caseId": WorkdayContext.read_string(case_data, "case_id"),
					"day": WorkdayState.day_number,
				},
			}
		)
	)
	if is_instance_valid(presenter.envelope):
		presenter.envelope.visible = false
		presenter.envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc_performance.start_case(case_data, LevelDirector.get_gameplay_queue())


# NPC 递交完成后将信封滑入工作台并恢复交互。
func _on_npc_delivery_finished() -> void:
	if not is_instance_valid(presenter.envelope):
		return
	presenter.envelope.position = WorkbenchCasePresenter.ENVELOPE_DELIVERY_POSITION
	presenter.envelope.visible = true
	presenter.envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var delivery := root.create_tween()
	delivery.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	delivery.tween_property(presenter.envelope, "position", WorkbenchCasePresenter.ENVELOPE_DESK_POSITION, 0.32)
	await delivery.finished
	if is_instance_valid(presenter.envelope):
		presenter.envelope.mouse_filter = Control.MOUSE_FILTER_STOP
		presenter.set_envelope_on_desk(true)
	if is_instance_valid(desk.queue_label):
		var person := WorkdayContext.read_dictionary(current_case, "person")
		var display_name := WorkdayContext.read_string(person, "display_name", "身份受限")
		desk.queue_label.text = "%s\n已投递文件袋\n等待办理" % display_name


# 玩家提交信封时转交提交模块处理当前案件。
func _on_envelope_submitted() -> void:
	submission.submit(presenter, current_case)


# 提交结束后让 NPC 根据盖章结果做出反应并离场。
func _on_submission_finished() -> void:
	var should_promote := accepting_new_cases and not WorkdayState.manager.should_show_report()
	npc_performance.react_and_leave(presenter.stamp_type(), should_promote)


# NPC 离场后进入批量送验，或等待玩家再次按铃。
func _on_npc_departed() -> void:
	if WorkdayState.manager.should_show_report() or not accepting_new_cases:
		_begin_batch_validation()
	else:
		flow_state = "WAITING_FOR_NEXT_CALL"
		_show_staged_applicant()
		call_bell.unlock()
		desk.status_label.text = "上一位申请人已离场。请按召唤铃传唤下一位。"


# 显示已经补位、等待传唤的下一位申请人。
func _show_staged_applicant() -> void:
	var staged_id := npc_performance.staged_case_id
	if staged_id.is_empty():
		return
	var staged_case := ConfigDatabase.get_gameplay_case(staged_id)
	if staged_case.is_empty():
		return
	var person := WorkdayContext.read_dictionary(staged_case, "person")
	var display_name := WorkdayContext.read_string(person, "display_name", "身份受限")
	if is_instance_valid(desk.applicant_card_label):
		desk.applicant_card_label.text = "%s\n等待传唤\n档案尚未投递" % display_name
	if is_instance_valid(desk.queue_label):
		desk.queue_label.text = (
			"%s\n已补位 / 等待传唤\n后续排队：%d 人"
			% [
				display_name,
				npc_performance.queue_case_ids.size(),
			]
		)


# 秘书简报结束后解锁首次传唤。
func _on_briefing_finished() -> void:
	flow_state = "WAITING_FOR_FIRST_CALL"
	GameStateSync.speaker_stopped("waiting_for_first_call")
	call_bell.unlock()
	desk.status_label.text = "简报结束。请按召唤铃传唤第一位申请人。"


# 按铃后先用共享底部对话框显示广播；玩家确认后才传唤下一位。
func _on_call_bell() -> void:
	if not workday_started:
		workday_started = true
	flow_state = "CALLING"
	var bridge := root.get_tree().root.get_node_or_null("RealityBridge")
	if bridge != null:
		bridge.call("secretary_line", "下一位。")
	GameStateSync.speaker_started("INTERNAL-BROADCAST", "内部广播", "system", "下一位。", "calling", {"day": WorkdayState.day_number})
	desk.status_label.text = "内部广播：下一位。"
	await dialogue_box.play_line("内部广播", "下一位。", "broadcast")
	dialogue_box.close()
	GameStateSync.speaker_stopped("calling")
	if flow_state != "CALLING":
		return
	sequence.advance(accepting_new_cases)


# 案件序列结束后进入批量送验。
func _on_day_finished() -> void:
	_begin_batch_validation()


# 锁定召唤铃并打开日终批量送验托盘。
func _begin_batch_validation() -> void:
	flow_state = "BATCH_VALIDATION"
	call_bell.lock()
	if WorkdayState.manager.get_pending_archives().is_empty():
		_open_daily_report()
		return
	batch_validation.open()
	desk.status_label.text = "工作时间结束：请从归档与积压中选择有限档案统一送验。"


# 切换到日报场景，失败时保留当前记录并显示提示。
func _open_daily_report() -> void:
	var error: Error = root.get_tree().change_scene_to_file("res://scenes/daily_report.tscn")
	if error != OK and is_instance_valid(desk.status_label):
		desk.status_label.text = "内部日报生成失败，当前记录已保留。"
