extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.save_path = "user://formocracy-branching-save-test.json"
	state.start_new_game()
	state.player_name = "分支测试员"
	assert(state.create_initial_checkpoint(), "opening must create the initial checkpoint")
	var nodes: Array[Dictionary] = state.get_checkpoint_nodes()
	assert(nodes.size() == 1, "new timeline must begin with one root")
	assert(int(nodes[0].completed_day) == 0, "root must represent the beginning")
	var root_id := String(nodes[0].node_id)

	state.balance = 10
	state.begin_next_day()
	nodes = state.get_checkpoint_nodes()
	assert(nodes.size() == 2, "finishing day one must create its checkpoint")
	var day_one_id := find_node_id(nodes, 1, root_id)
	assert(not day_one_id.is_empty(), "day one must be a child of the beginning")

	state.balance = 20
	state.begin_next_day()
	nodes = state.get_checkpoint_nodes()
	var first_day_two_id := find_node_id(nodes, 2, day_one_id)
	assert(not first_day_two_id.is_empty(), "first playthrough must create day two")

	assert(state.load_checkpoint(day_one_id), "historical day one must load")
	assert(state.day_number == 2, "loading day one must resume at day two")
	state.balance = 99
	state.begin_next_day()
	nodes = state.get_checkpoint_nodes()
	var day_two_children := find_children(nodes, day_one_id, 2)
	assert(day_two_children.size() == 2, "replaying from day one must branch into a second day two")
	assert(day_two_children[0].node_id != day_two_children[1].node_id, "branches must retain unique ids")

	var delete_id := String(day_two_children[0].node_id)
	assert(state.delete_checkpoint(delete_id), "one branch must be deletable")
	nodes = state.get_checkpoint_nodes()
	assert(find_children(nodes, day_one_id, 2).size() == 1, "deleting one branch must preserve its sibling")
	assert(not state.delete_checkpoint(root_id), "the beginning root must never be deletable")

	state.start_new_game()
	state.save_path = state.DEFAULT_SAVE_PATH
	state.persistence_enabled = false
	print("FORMOCRACY_BRANCHING_SAVE_TEST_OK")
	quit(0)


func find_node_id(nodes: Array[Dictionary], completed_day: int, parent_id: String) -> String:
	for node in nodes:
		if int(node.completed_day) == completed_day and String(node.parent_id) == parent_id:
			return String(node.node_id)
	return ""


func find_children(nodes: Array[Dictionary], parent_id: String, completed_day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in nodes:
		if String(node.parent_id) == parent_id and int(node.completed_day) == completed_day:
			result.append(node)
	return result
