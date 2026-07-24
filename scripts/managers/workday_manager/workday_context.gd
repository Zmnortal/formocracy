class_name WorkdayContext
extends Node

# 工作日各功能服务共享的强类型状态契约。
# 这里只保存运行时数据和服务需要调用的生命周期端口，不承载业务规则。

const CASES_PER_DAY := 3

var day_number := 1
var records: Array[Dictionary] = []
var save_path := "user://formocracy-save.json"
var current_level_id := "day_1"
var target_case_count := CASES_PER_DAY
var report_title := "工作日处理回执"
var player_name := ""
var reinstatement_date := ""
var player_signature: Array = []
var resume_loaded := false

var decision_by_case_id: Dictionary = {}
var persistence_enabled := true

var workday_duration := 180.0
var seconds_remaining := 180.0
var base_salary := 0
var living_expenses: Dictionary = {}
var balance := 0
var political_credit := 0
var delayed_consequences: Array[Dictionary] = []
var settled_day_number := 0
var machine_capacity := 2
var archived_cases: Array[Dictionary] = []
var next_archive_serial := 1
var desk_item_layout: Dictionary = {}

var evening_day_number := 0
var evening_actions_remaining := 2
var evening_location_id := "LOCATION-OFFICE"
var personal_form_inventory: Array[Dictionary] = []
var next_inventory_serial := 1
var water_covered_until_day := 1
var water_deprived := false
var last_personal_review_results: Array[Dictionary] = []

var active_checkpoint_id := ""


# 从动态字典边界安全读取字符串。
static func read_string(source: Dictionary, key: String, fallback := "") -> String:
	return stringify_value(source.get(key, fallback), fallback)


# 将动态值安全转换为字符串。
static func stringify_value(value: Variant, fallback := "") -> String:
	if value is String or value is StringName or value is NodePath:
		@warning_ignore("unsafe_call_argument")
		return String(value)
	return fallback


# 从动态字典边界安全读取整数。
static func read_int(source: Dictionary, key: String, fallback := 0) -> int:
	return to_int(source.get(key, fallback), fallback)


# 将动态值安全转换为整数。
static func to_int(value: Variant, fallback := 0) -> int:
	if value is int:
		@warning_ignore("unsafe_cast")
		return value
	if value is float:
		@warning_ignore("unsafe_call_argument")
		return int(value)
	return fallback


# 从动态字典边界安全读取浮点数。
static func read_float(source: Dictionary, key: String, fallback := 0.0) -> float:
	return to_float(source.get(key, fallback), fallback)


# 将动态值安全转换为浮点数。
static func to_float(value: Variant, fallback := 0.0) -> float:
	if value is float:
		@warning_ignore("unsafe_cast")
		return value
	if value is int:
		@warning_ignore("unsafe_call_argument")
		return float(value)
	return fallback


# 从动态字典边界安全读取布尔值。
static func read_bool(source: Dictionary, key: String, fallback := false) -> bool:
	return to_bool(source.get(key, fallback), fallback)


# 将动态值安全转换为布尔值。
static func to_bool(value: Variant, fallback := false) -> bool:
	if value is bool:
		@warning_ignore("unsafe_cast")
		return value
	return fallback


# 从动态字典边界安全复制数组。
static func read_array(source: Dictionary, key: String, fallback: Array = []) -> Array:
	var value: Variant = source.get(key, fallback)
	if value is Array:
		@warning_ignore("unsafe_cast")
		var typed_value: Array = value
		return typed_value.duplicate(true)
	return fallback.duplicate(true)


# 从动态字典边界安全复制字典。
static func read_dictionary(source: Dictionary, key: String, fallback: Dictionary = {}) -> Dictionary:
	var value: Variant = source.get(key, fallback)
	if value is Dictionary:
		@warning_ignore("unsafe_cast")
		var typed_value: Dictionary = value
		return typed_value.duplicate(true)
	return fallback.duplicate(true)


# 持久化端口，由 WorkdayState 门面实现。
func save_progress() -> bool:
	return false


# 快照端口，由 WorkdayState 门面实现。
func _capture_state() -> Dictionary:
	return {}


# 恢复端口，由 WorkdayState 门面实现。
func _apply_state(_state: Dictionary) -> void:
	pass


# 跨日端口，由 WorkdayState 门面实现。
func process_due_personal_forms() -> void:
	pass


# 新工作日准备端口，由 WorkdayState 门面实现。
func prepare_new_workday() -> void:
	pass


# 时间线检查点端口，由 WorkdayState 门面实现。
func create_checkpoint(_completed_day: int) -> bool:
	return false
