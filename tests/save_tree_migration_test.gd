extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.save_path = "user://formocracy-save-tree-migration-test.json"
	state.start_new_game()
	var legacy: Dictionary = state._capture_state()
	legacy.version = 6
	legacy.day_number = 4
	legacy.player_name = "旧档案经办员"
	legacy.balance = 46
	var file := FileAccess.open(state.save_path, FileAccess.WRITE)
	assert(file != null, "legacy fixture must be writable")
	file.store_string(JSON.stringify(legacy))
	file.close()

	assert(state.load_progress(), "legacy single save must migrate and load")
	assert(state.day_number == 4, "migration must preserve the in-progress workday")
	assert(state.balance == 46, "migration must preserve gameplay state")
	var nodes: Array[Dictionary] = state.get_checkpoint_nodes()
	assert(nodes.size() == 2, "day four legacy progress must migrate to beginning plus completed day three")
	assert(int(nodes[0].completed_day) == 0, "migration must synthesize the beginning root")
	assert(int(nodes[1].completed_day) == 3, "migration must preserve the last completed day")
	assert(String(nodes[1].parent_id) == String(nodes[0].node_id), "migrated completed day must descend from the root")
	assert(FileAccess.file_exists(state.save_path + ".bak"), "migration must retain the legacy file as a backup")

	state.start_new_game()
	state.save_path = state.DEFAULT_SAVE_PATH
	state.persistence_enabled = false
	print("FORMOCRACY_SAVE_TREE_MIGRATION_TEST_OK")
	quit(0)
