extends SceneTree

# 验证主工作台场景只转发生命周期，完整玩法功能收口在同名 Manager 文件夹。

const REQUIRED_MANAGER_FILES: PackedStringArray = [
	"res://scripts/managers/workbench_manager/workbench_manager.gd",
	"res://scripts/managers/workbench_manager/workbench_case_sequence.gd",
	"res://scripts/managers/workbench_manager/workbench_case_presenter.gd",
	"res://scripts/managers/workbench_manager/workbench_input_module.gd",
	"res://scripts/managers/workbench_manager/workbench_stamp_module.gd",
	"res://scripts/managers/workbench_manager/workbench_submission_module.gd",
	"res://scripts/managers/workbench_manager/workbench_call_bell_module.gd",
	"res://scripts/managers/workbench_manager/workbench_briefing_director.gd",
	"res://scripts/managers/workbench_manager/workbench_briefing_module.gd",
	"res://scripts/managers/workbench_manager/workbench_npc_performance_module.gd",
	"res://scripts/managers/workbench_manager/workbench_batch_validation_module.gd",
]
const FORBIDDEN_SCENE_IMPLEMENTATIONS: PackedStringArray = [
	"DeskBuilder.new()",
	"WorkdayState.manager.tick",
	"LevelDirector.get_next_gameplay_case",
	"submission_finished.connect",
	"npc_performance.start_case",
]


func _init() -> void:
	call_deferred("run")


func run() -> void:
	for file_path in REQUIRED_MANAGER_FILES:
		assert(FileAccess.file_exists(file_path), "workbench manager module is missing: %s" % file_path)

	var scene_source := FileAccess.get_file_as_string("res://scripts/scenes/main.gd")
	assert(scene_source.contains("var manager: WorkbenchManager"), "main scene must expose exactly one workbench manager")
	for implementation in FORBIDDEN_SCENE_IMPLEMENTATIONS:
		assert(not scene_source.contains(implementation), "workbench implementation leaked into main scene: %s" % implementation)

	var manager_source := FileAccess.get_file_as_string("res://scripts/managers/workbench_manager/workbench_manager.gd")
	assert(manager_source.contains("func start()"), "manager must own workbench startup")
	assert(manager_source.contains("func process(delta: float)"), "manager must own workday ticking")
	assert(manager_source.contains("func shutdown()"), "manager must own workbench cleanup")

	print("FORMOCRACY_WORKBENCH_MANAGER_BOUNDARY_TEST_OK")
	quit(0)
