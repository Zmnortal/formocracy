extends SceneTree

const SaveSchema := preload("res://scripts/save/save_schema.gd")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState") as WorkdayContext
	var save_system_value: Variant = state.get("save_system")
	assert(save_system_value is Object, "WorkdayState must expose the save system")
	@warning_ignore("unsafe_cast")
	var save_system: Object = save_system_value
	var save_path := "user://formocracy-save-tree-migration-test.json"
	state.save_path = save_path
	state.call("start_new_game")
	var legacy := state._capture_state()
	legacy.version = 6
	legacy.day_number = 4
	legacy.player_name = "旧档案经办员"
	legacy.balance = 46
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	assert(file != null, "legacy fixture must be writable")
	file.store_string(JSON.stringify(legacy))
	file.close()

	assert(save_system.call("load_progress") == true, "legacy single save must migrate and load")
	assert(state.day_number == 4, "migration must preserve the in-progress workday")
	assert(state.balance == 46, "migration must preserve gameplay state")
	var nodes_value: Variant = save_system.call("get_checkpoint_nodes")
	assert(nodes_value is Array, "save system must return checkpoint nodes")
	@warning_ignore("unsafe_cast")
	var nodes: Array = nodes_value
	assert(nodes.size() == 2, "day four legacy progress must migrate to beginning plus completed day three")
	var root_node: Dictionary = nodes[0]
	var completed_node: Dictionary = nodes[1]
	assert(WorkdayContext.read_int(root_node, "completed_day") == 0, "migration must synthesize the beginning root")
	assert(WorkdayContext.read_int(completed_node, "completed_day") == 3, "migration must preserve the last completed day")
	assert(WorkdayContext.read_string(completed_node, "parent_id") == WorkdayContext.read_string(root_node, "node_id"), "migrated completed day must descend from the root")
	assert(FileAccess.file_exists(save_path + ".bak"), "migration must retain the legacy file as a backup")

	state.call("start_new_game")
	state.save_path = SaveSchema.DEFAULT_PATH
	state.persistence_enabled = false
	print("FORMOCRACY_SAVE_TREE_MIGRATION_TEST_OK")
	quit(0)
