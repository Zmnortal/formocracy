extends Control

const EVENING_MAP_SCENE := "res://scenes/evening_map.tscn"

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
	var settlement: Dictionary = WorkdayState.get_settlement()
	title_label.text = WorkdayState.report_title
	var clerk_name := WorkdayState.player_name if not WorkdayState.player_name.is_empty() else "未登记职员"
	metadata_label.text = "经办员：%s    工作日：%02d    回执：D12-%04d    生成时间：当日终止后" % [clerk_name, day, day]
	stats_label.text = "形式审查 %02d    送交验收 %02d    批准 %02d    驳回 %02d    程序错误 %02d\n日薪 %+d  绩效 %+d  罚款 -%d  生活支出 -%d  本日结余 %+d  %s" % [
		summary.reviewed, summary.submitted, summary.approved,
		summary.rejected, summary.procedure_errors,
		settlement.base_salary, settlement.performance, settlement.fines,
		settlement.living_expenses, settlement.net, settlement.political_evaluation
	]
	var lines: Array[String] = []
	for i in WorkdayState.records.size():
		var record: Dictionary = WorkdayState.records[i]
		lines.append("%02d / %s / %s / 处理：%s / 程序：%s" % [
			i + 1, record.code, record.applicant, record.decision,
			"完整" if record.get("procedure_errors", []).is_empty() else "、".join(record.get("procedure_errors", []))
		])
	if lines.is_empty():
		lines.append("00 / 本工作日未形成可供汇总的事项记录")
	cases_label.text = "\n".join(lines)
	_send_report_to_glass(day, summary, settlement)


func _send_report_to_glass(day: int, summary: Dictionary, settlement: Dictionary) -> void:
	var bridge := get_tree().root.get_node_or_null("RealityBridge")
	if bridge == null:
		return
	bridge.day_report(
		[
			"形式审查：%d　批准：%d　驳回：%d" % [
				summary.reviewed,
				summary.approved,
				summary.rejected,
			],
			"程序错误：%d　现实生效：%d　等待处理：%d" % [
				summary.procedure_errors,
				summary.effective,
				summary.pending,
			],
			"日薪：%+d　绩效：%+d　罚款：-%d" % [
				settlement.base_salary,
				settlement.performance,
				settlement.fines,
			],
			"生活支出：-%d　本日结余：%+d" % [
				settlement.living_expenses,
				settlement.net,
			],
			"政治评价：%s" % settlement.political_evaluation,
		],
		day,
		WorkdayState.report_title
	)


# 玩家勾选或取消“已核对记录”声明时调用。
# 根据 pressed 状态启用或禁用确认按钮，并在状态栏提示“可结束工作日”或“等待人员确认”。
# 当处于封存过程中时，按钮仍保持禁用，避免重复提交。
func _on_declaration_toggled(pressed: bool) -> void:
	Sfx.play("ui_switch")
	confirm_button.disabled = not pressed or confirming
	status_line.text = "记录状态：可结束工作日" if pressed else "记录状态：等待人员确认"


# 玩家点击确认封存后执行。先校验声明已勾选且未处于封存中，设置 confirming 标志防止重复提交。
# 成功后进入下班地图；此时仍属于当前工作日，不提前结算或清除当日记录。
# 若场景切换失败则复位标志并提示“封存失败，请重试”。
func _on_confirm_pressed() -> void:
	if confirming or not declaration.button_pressed:
		return
	confirming = true
	Sfx.play("ui_click")
	confirm_button.disabled = true
	status_line.text = "记录状态：正在封存"
	WorkdayState.begin_evening()
	var error: Error = get_tree().change_scene_to_file(EVENING_MAP_SCENE)
	if error != OK:
		confirming = false
		status_line.text = "记录状态：封存失败，请重试"
		confirm_button.disabled = false


# 以 1280x720 为设计分辨率，按实际视口大小等比例缩放整个日报 Control 并将位置归零。
# 保证日报在不同分辨率下都能铺满屏幕，不留下黑边。
func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO
