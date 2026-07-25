extends SceneTree

const Schedule := preload("res://scripts/gameplay/work_calendar_schedule.gd")


func _init() -> void:
	assert(Schedule.weekday_name(1) == "礼拜一")
	assert(Schedule.weekday_name(6) == "礼拜六")
	assert(Schedule.weekday_name(7) == "礼拜日")
	assert(Schedule.weekday_name(8) == "礼拜一")
	assert(not Schedule.is_rest_day(6))
	assert(Schedule.is_rest_day(7))
	assert(Schedule.is_rest_day(14))
	assert(Schedule.duty_day_in_cycle(7) == 0)
	assert(Schedule.duty_day_in_cycle(8) == 1)
	assert(Schedule.cycle_number(14) == 2)
	assert(Schedule.calendar_page_start(35) == 1)
	assert(Schedule.calendar_page_start(36) == 36)
	print("FORMOCRACY_WORK_CALENDAR_SCHEDULE_TEST_OK")
	quit()
