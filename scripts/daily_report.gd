extends Control

@onready var metadata_label: Label = $Terminal/Receipt/Metadata
@onready var stats_label: Label = $Terminal/Receipt/Stats/StatsText
@onready var cases_label: Label = $Terminal/Receipt/CasesText
@onready var declaration: CheckBox = $Terminal/Receipt/Declaration
@onready var confirm_button: Button = $Terminal/Receipt/ConfirmButton
@onready var status_line: Label = $Terminal/StatusLine

var confirming := false


func _ready() -> void:
	declaration.toggled.connect(_on_declaration_toggled)
	confirm_button.pressed.connect(_on_confirm_pressed)
	populate_report()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


func populate_report() -> void:
	var day: int = WorkdayState.day_number
	var summary: Dictionary = WorkdayState.get_summary()
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


func _on_declaration_toggled(pressed: bool) -> void:
	confirm_button.disabled = not pressed or confirming
	status_line.text = "记录状态：可结束工作日" if pressed else "记录状态：等待人员确认"


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


func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO
