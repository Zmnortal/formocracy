class_name CaseSequence
extends RefCounted

# 管理工作日级别的案件队列：启动工作日、依次取案件、或在满足条件时结束当天。

signal case_started(case_data: Dictionary)
signal day_finished

var case_index := -1
var current_case: Dictionary = {}


# 启动默认工作日的案件队列。
# accepting_new_cases 用于主脚本判断当天是否已超时。
func start_day(accepting_new_cases := true) -> void:
	if not LevelDirector.start_gameplay_workday():
		push_error("无法启动游戏工作日：%s" % "；".join(LevelDirector.runtime_errors))
		day_finished.emit()
		return
	advance(accepting_new_cases)


# 推进到下一件案件；若当天已结束则发射 day_finished。
func advance(accepting_new_cases := true) -> void:
	if WorkdayState.should_show_report() or not accepting_new_cases:
		day_finished.emit()
		return

	case_index += 1
	current_case = LevelDirector.get_next_gameplay_case()
	if current_case.is_empty():
		day_finished.emit()
		return

	case_started.emit(current_case)
