class_name DocumentView
extends Panel

# 一份可展开、拖动、盖多枚章并重新装袋的正式文件。

const LOGICAL_SIZE := Vector2(640, 480)
const APPROVE_MARK := preload("res://assets/day1_8bit/interactive/approve_stamp.png")
const RETURN_MARK := preload("res://assets/day1_8bit/interactive/return_stamp.png")
const STAMP_DISPLAY_SIZE := Vector2(68, 82)

var document_id := ""
var document_type_id := ""
var is_primary := false
var stamp_records: Array[Dictionary] = []
var background: TextureRect


func configure(
	document_data: Dictionary,
	type_data: Dictionary,
	person_data: Dictionary,
	case_code: String
) -> void:
	document_id = String(document_data.get("id", ""))
	document_type_id = String(document_data.get("document_type_id", ""))
	is_primary = bool(type_data.get("is_primary", false))
	name = document_id if not document_id.is_empty() else "DocumentView"
	size = LOGICAL_SIZE
	pivot_offset = size / 2.0
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	set_meta("document_id", document_id)
	set_meta("document_type_id", document_type_id)
	add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color("d8cba7"), 0, Color("645a43"), 1)
	)

	background = TextureRect.new()
	background.name = "DocumentBackground"
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.position = Vector2.ZERO
	background.size = size
	var background_path := String(type_data.get("background", ""))
	if not background_path.is_empty():
		background.texture = load(background_path)
	add_child(background)

	var title_position := _vector(type_data.get("title_position", [44, 60]), Vector2(44, 60))
	var title_size := _vector(type_data.get("title_size", [490, 42]), Vector2(490, 42))
	var title := WorkbenchUI.add_text(
		self,
		String(document_data.get("title", type_data.get("name", "正式文件"))),
		22,
		WorkbenchUI.COLORS.ink,
		title_position,
		title_size
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var code_position := _vector(type_data.get("code_position", [520, 62]), Vector2(520, 62))
	var code_label := WorkbenchUI.add_text(
		self,
		case_code,
		12,
		Color("565647"),
		code_position,
		Vector2(92, 28)
	)
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var values: Dictionary = document_data.get("fields", {}).duplicate(true)
	if not person_data.is_empty():
		values["name"] = values.get("name", person_data.get("display_name", "身份受限"))
		values["citizen_id"] = person_data.get("citizen_id", "未登记")
	var field_layouts: Dictionary = type_data.get("fields", {})
	var fallback_index := 0
	for field_name in values:
		var layout: Dictionary = field_layouts.get(field_name, {})
		var position := _vector(
			layout.get("position", [72, 132 + fallback_index * 52]),
			Vector2(72, 132 + fallback_index * 52)
		)
		var dimensions := _vector(layout.get("size", [500, 42]), Vector2(500, 42))
		var label := String(layout.get("label", field_name))
		var value_text := _format_value(values[field_name])
		WorkbenchUI.add_text(
			self,
			"%s：%s" % [label, value_text],
			int(layout.get("font_size", 16)),
			WorkbenchUI.COLORS.ink,
			position,
			dimensions
		)
		fallback_index += 1


func add_stamp(kind: String, local_position: Vector2) -> Dictionary:
	var constrained := Vector2(
		clampf(local_position.x, 12.0, size.x - 12.0),
		clampf(local_position.y, 12.0, size.y - 12.0)
	)
	var order := stamp_records.size()
	var rotation_value := (-0.10 + float(order % 5) * 0.045)
	var record := {
		"kind": kind,
		"document_id": document_id,
		"position": [constrained.x, constrained.y],
		"rotation": rotation_value,
		"order": order,
	}
	stamp_records.append(record)

	var mark := TextureRect.new()
	mark.name = "StampMark%d" % order
	mark.texture = APPROVE_MARK if kind == "批准" else RETURN_MARK
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = STAMP_DISPLAY_SIZE
	mark.position = constrained - STAMP_DISPLAY_SIZE / 2.0
	mark.pivot_offset = STAMP_DISPLAY_SIZE / 2.0
	mark.rotation = rotation_value
	mark.modulate.a = 0.0
	mark.scale = Vector2(1.38, 1.38)
	add_child(mark)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mark, "scale", Vector2.ONE, 0.18)
	tween.tween_property(mark, "modulate:a", 0.9, 0.24)
	return record.duplicate(true)


func has_stamp_kind(kind: String) -> bool:
	return stamp_records.any(func(record): return String(record.get("kind", "")) == kind)


func has_stamp_conflict() -> bool:
	return has_stamp_kind("批准") and has_stamp_kind("驳回")


func _format_value(value: Variant) -> String:
	if value is bool:
		return "有效 / 已签署" if value else "无效 / 未签署"
	return str(value)


func _vector(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback
