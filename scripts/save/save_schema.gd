class_name FormocracySaveSchema
extends RefCounted

# 存档格式的单一事实来源。

const CURRENT_VERSION := 7
const DEFAULT_PATH := "user://formocracy-save.json"


# 判断字典是否为合法存档（含节点或旧版 day_number 字段）。
static func is_loadable_document(document: Dictionary) -> bool:
	if document.is_empty():
		return false
	if document.has("nodes"):
		return document.get("nodes") is Array and document.get("working_state") is Dictionary
	return document.has("day_number")


# 创建一个空的存档树结构字典。
static func make_empty_tree(active_checkpoint_id: String = "") -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"nodes": [],
		"active_checkpoint_id": active_checkpoint_id,
		"working_state": {},
	}
