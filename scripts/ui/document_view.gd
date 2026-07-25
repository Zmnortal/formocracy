class_name DocumentView
extends Panel

# 一份可展开、拖动、盖多枚章并重新装袋的正式文件。

const LOGICAL_SIZE := Vector2(640, 480)
const APPROVE_MARK := preload("res://assets/office/stamp_marks/approve_mark.png")
const REJECT_MARK := preload("res://assets/office/stamp_marks/reject_mark.png")
const STAMP_DISPLAY_SIZE := Vector2(92, 92)
const VISUAL_POCKET := "pocket"
const VISUAL_DESK := "desk"
const VISUAL_INSPECTION := "inspection"

var document_id := ""
var document_type_id := ""
var is_primary := false
var stamp_records: Array[Dictionary] = []
var background: TextureRect
var visual_state := VISUAL_INSPECTION
var visual_specs: Dictionary = {}
var inspection_size := LOGICAL_SIZE
var fallback_background_path := ""
var content_layer: Control
var stamp_layer: Control


# 根据文件数据、类型布局与人员信息构建文件外观：底图、标题、案件编号与各字段文本。
func configure(document_data: Dictionary, type_data: Dictionary, person_data: Dictionary, case_code: String) -> void:
	document_id = WorkdayContext.read_string(document_data, "id")
	document_type_id = WorkdayContext.read_string(document_data, "document_type_id")
	is_primary = WorkdayContext.read_bool(type_data, "is_primary")
	visual_specs = WorkdayContext.read_dictionary(type_data, "visuals")
	fallback_background_path = WorkdayContext.read_string(type_data, "background")
	inspection_size = visual_size(VISUAL_INSPECTION)
	name = document_id if not document_id.is_empty() else "DocumentView"
	size = inspection_size
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
	add_child(background)

	content_layer = Control.new()
	content_layer.name = "DocumentContent"
	content_layer.size = inspection_size
	content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_layer)

	var title_position := _vector(type_data.get("title_position", [44, 60]), Vector2(44, 60))
	var title_size := _vector(type_data.get("title_size", [490, 42]), Vector2(490, 42))
	var title_fallback := WorkdayContext.read_string(type_data, "name", "正式文件")
	var title := WorkbenchUI.add_text(content_layer, WorkdayContext.read_string(document_data, "title", title_fallback), 22, WorkbenchUI.COLORS.ink, title_position, title_size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var code_position := _vector(type_data.get("code_position", [520, 62]), Vector2(520, 62))
	var code_label := WorkbenchUI.add_text(content_layer, case_code, 12, Color("565647"), code_position, Vector2(120, 28))
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_portrait(type_data, person_data)

	var values := WorkdayContext.read_dictionary(type_data, "prefill").duplicate(true)
	values.merge(WorkdayContext.read_dictionary(document_data, "fields"), true)
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
		WorkbenchUI.add_text(content_layer, "%s：%s" % [label, value_text], WorkdayContext.read_int(layout, "font_size", 16), WorkbenchUI.COLORS.ink, position, dimensions)
		fallback_index += 1

	stamp_layer = Control.new()
	stamp_layer.name = "DocumentStamps"
	stamp_layer.size = inspection_size
	stamp_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stamp_layer)
	apply_visual_state(VISUAL_INSPECTION)


# 切换同一份文件的物理视觉状态；数据、字段与印章记录始终留在同一个 DocumentView。
func apply_visual_state(state: String) -> void:
	var next_state := state if [VISUAL_DESK, VISUAL_INSPECTION].has(state) else VISUAL_INSPECTION
	visual_state = next_state
	var next_size := visual_size(next_state)
	size = next_size
	pivot_offset = size / 2.0
	background.position = Vector2.ZERO
	background.size = size
	background.texture = visual_texture(next_state)
	var state_scale := Vector2(next_size.x / maxf(inspection_size.x, 1.0), next_size.y / maxf(inspection_size.y, 1.0))
	content_layer.scale = state_scale
	content_layer.visible = next_state == VISUAL_INSPECTION
	stamp_layer.scale = state_scale


# 返回某一物理状态的独立纹理；旧配置缺少三态定义时退回通用背景。
func visual_texture(state: String) -> Texture2D:
	var spec := _visual_spec(state)
	var path := WorkdayContext.read_string(spec, "texture", fallback_background_path)
	return _load_texture(path) if not path.is_empty() else null


# 返回配置中的状态逻辑尺寸，旧类型继续兼容 640×480。
func visual_size(state: String) -> Vector2:
	var spec := _visual_spec(state)
	return _vector(spec.get("size", LOGICAL_SIZE), LOGICAL_SIZE)


# 为身份证等卡片文档绘制申请人照片，照片只在查验态显示。
func _add_portrait(type_data: Dictionary, person_data: Dictionary) -> void:
	var portrait_layout := WorkdayContext.read_dictionary(type_data, "portrait")
	var portrait_path := WorkdayContext.read_string(person_data, "portrait_texture")
	if portrait_layout.is_empty() or portrait_path.is_empty():
		return
	var portrait_texture := _load_texture(portrait_path)
	if portrait_texture == null:
		return
	var portrait := TextureRect.new()
	portrait.name = "DocumentPortrait"
	portrait.position = _vector(portrait_layout.get("position", [0, 0]), Vector2.ZERO)
	portrait.size = _vector(portrait_layout.get("size", [160, 200]), Vector2(160, 200))
	portrait.texture = portrait_texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.clip_contents = true
	portrait.modulate = Color(0.48, 0.45, 0.36, 0.82)
	content_layer.add_child(portrait)


# 读取指定状态的视觉配置。
func _visual_spec(state: String) -> Dictionary:
	return WorkdayContext.read_dictionary(visual_specs, state)


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
	stamp_layer.add_child(mark)

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
