extends Control

const EVENING_MAP_SCENE := "res://scenes/evening_map.tscn"
const REVEAL_OFFSET := Vector2(0.0, 7.0)
const REVEAL_SETTLE_SECONDS := 0.12
const REVEAL_INITIAL_DELAY_SECONDS := 0.30

@export_range(0.01, 2.0, 0.01) var reveal_interval_seconds := 0.92

var confirming := false
var reveal_sequence_finished := false
var revealed_block_count := 0
var reveal_generation := 0
var reveal_blocks: Array[Control] = []
var reveal_origins: Array[Vector2] = []

@onready var metadata_label: Label = $Terminal/Receipt/MetadataBlock/Metadata
@onready var title_label: Label = $Terminal/Receipt/Title
@onready var stats_label: Label = $Terminal/Receipt/Stats/StatsText
@onready var cases_label: Label = $Terminal/Receipt/CasesText
@onready var reviewed_value: Label = $Terminal/Receipt/StatsBlock/ReviewedValue
@onready var submitted_value: Label = $Terminal/Receipt/StatsBlock/SubmittedValue
@onready var approved_value: Label = $Terminal/Receipt/StatsBlock/ApprovedValue
@onready var rejected_value: Label = $Terminal/Receipt/StatsBlock/RejectedValue
@onready var procedure_value: Label = $Terminal/Receipt/StatsBlock/ProcedureValue
@onready var effect_summary: Label = $Terminal/Receipt/EffectBlock/EffectSummary
@onready var salary_amount: Label = $Terminal/Receipt/SalaryRow/Amount
@onready var performance_amount: Label = $Terminal/Receipt/PerformanceRow/Amount
@onready var fines_amount: Label = $Terminal/Receipt/FinesRow/Amount
@onready var expenses_amount: Label = $Terminal/Receipt/ExpensesRow/Amount
@onready var net_amount: Label = $Terminal/Receipt/BalanceBlock/Amount
@onready var evaluation_label: Label = $Terminal/Receipt/BalanceBlock/Evaluation
@onready var declaration: CheckBox = $Terminal/Receipt/DeclarationBlock/Declaration
@onready var confirm_button: Button = $Terminal/Receipt/DeclarationBlock/ConfirmButton
@onready var status_line: Label = $Terminal/StatusLine


# 场景进入时初始化日报界面。
# 连接声明复选框与确认按钮的信号，立即渲染当前工作日的汇总内容，并监听视口尺寸变化以自适应 1280x720 的基准分辨率。
func _ready() -> void:
	declaration.toggled.connect(_on_declaration_toggled)
	confirm_button.pressed.connect(_on_confirm_pressed)
	_collect_reveal_blocks()
	_prepare_reveal_sequence()
	populate_report()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()
	_play_reveal_sequence.call_deferred()


# 从 WorkdayState 读取当前工作日编号、统计摘要和经济结算。
# 主回执只显示固定数量的统计字段，不再绘制会随案件数量增长的逐案列表；
# 完整逐案文本仍写入隐藏数据标签，供测试、存档与外部桥接读取。
func populate_report() -> void:
	var day: int = WorkdayState.day_number
	var summary: Dictionary = WorkdayState.manager.get_summary()
	var settlement: Dictionary = WorkdayState.manager.get_settlement()
	title_label.text = "工作日处理回执 / 第 %02d 天" % day
	var clerk_name := WorkdayState.player_name if not WorkdayState.player_name.is_empty() else "未登记职员"
	metadata_label.text = "编号：D12-%04d        经办员：%s        工作日：%02d" % [day, clerk_name, day]
	stats_label.text = (
		"形式审查 %02d    送交验收 %02d    批准 %02d    驳回 %02d    程序错误 %02d\n现实生效 %02d    等待设施处理 %02d    日薪 %+d    绩效 %+d    罚款 -%d    生活支出 -%d    本日结余 %+d    %s"
		% [
			summary.reviewed,
			summary.submitted,
			summary.approved,
			summary.rejected,
			summary.procedure_errors,
			summary.effective,
			summary.pending,
			settlement.base_salary,
			settlement.performance,
			settlement.fines,
			settlement.living_expenses,
			settlement.net,
			settlement.political_evaluation
		]
	)
	reviewed_value.text = "%02d" % summary.reviewed
	submitted_value.text = "%02d" % summary.submitted
	approved_value.text = "%02d" % summary.approved
	rejected_value.text = "%02d" % summary.rejected
	procedure_value.text = "%02d" % summary.procedure_errors
	effect_summary.text = ("现实生效  %02d        等待设施处理  %02d        异常档案  %02d" % [summary.effective, summary.pending, summary.abnormal_records])
	salary_amount.text = "%+d" % settlement.base_salary
	performance_amount.text = "%+d" % settlement.performance
	fines_amount.text = "-%d" % settlement.fines
	expenses_amount.text = "-%d" % settlement.living_expenses
	net_amount.text = "%+d" % settlement.net
	evaluation_label.text = "内部评价：%s" % settlement.political_evaluation
	var lines: Array[String] = []
	for i in WorkdayState.records.size():
		var record: Dictionary = WorkdayState.records[i]
		lines.append(
			(
				"%02d / %s / %s / 处理：%s / 程序：%s"
				% [i + 1, record.code, record.applicant, record.decision, "完整" if record.get("procedure_errors", []).is_empty() else "、".join(record.get("procedure_errors", []))]
			)
		)
	if lines.is_empty():
		lines.append("00 / 本工作日未形成可供汇总的事项记录")
	cases_label.text = "\n".join(lines)
	_send_report_to_glass(day, summary, settlement)


# 固定日报中需要依次宣读的字段组。
func _collect_reveal_blocks() -> void:
	reveal_blocks = [
		$Terminal/Receipt/MetadataBlock,
		$Terminal/Receipt/StatsBlock,
		$Terminal/Receipt/EffectBlock,
		$Terminal/Receipt/SalaryRow,
		$Terminal/Receipt/PerformanceRow,
		$Terminal/Receipt/FinesRow,
		$Terminal/Receipt/ExpensesRow,
		$Terminal/Receipt/BalanceBlock,
		$Terminal/Receipt/DeclarationBlock,
	]
	reveal_origins.clear()
	for block: Control in reveal_blocks:
		reveal_origins.append(block.position)


# 先隐藏所有动态字段；确认区只在系统逐项生成完毕后开放。
func _prepare_reveal_sequence() -> void:
	reveal_sequence_finished = false
	revealed_block_count = 0
	declaration.disabled = true
	confirm_button.disabled = true
	for index in reveal_blocks.size():
		var block := reveal_blocks[index]
		block.visible = false
		block.modulate.a = 0.0
		block.position = reveal_origins[index] + REVEAL_OFFSET
	status_line.text = "记录状态：正在生成 00 / %02d" % reveal_blocks.size()


# 以接近一秒的节拍逐块落下日报字段；每一块只做短促位移和显现，不逐字打印。
func _play_reveal_sequence() -> void:
	if reveal_sequence_finished:
		return
	reveal_generation += 1
	var generation := reveal_generation
	await get_tree().create_timer(REVEAL_INITIAL_DELAY_SECONDS).timeout
	for index in reveal_blocks.size():
		if generation != reveal_generation or not is_inside_tree():
			return
		_reveal_block(index)
		await get_tree().create_timer(reveal_interval_seconds).timeout
	if generation != reveal_generation or not is_inside_tree():
		return
	_finish_reveal_sequence()


# 显示单个字段组并播放一次机械短音。
func _reveal_block(index: int) -> void:
	var block := reveal_blocks[index]
	block.visible = true
	block.modulate.a = 0.0
	block.position = reveal_origins[index] + REVEAL_OFFSET
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(block, "position", reveal_origins[index], REVEAL_SETTLE_SECONDS)
	tween.parallel().tween_property(block, "modulate:a", 1.0, REVEAL_SETTLE_SECONDS)
	revealed_block_count = index + 1
	status_line.text = "记录状态：正在生成 %02d / %02d" % [revealed_block_count, reveal_blocks.size()]
	Sfx.play("dialogue_tick")


# 完成逐块生成并开放声明勾选。
func _finish_reveal_sequence() -> void:
	reveal_sequence_finished = true
	declaration.disabled = false
	status_line.text = "记录状态：等待人员确认"


# 供自动化快照和调试直接展开完整日报；不会改变正常游戏中的默认节拍。
func reveal_all_blocks() -> void:
	reveal_generation += 1
	for index in reveal_blocks.size():
		var block := reveal_blocks[index]
		block.visible = true
		block.modulate.a = 1.0
		block.position = reveal_origins[index]
	revealed_block_count = reveal_blocks.size()
	_finish_reveal_sequence()


# 将当日统计、结算与政治评价汇总为多行文本，通过 RealityBridge 推送到外部展示端；桥不存在时静默跳过。
func _send_report_to_glass(day: int, summary: Dictionary, settlement: Dictionary) -> void:
	var bridge := get_tree().root.get_node_or_null("RealityBridge")
	if bridge == null:
		return
	(
		bridge
		. day_report(
			[
				(
					"形式审查：%d　批准：%d　驳回：%d"
					% [
						summary.reviewed,
						summary.approved,
						summary.rejected,
					]
				),
				(
					"程序错误：%d　现实生效：%d　等待处理：%d"
					% [
						summary.procedure_errors,
						summary.effective,
						summary.pending,
					]
				),
				(
					"日薪：%+d　绩效：%+d　罚款：-%d"
					% [
						settlement.base_salary,
						settlement.performance,
						settlement.fines,
					]
				),
				(
					"生活支出：-%d　本日结余：%+d"
					% [
						settlement.living_expenses,
						settlement.net,
					]
				),
				"政治评价：%s" % settlement.political_evaluation,
			],
			day,
			WorkdayState.report_title
		)
	)


# 玩家勾选或取消“已核对记录”声明时调用。
# 根据 pressed 状态启用或禁用确认按钮，并在状态栏提示“可结束工作日”或“等待人员确认”。
# 当处于封存过程中时，按钮仍保持禁用，避免重复提交。
func _on_declaration_toggled(pressed: bool) -> void:
	Sfx.play("ui_switch")
	confirm_button.disabled = not pressed or confirming or not reveal_sequence_finished
	if reveal_sequence_finished:
		status_line.text = "记录状态：可结束工作日" if pressed else "记录状态：等待人员确认"


# 玩家点击确认封存后执行。先校验声明已勾选且未处于封存中，设置 confirming 标志防止重复提交。
# 成功后进入下班地图；此时仍属于当前工作日，不提前结算或清除当日记录。
# 若场景切换失败则复位标志并提示“封存失败，请重试”。
func _on_confirm_pressed() -> void:
	if confirming or not declaration.button_pressed or not reveal_sequence_finished:
		return
	confirming = true
	Sfx.play("ui_click")
	confirm_button.disabled = true
	status_line.text = "记录状态：正在封存"
	WorkdayState.manager.begin_evening()
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
