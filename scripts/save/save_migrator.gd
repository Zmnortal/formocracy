class_name FormocracySaveMigrator
extends RefCounted

# 将旧格式转换为当前文档，并集中处理只在载入旧版本时需要的状态修复。

const SaveSchema := preload("res://scripts/save/save_schema.gd")


# 将旧版单存档迁移为新版树结构存档。
static func migrate_legacy_document(legacy: Dictionary, source_modified_time: int, new_checkpoint_id: Callable) -> Dictionary:
	var legacy_day := maxi(1, WorkdayContext.read_int(legacy, "day_number", 1))
	var completed_day := maxi(0, legacy_day - 1)
	var root_state := legacy.duplicate(true)
	root_state["day_number"] = 1
	root_state["records"] = []
	root_state["settled_day_number"] = 0
	root_state["evening_day_number"] = 0
	root_state["evening_actions_remaining"] = 2
	var root_id := WorkdayContext.stringify_value(new_checkpoint_id.call(0))
	var nodes: Array[Dictionary] = [
		{
			"node_id": root_id,
			"parent_id": "",
			"completed_day": 0,
			"branch_order": 0,
			"created_at": source_modified_time,
			"player_name": WorkdayContext.read_string(legacy, "player_name"),
			"state": root_state,
		}
	]
	var active_id := root_id
	if completed_day > 0:
		active_id = WorkdayContext.stringify_value(new_checkpoint_id.call(completed_day))
		(
			nodes
			. append(
				{
					"node_id": active_id,
					"parent_id": root_id,
					"completed_day": completed_day,
					"branch_order": 0,
					"created_at": source_modified_time,
					"player_name": WorkdayContext.read_string(legacy, "player_name"),
					"state": legacy.duplicate(true),
				}
			)
		)
	return {
		"version": SaveSchema.CURRENT_VERSION,
		"nodes": nodes,
		"active_checkpoint_id": active_id,
		"working_state": legacy.duplicate(true),
		"updated_at": int(Time.get_unix_time_from_system()),
	}


# 修复 v5 及更早版本可能产生的跨日卡死存档。
static func repair_exhausted_evening(state: WorkdayContext, save_version: int) -> bool:
	if (
		save_version > 5
		or state.evening_actions_remaining > 0
		or state.evening_day_number != state.day_number
		or state.settled_day_number != state.day_number
		or state.records.size() < state.target_case_count
	):
		return false
	state.day_number += 1
	state.records.clear()
	state.evening_day_number = state.day_number
	state.evening_actions_remaining = 2
	state.evening_location_id = "LOCATION-OFFICE"
	state.process_due_personal_forms()
	state.prepare_new_workday()
	return true
