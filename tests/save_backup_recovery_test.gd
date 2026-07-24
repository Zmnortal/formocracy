extends SceneTree

# 验证主存档损坏时回退到 .bak，以及新游戏不会让旧备份复活。

const SaveSchema := preload("res://scripts/save/save_schema.gd")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState") as WorkdayContext
	var save_system_value: Variant = state.get("save_system")
	assert(save_system_value is Object, "WorkdayState must expose the save system")
	@warning_ignore("unsafe_cast")
	var save_system: Object = save_system_value
	var save_path := "user://formocracy-save-backup-recovery-test.json"
	state.save_path = save_path
	state.call("start_new_game")
	state.persistence_enabled = false
	state.player_name = "备份测试员"
	assert(save_system.call("create_initial_checkpoint") == true, "test must create a primary save")
	assert(state.save_progress(), "second write must rotate a valid backup")

	var primary := FileAccess.open(save_path, FileAccess.WRITE)
	assert(primary != null, "test must be able to corrupt the primary fixture")
	primary.store_string("{broken")
	primary.close()
	assert(save_system.call("has_save") == true, "a valid backup must still count as a loadable save")

	state.player_name = ""
	assert(save_system.call("load_progress") == true, "load must recover from the valid backup")
	assert(state.player_name == "备份测试员", "backup recovery must restore saved state")
	var repaired := FileAccess.open(save_path, FileAccess.READ)
	assert(repaired != null, "backup recovery must recreate the primary file")
	assert(JSON.parse_string(repaired.get_as_text()) is Dictionary, "recreated primary save must be valid JSON")

	state.call("start_new_game")
	assert(not FileAccess.file_exists(save_path), "new game must remove the primary save")
	assert(not FileAccess.file_exists(save_path + ".bak"), "new game must remove the backup save")
	assert(not FileAccess.file_exists(save_path + ".tmp"), "new game must remove temporary save data")
	assert(save_system.call("has_save") == false, "deleted backup must never resurrect an old game")

	state.save_path = SaveSchema.DEFAULT_PATH
	state.persistence_enabled = false
	print("FORMOCRACY_SAVE_BACKUP_RECOVERY_TEST_OK")
	quit(0)
