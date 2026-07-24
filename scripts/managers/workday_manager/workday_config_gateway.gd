class_name WorkdayConfigGateway
extends RefCounted

# 隔离 WorkdayManager 与 ConfigDatabase Autoload 的加载顺序。

var _state: WorkdayContext


func _init(state: WorkdayContext) -> void:
	_state = state


# 返回指定本体配置；配置库尚未进入场景树时返回空字典。
func get_ontology(table_name: String, row_id: String) -> Dictionary:
	var database := _get_database()
	if database == null:
		return {}
	var result: Variant = database.call("get_ontology", table_name, row_id)
	if result is Dictionary:
		@warning_ignore("unsafe_cast")
		var typed_result: Dictionary = result
		return typed_result
	return {}


# 运行案件规则评估；配置库尚未进入场景树时返回空字典。
func evaluate_gameplay_case(case_data: Dictionary) -> Dictionary:
	var database := _get_database()
	if database == null:
		return {}
	var result: Variant = database.call("evaluate_gameplay_case", case_data)
	if result is Dictionary:
		@warning_ignore("unsafe_cast")
		var typed_result: Dictionary = result
		return typed_result
	return {}


func _get_database() -> Node:
	if not _state.is_inside_tree():
		return null
	return _state.get_tree().root.get_node_or_null("ConfigDatabase")
