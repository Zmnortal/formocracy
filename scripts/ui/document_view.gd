class_name DocumentView
extends Panel

# 一份可展开、拖动、盖多枚章并重新装袋的正式文件。

const LOGICAL_SIZE := Vector2(640, 480)
const APPROVE_MARK := preload("res://assets/office/stamp_marks/approve_mark.png")
const REJECT_MARK := preload("res://assets/office/stamp_marks/reject_mark.png")
const STAMP_DISPLAY_SIZE := Vector2(92, 92)

var document_id := ""
var document_type_id := ""
var is_primary := false
var stamp_records: Array[Dictionary] = []
var background: TextureRect


# 根据文件数据、类型布局与人员信息构建文件外观：底图、标题、案件编号与各字段文本。
func configure(document_data: Dictionary, type_data: Dictionary, person_data: Dictionary, case_code: String) -> void:
	document_id = WorkdayContext.read_string(document_data, "id")
	document_type_id = WorkdayContext.read_string(document_data, "document_type_id")
	is_primary = WorkdayContext.read_bool(type_data, "is_primary")
	name = document_id if not document_id.is_empty() else "DocumentView"
	size = LOGICAL_SIZE
	pivot_offset = size / 2.0
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	set_meta("document_id", document_id)
	set_meta("document_type_id", document_type_id)
	add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color("d8cba7"), 0, Color("645a43"), 1))

	background = TextureRect.new()
	background.name = "DocumentBackground"
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.position = Vector2.ZERO
	background.size = size
	var background_path := WorkdayContext.read_string(type_data, "background")
	if not background_path.is_empty():
		background.texture = _load_texture(background_path)
	add_child(background)

	var title_position := _vector(type_data.get("title_position", [44, 60]), Vector2(44, 60))
	var title_size := _vector(type_data.get("title_size", [490, 42]), Vector2(490, 42))
	var title_fallback := WorkdayContext.read_string(type_data, "name", "正式文件")
	var title := WorkbenchUI.add_text(self, WorkdayContext.read_string(document_data, "title", title_fallback), 22, WorkbenchUI.COLORS.ink, title_position, title_size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var code_position := _vector(type_data.get("code_position", [520, 62]), Vector2(520, 62))
	var code_label := WorkbenchUI.add_text(self, case_code, 12, Color("565647"), code_position, Vector2(92, 28))
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var values := WorkdayContext.read_dictionary(document_data, "fields")
	if not person_data.is_empty():
		values["name"] = WorkdayContext.stringify_value(values.get("name"), WorkdayContext.read_string(person_data, "display_name", "身份受限"))
		values["citizen_id"] = WorkdayContext.read_string(person_data, "citizen_id", "未登记")
	var field_layouts := WorkdayContext.read_dictionary(type_data, "fields")
	var fallback_index := 0
	for field_name: Variant in values:
		var field_key := WorkdayContext.stringify_value(field_name)
		var layout_value: Variant = field_layouts.get(field_name, {})
		var layout: Dictionary = {}
		if layout_value is Dictionary:
			@warning_ignore("unsafe_cast")
			layout = layout_value
		var position := _vector(layout.get("position", [72, 132 + fallback_index * 52]), Vector2(72, 132 + fallback_index * 52))
		var dimensions := _vector(layout.get("size", [500, 42]), Vector2(500, 42))
		var label := WorkdayContext.read_string(layout, "label", field_key)
		var value_text := _format_value(values[field_name])
		WorkbenchUI.add_text(self, "%s：%s" % [label, value_text], WorkdayContext.read_int(layout, "font_size", 16), WorkbenchUI.COLORS.ink, position, dimensions)
		fallback_index += 1


# 在文件指定位置盖一枚章：记录印章数据并以回弹动画显示印记，返回记录副本。
func add_stamp(kind: String, local_position: Vector2) -> Dictionary:
	var constrained := Vector2(clampf(local_position.x, 12.0, size.x - 12.0), clampf(local_position.y, 12.0, size.y - 12.0))
	var order := stamp_records.size()
	var rotation_value := -0.10 + float(order % 5) * 0.045
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
	mark.texture = APPROVE_MARK if kind == "批准" else REJECT_MARK
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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


# 判断文件上是否已盖过指定种类的章。
func has_stamp_kind(kind: String) -> bool:
	for record: Dictionary in stamp_records:
		if WorkdayContext.read_string(record, "kind") == kind:
			return true
	return false


# 判断文件上是否同时盖有“批准”与“驳回”两种冲突印章。
func has_stamp_conflict() -> bool:
	return has_stamp_kind("批准") and has_stamp_kind("驳回")


# 将字段值格式化为显示文本，布尔值转换为签署状态描述。
func _format_value(value: Variant) -> String:
	if value is bool:
		return "有效 / 已签署" if value else "无效 / 未签署"
	return str(value)


# 将 Vector2/数组/字典形式的配置值统一转换为 Vector2，无法解析时返回回退值。
func _vector(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		@warning_ignore("unsafe_cast")
		var array_value: Array = value
		if array_value.size() >= 2:
			return Vector2(WorkdayContext.to_float(array_value[0], fallback.x), WorkdayContext.to_float(array_value[1], fallback.y))
	if value is Dictionary:
		@warning_ignore("unsafe_cast")
		var dictionary_value: Dictionary = value
		return Vector2(WorkdayContext.read_float(dictionary_value, "x", fallback.x), WorkdayContext.read_float(dictionary_value, "y", fallback.y))
	return fallback


# 加载并收窄文件背景贴图资源。
func _load_texture(path: String) -> Texture2D:
	var resource := ResourceLoader.load(path)
	return resource as Texture2D if resource is Texture2D else null
