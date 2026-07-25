class_name WorkCalendarSchedule
extends RefCounted

# 中央现实管理局统一值勤历：第一日为礼拜一，做六休一。

const WORK_DAYS_PER_CYCLE := 6
const REST_DAYS_PER_CYCLE := 1
const CYCLE_LENGTH := WORK_DAYS_PER_CYCLE + REST_DAYS_PER_CYCLE
const CALENDAR_PAGE_DAYS := 35
const WEEKDAY_NAMES: Array[String] = [
	"礼拜一",
	"礼拜二",
	"礼拜三",
	"礼拜四",
	"礼拜五",
	"礼拜六",
	"礼拜日",
]


# 返回指定游戏日位于一周中的零基下标。
static func weekday_index(day_number: int) -> int:
	return posmod(maxi(day_number, 1) - 1, CYCLE_LENGTH)


# 返回指定游戏日的中文礼拜名。
static func weekday_name(day_number: int) -> String:
	return WEEKDAY_NAMES[weekday_index(day_number)]


# 每七日的最后一日为休息日。
static func is_rest_day(day_number: int) -> bool:
	return weekday_index(day_number) >= WORK_DAYS_PER_CYCLE


# 返回当前日处于第几个做六休一周期。
static func cycle_number(day_number: int) -> int:
	return (maxi(day_number, 1) - 1) / CYCLE_LENGTH + 1


# 返回当前日是本周期的第几个值勤日；休息日返回零。
static func duty_day_in_cycle(day_number: int) -> int:
	return 0 if is_rest_day(day_number) else weekday_index(day_number) + 1


# 返回包含指定日期的 35 日纸面页起始日。
static func calendar_page_start(day_number: int) -> int:
	return ((maxi(day_number, 1) - 1) / CALENDAR_PAGE_DAYS) * CALENDAR_PAGE_DAYS + 1
