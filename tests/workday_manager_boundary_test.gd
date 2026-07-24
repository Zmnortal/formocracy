extends SceneTree

# 验证工作日功能只通过同名 Manager 入口暴露，内部模块保持在统一文件夹。

const WorkdayStateScript := preload("res://scripts/autoload/workday_state.gd")
const REQUIRED_MANAGER_FILES: PackedStringArray = [
	"res://scripts/managers/workday_manager/workday_manager.gd",
	"res://scripts/managers/workday_manager/workday_context.gd",
	"res://scripts/managers/workday_manager/workday_clock_module.gd",
	"res://scripts/managers/workday_manager/workday_settlement_module.gd",
	"res://scripts/managers/workday_manager/workday_archive_module.gd",
	"res://scripts/managers/workday_manager/workday_personal_form_module.gd",
	"res://scripts/managers/workday_manager/workday_consequence_module.gd",
	"res://scripts/managers/workday_manager/workday_desk_layout_module.gd",
	"res://scripts/managers/workday_manager/workday_config_gateway.gd",
]
const FORBIDDEN_STATE_IMPLEMENTATIONS: PackedStringArray = [
	"ConfigDatabase.get_ontology",
	"archived_cases.append({",
	"seconds_remaining = maxf(0.0, seconds_remaining - delta)",
	"desk_item_layout[item_id]",
]


func _init() -> void:
	call_deferred("run")


func run() -> void:
	for path in REQUIRED_MANAGER_FILES:
		assert(FileAccess.file_exists(path), "manager module is missing: %s" % path)

	var state := WorkdayStateScript.new()
	state.reset_for_tests()
	state.seconds_remaining = 10.0
	state.manager.tick(1.5)
	assert(is_equal_approx(state.seconds_remaining, 8.5), "clock behavior must be exposed by WorkdayManager")

	state.manager.set_desk_item_layout("boundary-test", Vector2(42, 24), 3)
	var layout: Dictionary = state.manager.get_desk_item_layout("boundary-test")
	assert(layout.has("position"), "desk layout behavior must be exposed by WorkdayManager")

	var state_source := FileAccess.get_file_as_string("res://scripts/autoload/workday_state.gd")
	for implementation in FORBIDDEN_STATE_IMPLEMENTATIONS:
		assert(not state_source.contains(implementation), "business implementation leaked into WorkdayState: %s" % implementation)

	state.free()
	print("FORMOCRACY_WORKDAY_MANAGER_BOUNDARY_TEST_OK")
	quit(0)
