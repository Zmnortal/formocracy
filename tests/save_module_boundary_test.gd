extends SceneTree

const SaveSchema := preload("res://scripts/save/save_schema.gd")
const REQUIRED_SAVE_FILES: PackedStringArray = [
	"res://scripts/save/save_repository.gd",
	"res://scripts/save/save_migrator.gd",
	"res://scripts/save/save_system.gd",
]


func _init() -> void:
	call_deferred("run")


func run() -> void:
	for file_path in REQUIRED_SAVE_FILES:
		assert(FileAccess.file_exists(file_path), "save module is missing: %s" % file_path)

	var source := FileAccess.get_file_as_string("res://scripts/autoload/workday_state.gd")
	assert(source.contains("const SAVE_TREE_VERSION := SaveSchema.CURRENT_VERSION"), "compatibility version must come from SaveSchema")
	var save_system_source := FileAccess.get_file_as_string("res://scripts/save/save_system.gd")
	assert(save_system_source.contains("var state: WorkdayContext"), "save system must accept the gameplay state host")
	for forbidden: String in [
		"FileAccess.",
		"DirAccess.",
		"JSON.",
		"_read_or_migrate_document",
		"_write_document_atomic",
		"_migrate_legacy_document",
	]:
		assert(not source.contains(forbidden), "WorkdayState must delegate persistence infrastructure: %s" % forbidden)

	print("FORMOCRACY_SAVE_MODULE_BOUNDARY_TEST_OK")
	quit(0)
