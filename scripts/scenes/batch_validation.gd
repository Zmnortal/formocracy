extends Node2D

# 日终送验是独立于工作台的完整场景；主场景在进入这里时已经释放。

const BatchValidationModule := preload("res://scripts/managers/workbench_manager/workbench_batch_validation_module.gd")
const DAILY_REPORT_SCENE := "res://scenes/daily_report.tscn"

var module: WorkbenchBatchValidationModule


func _ready() -> void:
	OpeningMusic.stop_opening(0.4)
	Sfx.stop_ambience()
	module = BatchValidationModule.new(self)
	module.finished.connect(_open_daily_report)
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	module.open()
	(
		GameStateSync
		. scene_changed(
			"batch_validation",
			"selecting",
			{
				"day": WorkdayState.day_number,
				"capacity": WorkdayState.machine_capacity,
				"pendingArchives": WorkdayState.manager.get_pending_archives().size(),
			}
		)
	)


func _fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO


func _open_daily_report() -> void:
	var error := get_tree().change_scene_to_file(DAILY_REPORT_SCENE)
	if error != OK and module != null:
		module.overlay.visible = true
		module.finishing = false
		module.leave_button.disabled = false
		module.machine_state_label.text = "日报生成失败"
		module.instruction_label.text = "送验记录已保留，请稍后重试"


func _exit_tree() -> void:
	Sfx.stop_conveyor()
	if get_viewport().size_changed.is_connected(_fit_to_window):
		get_viewport().size_changed.disconnect(_fit_to_window)
	module = null
