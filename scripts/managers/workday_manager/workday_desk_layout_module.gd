class_name WorkdayDeskLayoutModule
extends RefCounted

# 管理桌面物件的稳定落点和遮挡顺序。

var state: WorkdayContext


# 记录所属的工作日状态引用。
func _init(owner_state: WorkdayContext) -> void:
	state = owner_state


# 保存桌面物件的落点坐标与遮挡层级，必要时写入存档。
func set_item_layout(item_id: String, item_position: Vector2, layer: int) -> void:
	if item_id.is_empty():
		return
	state.desk_item_layout[item_id] = {
		"position": [item_position.x, item_position.y],
		"layer": layer,
	}
	if state.persistence_enabled:
		state.save_progress()


# 读取指定物件已保存的布局信息。
func get_item_layout(item_id: String) -> Dictionary:
	return WorkdayContext.read_dictionary(state.desk_item_layout, item_id)
