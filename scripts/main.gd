extends Node2D

# 主工作台场景协调器。
# 负责把构建、输入、案件、印章、提交等模块连接起来，并处理窗口缩放与倒计时。

var desk: DeskNodes
var presenter: CasePresenter
var stamp_mgr: StampManager
var input_mgr: WorkbenchInput
var submission_mgr: SubmissionManager
var sequence: CaseSequence

var current_case: Dictionary = {}
var accepting_new_cases := true


# 进入主工作台场景时调用：构建工作台、初始化各模块并启动第一个案件。
func _ready() -> void:
	OpeningMusic.stop_opening(1.2)
	Sfx.start_ambience()

	desk = DeskBuilder.new().build(self)
	presenter = CasePresenter.new(self, desk)
	stamp_mgr = StampManager.new(self, desk, presenter)
	input_mgr = WorkbenchInput.new(self, desk)
	submission_mgr = SubmissionManager.new(self, desk)
	sequence = CaseSequence.new()

	sequence.case_started.connect(presenter.start_case)
	sequence.case_started.connect(func(_data): input_mgr.bind_case(presenter))
	sequence.case_started.connect(_on_case_started)
	stamp_mgr.stamp_applied.connect(presenter.apply_stamp)
	input_mgr.envelope_submitted.connect(_on_envelope_submitted)
	submission_mgr.submission_finished.connect(_on_submission_finished)
	sequence.day_finished.connect(_on_day_finished)

	get_viewport().size_changed.connect(fit_to_window)
	sequence.start_day(accepting_new_cases)
	if WorkdayState.water_deprived:
		desk.need_status_label.text = "生活状态：缺水 / 工作时间 -20 秒 / 拖拽响应 72%"
		desk.need_status_label.add_theme_color_override("font_color", Color("d98463"))
		desk.status_label.text = "个人饮水配额未生效。今日操作响应受到影响。"
	else:
		desk.need_status_label.text = "生活状态：饮水正常 / 配额有效至第 %02d 工作日" % WorkdayState.water_covered_until_day
	fit_to_window()


var case_index := 0


func _on_case_started(case_data: Dictionary) -> void:
	current_case = case_data
	case_index = sequence.case_index


func _on_envelope_submitted() -> void:
	submission_mgr.submit(presenter, current_case)


func _on_submission_finished() -> void:
	if WorkdayState.should_show_report() or not accepting_new_cases:
		var error: Error = get_tree().change_scene_to_file("res://scenes/daily_report.tscn")
		if error != OK:
			if is_instance_valid(desk.status_label):
				desk.status_label.text = "内部日报生成失败，当前记录已保留。"
			sequence.advance(accepting_new_cases)
	else:
		sequence.advance(accepting_new_cases)


func _on_day_finished() -> void:
	var error: Error = get_tree().change_scene_to_file("res://scenes/daily_report.tscn")
	if error != OK and is_instance_valid(desk.status_label):
		desk.status_label.text = "内部日报生成失败，当前记录已保留。"


# 离开工作台场景时停止办公室环境音。
func _exit_tree() -> void:
	Sfx.stop_ambience()
	Sfx.stop_conveyor()


# 每帧更新倒计时，时间到后停止接收新案件。
func _process(_delta: float) -> void:
	if not get_tree().paused and accepting_new_cases:
		WorkdayState.tick(_delta)
		if is_instance_valid(desk.timer_label):
			var remaining := ceili(WorkdayState.seconds_remaining)
			desk.timer_label.text = "剩余 %02d:%02d" % [remaining / 60, remaining % 60]
		if WorkdayState.is_time_up():
			accepting_new_cases = false
			if is_instance_valid(desk.status_label):
				desk.status_label.text = "工作时间结束：完成当前案件后停止接待。"


# 以 1280x720 为设计分辨率，横纵独立缩放整个 Node2D 并将位置归零。
# 不使用等比 cover，避免宽高比变化时把右侧候选区和底部工作台裁出屏幕。
func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO
