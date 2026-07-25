extends SceneTree


func _init() -> void:
	call_deferred("_open_preview")


func _open_preview() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.player_name = "预览职员"
	state.balance = 20
	state.manager.begin_evening()
	var error := change_scene_to_file("res://scenes/central_forms_scene.tscn")
	assert(error == OK)
