extends Control

@onready var metadata_label: Label = $Terminal/Receipt/Metadata
@onready var title_label: Label = $Terminal/Receipt/Title
@onready var stats_label: Label = $Terminal/Receipt/Stats/StatsText
@onready var cases_label: Label = $Terminal/Receipt/CasesText
@onready var declaration: CheckBox = $Terminal/Receipt/Declaration
@onready var confirm_button: Button = $Terminal/Receipt/ConfirmButton
@onready var status_line: Label = $Terminal/StatusLine

var confirming := false


# 场景进入时初始化日报界面。
# 连接声明复选框与确认按钮的信号，立即渲染当前工作日的汇总内容，并监听视口尺寸变化以自适应 1280x720 的基准分辨率。
func _ready() -> void:
	declaration.toggled.connect(_on_declaration_toggled)
	confirm_button.pressed.connect(_on_confirm_pressed)
	populate_report()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


# 从 WorkdayState 读取当前工作日编号与统计摘要，填充日报的元数据、统计行与事项列表。
# 元数据包含工作日编号与回执编号；统计行涵盖形式审查、送交验收、批准、驳回、退回补正、取得现实效力与等待设施处理数量；
# 事项列表按“序号 / 编号 / 申请人 / 处理结果 / 效力状态”渲染。若当日无记录，则显示占位说明。
func populate_report() -> void:
	var day: int = WorkdayState.day_number
	var summary: Dictionary = WorkdayState.get_summary()
	title_label.text = WorkdayState.report_title
	metadata_label.text = "工作日：%02d    回执：D12-%04d    生成时间：当日终止后" % [day, day]
	stats_label.text = "形式审查 %02d    送交验收 %02d    批准 %02d    驳回 %02d    退回补正 %02d\n取得现实效力 %02d    等待设施处理 %02d" % [
		summary.reviewed, summary.submitted, summary.approved,
		summary.rejected, summary.returned, summary.effective, summary.pending
	]
	var lines: Array[String] = []
	for i in WorkdayState.records.size():
		var record: Dictionary = WorkdayState.records[i]
		lines.append("%02d / %s / %s / 处理：%s / 效力：等待验收" % [
			i + 1, record.code, record.applicant, record.decision
		])
	if lines.is_empty():
		lines.append("00 / 本工作日未形成可供汇总的事项记录")
	cases_label.text = "\n".join(lines)


# 玩家勾选或取消“已核对记录”声明时调用。
# 根据 pressed 状态启用或禁用确认按钮，并在状态栏提示“可结束工作日”或“等待人员确认”。
# 当处于封存过程中时，按钮仍保持禁用，避免重复提交。
func _on_declaration_toggled(pressed: bool) -> void:
	confirm_button.disabled = not pressed or confirming
	status_line.text = "记录状态：可结束工作日" if pressed else "记录状态：等待人员确认"


# 玩家点击确认封存后执行。先校验声明已勾选且未处于封存中，设置 confirming 标志防止重复提交。
# 成功后切换回主场景，并通过 WorkdayState.begin_next_day() 进入下一工作日；
# 若场景切换失败则复位标志并提示“封存失败，请重试”。
func _on_confirm_pressed() -> void:
	if confirming or not declaration.button_pressed:
		return
	confirming = true
	confirm_button.disabled = true
	status_line.text = "记录状态：正在封存"
	var error: Error = get_tree().change_scene_to_file("res://main.tscn")
	if error != OK:
		confirming = false
		status_line.text = "记录状态：封存失败，请重试"
		confirm_button.disabled = false
	else:
		WorkdayState.begin_next_day()


# 以 1280x720 为设计分辨率，按实际视口大小等比例缩放整个日报 Control 并将位置归零。
# 保证日报在不同分辨率下都能铺满屏幕，不留下黑边。
func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO
