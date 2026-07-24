class_name WorkdayClockModule
extends RefCounted

# 管理工作日时间和缺水造成的操作惩罚。

var state: WorkdayContext


# 记录所属的工作日状态引用。
func _init(owner_state: WorkdayContext) -> void:
	state = owner_state


# 按帧递减剩余工作时间，不低于零。
func tick(delta: float) -> void:
	state.seconds_remaining = maxf(0.0, state.seconds_remaining - delta)


# 判断当日工作时间是否已耗尽。
func is_time_up() -> bool:
	return state.seconds_remaining <= 0.0


# 根据饮水覆盖情况设置缺水标记，并计算扣减惩罚后的新一天时长。
func prepare_new_workday() -> void:
	state.water_deprived = state.day_number > state.water_covered_until_day
	var time_penalty := 20.0 if state.water_deprived else 0.0
	state.seconds_remaining = maxf(60.0, state.workday_duration - time_penalty)


# 返回拖拽响应系数，缺水时降低。
func get_drag_response_multiplier() -> float:
	return 0.72 if state.water_deprived else 1.0
