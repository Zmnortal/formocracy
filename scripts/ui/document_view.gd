class_name DocumentView
extends Panel

# 一份可展开、拖动、盖多枚章并重新装袋的正式文件。

const LOGICAL_SIZE := Vector2(640, 480)
const APPROVE_MARK := preload("res://assets/office/stamp_marks/approve_mark.png")
const REJECT_MARK := preload("res://assets/office/stamp_marks/reject_mark.png")
const CLEAN_PAPER := preload("res://assets/documents/common_document_bg.png")
const STAMP_DISPLAY_SIZE := Vector2(92, 92)
const VISUAL_POCKET := "pocket"
const VISUAL_DESK := "desk"
const VISUAL_INSPECTION := "inspection"
const HERO_FIELDS := ["request", "subject", "reason", "summary", "resource", "scope", "adjustment"]
const NATIVE_TITLE_FONT_SIZE := 30
const NATIVE_CASE_CODE_FONT_SIZE := 18
const NATIVE_FIELD_FONT_MULTIPLIER := 1.4
const NATIVE_FIELD_FONT_MINIMUM := 20
const USER_ZOOM_MIN := 0.8
const USER_ZOOM_MAX := 1.8
const USER_ZOOM_STEP := 0.1

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
var chrome: DocumentChrome
var selection_outline: Panel
var user_zoom := 1.0


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

	var values := WorkdayContext.read_dictionary(type_data, "prefill").duplicate(true)
	values.merge(WorkdayContext.read_dictionary(document_data, "fields"), true)
	if not person_data.is_empty():
		values["name"] = WorkdayContext.stringify_value(values.get("name"), WorkdayContext.read_string(person_data, "display_name", "身份受限"))
		values["citizen_id"] = WorkdayContext.read_string(person_data, "citizen_id", "未登记")
	if not _visual_spec(VISUAL_INSPECTION).is_empty():
		_build_native_inspection(document_data, type_data, person_data, case_code, values)
	else:
		_build_readable_inspection(document_data, type_data, person_data, case_code, values)

	stamp_layer = Control.new()
	stamp_layer.name = "DocumentStamps"
	stamp_layer.size = inspection_size
	stamp_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stamp_layer)
	_build_selection_outline()
	apply_visual_state(VISUAL_INSPECTION)


# 在该文件自己的查验态原图上填写标题、编号和字段，确保打开、桌面、袋内三态属于同一套材料。
func _build_native_inspection(document_data: Dictionary, type_data: Dictionary, person_data: Dictionary, case_code: String, values: Dictionary) -> void:
	var title_position := _vector(type_data.get("title_position", [44, 60]), Vector2(44, 60))
	var title_size := _vector(type_data.get("title_size", [490, 42]), Vector2(490, 42))
	var title_fallback := WorkdayContext.read_string(type_data, "name", "正式文件")
	var title := WorkbenchUI.add_text(content_layer, WorkdayContext.read_string(document_data, "title", title_fallback), NATIVE_TITLE_FONT_SIZE, WorkbenchUI.COLORS.ink, title_position, title_size)
	title.name = "DocumentTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_meta("document_font_role", "title")

	var code_position := _vector(type_data.get("code_position", [520, 62]), Vector2(520, 62))
	var code_label := WorkbenchUI.add_text(content_layer, _short_case_code(case_code), NATIVE_CASE_CODE_FONT_SIZE, Color("565647"), code_position, Vector2(120, 28))
	code_label.name = "DocumentCaseCode"
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_portrait(type_data, person_data)

	var field_layouts := WorkdayContext.read_dictionary(type_data, "fields")
	var fallback_index := 0
	for raw_field_name: Variant in values:
		var field_name := WorkdayContext.stringify_value(raw_field_name)
		var layout := WorkdayContext.read_dictionary(field_layouts, field_name)
		var position := _vector(layout.get("position", [72, 132 + fallback_index * 52]), Vector2(72, 132 + fallback_index * 52))
		var dimensions := _vector(layout.get("size", [500, 42]), Vector2(500, 42))
		var label := WorkdayContext.read_string(layout, "label", field_name)
		var configured_font_size := WorkdayContext.read_int(layout, "font_size", 16)
		var readable_font_size := maxi(NATIVE_FIELD_FONT_MINIMUM, roundi(float(configured_font_size) * NATIVE_FIELD_FONT_MULTIPLIER))
		var field_value := WorkbenchUI.add_text(content_layer, "%s：%s" % [label, _format_value(values[raw_field_name])], readable_font_size, WorkbenchUI.COLORS.ink, position, dimensions)
		field_value.name = "DocumentField_%s" % field_name
		field_value.set_meta("document_font_role", "native_field")
		fallback_index += 1


# 使用清爽纸张、类别色带、像素图标和大字号卡片建立统一的查验态信息层级。
func _build_readable_inspection(document_data: Dictionary, type_data: Dictionary, person_data: Dictionary, case_code: String, values: Dictionary) -> void:
	var clean_paper := TextureRect.new()
	clean_paper.name = "ReadablePaper"
	# 必须先忽略纹理原始尺寸，再设置节点尺寸；否则 1404px 素材会把 640px 表单撑宽。
	clean_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clean_paper.stretch_mode = TextureRect.STRETCH_SCALE
	clean_paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clean_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clean_paper.texture = CLEAN_PAPER
	clean_paper.position = Vector2.ZERO
	clean_paper.size = inspection_size
	content_layer.add_child(clean_paper)

	var visual_language := WorkdayContext.read_dictionary(type_data, "visual_language")
	var accent := Color.from_string(WorkdayContext.read_string(visual_language, "accent", "7a633e"), Color("7a633e"))
	var category := WorkdayContext.read_string(visual_language, "category", "行政事项")
	var icon_name := WorkdayContext.read_string(visual_language, "icon", "form")
	var compact := inspection_size.y < 560.0
	var margin := 28.0
	var header_height := 96.0 if compact else 128.0
	var footer_height := 72.0 if compact else 92.0

	chrome = DocumentChrome.new()
	chrome.name = "DocumentChrome"
	chrome.position = Vector2.ZERO
	chrome.size = inspection_size
	chrome.configure(accent, icon_name, header_height, footer_height)
	content_layer.add_child(chrome)

	var icon_space := clampf(header_height - 32.0, 52.0, 78.0) + 34.0
	var text_left := margin + icon_space
	var text_width := inspection_size.x - text_left - margin - 20.0
	var header_ink := Color("f7edcf")
	var category_label := WorkbenchUI.add_text(content_layer, category, 22 if compact else 26, Color(header_ink, 0.82), Vector2(text_left, margin + 11.0), Vector2(text_width, 34.0))
	category_label.name = "DocumentCategoryLabel"

	var title_fallback := WorkdayContext.read_string(type_data, "name", "正式文件")
	var title_text := WorkdayContext.read_string(document_data, "title", title_fallback)
	var title_font := 30 if compact else (34 if title_text.length() > 10 else 40)
	var title := WorkbenchUI.add_text(content_layer, title_text, title_font, header_ink, Vector2(text_left, margin + (35.0 if compact else 42.0)), Vector2(text_width, header_height - 42.0))
	title.name = "DocumentTitle"
	title.set_meta("document_font_role", "title")

	var code_label := WorkbenchUI.add_text(
		content_layer, _short_case_code(case_code), 20 if compact else 24, Color(header_ink, 0.76), Vector2(inspection_size.x - margin - 180.0, margin + 10.0), Vector2(164.0, 30.0)
	)
	code_label.name = "DocumentCaseCode"
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var footer_y := inspection_size.y - margin - footer_height
	var footer_label := WorkbenchUI.add_text(
		content_layer, "%s · 功能分类" % category, 20 if compact else 24, accent.darkened(0.18), Vector2(margin + 8.0, footer_y + 17.0), Vector2(inspection_size.x * 0.5, footer_height - 20.0)
	)
	footer_label.name = "DocumentFunctionLegend"
	var stamp_label := WorkbenchUI.add_text(
		content_layer, "核验章区", 20 if compact else 24, Color(accent, 0.72), Vector2(inspection_size.x * 0.7, footer_y + 17.0), Vector2(inspection_size.x * 0.23, footer_height - 20.0)
	)
	stamp_label.name = "DocumentStampZoneLabel"
	stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var entries := _field_entries(type_data, values)
	var body_rect := Rect2(Vector2(margin + 14.0, margin + header_height + 18.0), Vector2(inspection_size.x - (margin + 14.0) * 2.0, footer_y - (margin + header_height + 30.0)))
	_layout_field_cards(entries, type_data, person_data, body_rect, accent, compact)


# 按本体配置顺序组织字段，确保核心业务字段稳定出现在辅助元数据之前。
func _field_entries(type_data: Dictionary, values: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var included: Array[String] = []
	var field_layouts := WorkdayContext.read_dictionary(type_data, "fields")
	for raw_field_name: Variant in field_layouts:
		var field_name := WorkdayContext.stringify_value(raw_field_name)
		if not values.has(raw_field_name) and not values.has(field_name):
			continue
		var layout := WorkdayContext.read_dictionary(field_layouts, field_name)
		var value: Variant = values.get(raw_field_name, values.get(field_name))
		(
			entries
			. append(
				{
					"key": field_name,
					"label": WorkdayContext.read_string(layout, "label", field_name),
					"value": _format_value(value),
				}
			)
		)
		included.append(field_name)
	for raw_field_name: Variant in values:
		var field_name := WorkdayContext.stringify_value(raw_field_name)
		if included.has(field_name):
			continue
		entries.append({"key": field_name, "label": field_name, "value": _format_value(values[raw_field_name])})
	return entries


# 将核心事项作为通栏信息，其余核验字段排为无边框浅色卡片。
func _layout_field_cards(entries: Array[Dictionary], type_data: Dictionary, person_data: Dictionary, body_rect: Rect2, accent: Color, compact: bool) -> void:
	var hero: Dictionary = {}
	var remaining: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if hero.is_empty() and HERO_FIELDS.has(WorkdayContext.read_string(entry, "key")):
			hero = entry
		else:
			remaining.append(entry)

	var cursor_y := body_rect.position.y
	var available_width := body_rect.size.x
	if not hero.is_empty():
		var hero_height := minf(82.0 if compact else 112.0, body_rect.size.y * 0.28)
		_add_field_card(Rect2(body_rect.position, Vector2(available_width, hero_height)), hero, accent, true, compact)
		cursor_y += hero_height + (10.0 if compact else 14.0)

	var grid_position := Vector2(body_rect.position.x, cursor_y)
	var grid_height := body_rect.end.y - cursor_y
	var portrait_layout := WorkdayContext.read_dictionary(type_data, "portrait")
	if not portrait_layout.is_empty() and not _portrait_path(person_data).is_empty():
		var portrait_width := minf(160.0, available_width * 0.24)
		_add_portrait(type_data, person_data, Vector2(grid_position.x, grid_position.y), Vector2(portrait_width, grid_height))
		grid_position.x += portrait_width + 14.0
		available_width -= portrait_width + 14.0

	if remaining.is_empty():
		return
	var columns := 2 if available_width >= 420.0 else 1
	var rows := ceili(float(remaining.size()) / float(columns))
	var gap := 10.0 if compact else 12.0
	var card_width := (available_width - gap * float(columns - 1)) / float(columns)
	var card_height := (grid_height - gap * float(rows - 1)) / float(rows)
	for index in range(remaining.size()):
		var column := index % columns
		var row := index / columns
		var card_position := grid_position + Vector2(column * (card_width + gap), row * (card_height + gap))
		_add_field_card(Rect2(card_position, Vector2(card_width, card_height)), remaining[index], accent, false, compact)


# 添加一个仅以底色和左侧色条分组的字段卡，避免重新引入密集表格线。
func _add_field_card(rect: Rect2, entry: Dictionary, accent: Color, emphasis: bool, compact: bool) -> void:
	var card := ColorRect.new()
	card.name = "FieldCard_%s" % WorkdayContext.read_string(entry, "key", "field")
	card.position = rect.position
	card.size = rect.size
	card.color = Color(accent, 0.075 if not emphasis else 0.12)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.clip_contents = true
	content_layer.add_child(card)

	var bar := ColorRect.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(7.0 if not compact else 6.0, rect.size.y)
	bar.color = Color(accent, 0.82)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bar)

	var inset := 16.0 if compact else 18.0
	var label_font := 20 if compact else 24
	var value_font := 30 if emphasis else (28 if compact else 32)
	var value_text := WorkdayContext.read_string(entry, "value", "—")
	if value_text.length() > 18:
		value_font -= 4
	var label := WorkbenchUI.add_text(card, WorkdayContext.read_string(entry, "label", "字段"), label_font, accent.darkened(0.22), Vector2(inset, 6.0), Vector2(rect.size.x - inset - 8.0, 30.0))
	label.name = "FieldLabel"
	label.set_meta("document_font_role", "field_label")
	var value_top := 31.0 if compact else 36.0
	var value := WorkbenchUI.add_text(card, value_text, value_font, WorkbenchUI.COLORS.ink, Vector2(inset, value_top), Vector2(rect.size.x - inset - 8.0, maxf(rect.size.y - value_top - 4.0, 1.0)))
	value.name = "FieldValue"
	value.set_meta("document_font_role", "field_value")


# 案件代码可能同时包含长事项名称；表头只保留真正承担索引作用的短代码。
func _short_case_code(case_code: String) -> String:
	var short_code := case_code.get_slice("/", 0).strip_edges()
	if short_code.is_empty():
		short_code = case_code
	return short_code.left(12)


# 切换同一份文件的物理视觉状态；数据、字段与印章记录始终留在同一个 DocumentView。
func apply_visual_state(state: String) -> void:
	var next_state := state if [VISUAL_DESK, VISUAL_INSPECTION].has(state) else VISUAL_INSPECTION
	visual_state = next_state
	user_zoom = 1.0
	set_meta("desk_user_zoom", user_zoom)
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
	if is_instance_valid(selection_outline):
		selection_outline.size = size


# 构建材料选中框。边框属于文件自身，缩放和拖动时会始终贴合真实纸张边缘。
func _build_selection_outline() -> void:
	selection_outline = Panel.new()
	selection_outline.name = "SelectionOutline"
	selection_outline.position = Vector2.ZERO
	selection_outline.size = size
	selection_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 与材料父节点处于同一层，避免选中框把整体有效层级推过抓取上限 999。
	selection_outline.z_index = 0
	selection_outline.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color.TRANSPARENT, 2, Color("f1d06d"), 6))
	selection_outline.visible = false
	add_child(selection_outline)


# 显示或隐藏该材料的选中边框。
func set_selected(selected: bool) -> void:
	if is_instance_valid(selection_outline):
		selection_outline.visible = selected
	set_meta("document_selected", selected)


# 围绕材料视觉中心调整用户缩放，并同步桌面控制器使用的稳定比例。
func adjust_user_zoom(direction: int) -> bool:
	if direction == 0 or not visible:
		return false
	var next_zoom := clampf(user_zoom + USER_ZOOM_STEP * signi(direction), USER_ZOOM_MIN, USER_ZOOM_MAX)
	next_zoom = snappedf(next_zoom, USER_ZOOM_STEP)
	if is_equal_approx(next_zoom, user_zoom):
		return false

	var visual_center_global := get_global_transform() * (size * 0.5)
	var stored_base_value: Variant = get_meta("desk_base_scale", scale)
	var stored_base_scale: Vector2 = scale
	if stored_base_value is Vector2:
		stored_base_scale = stored_base_value as Vector2
	var canonical_scale: Vector2 = stored_base_scale / maxf(user_zoom, 0.001)
	var next_scale: Vector2 = canonical_scale * next_zoom
	user_zoom = next_zoom
	set_meta("desk_user_zoom", user_zoom)
	set_meta("desk_base_scale", next_scale)
	scale = next_scale

	# 兼容查验态中心枢轴与桌面态左上枢轴：缩放后把视觉中心校正回原位置。
	var parent_canvas := get_parent() as CanvasItem
	if is_instance_valid(parent_canvas):
		var parent_inverse := parent_canvas.get_global_transform().affine_inverse()
		var adjusted_center_global := get_global_transform() * (size * 0.5)
		position += parent_inverse * visual_center_global - parent_inverse * adjusted_center_global
	return true


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
func _add_portrait(type_data: Dictionary, person_data: Dictionary, override_position := Vector2(-1.0, -1.0), override_size := Vector2.ZERO) -> void:
	var portrait_layout := WorkdayContext.read_dictionary(type_data, "portrait")
	var portrait_path := _portrait_path(person_data)
	if portrait_layout.is_empty() or portrait_path.is_empty():
		return
	var portrait_texture := _load_texture(portrait_path)
	if portrait_texture == null:
		return
	var portrait := TextureRect.new()
	portrait.name = "DocumentPortrait"
	portrait.position = (override_position if override_position.x >= 0.0 and override_position.y >= 0.0 else _vector(portrait_layout.get("position", [0, 0]), Vector2.ZERO))
	portrait.size = (override_size if override_size.x > 0.0 and override_size.y > 0.0 else _vector(portrait_layout.get("size", [160, 200]), Vector2(160, 200)))
	portrait.texture = portrait_texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = (CanvasItem.TEXTURE_FILTER_LINEAR if not WorkdayContext.read_string(person_data, "standard_portrait_texture").is_empty() else CanvasItem.TEXTURE_FILTER_NEAREST)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.clip_contents = true
	portrait.modulate = Color(0.48, 0.45, 0.36, 0.82)
	content_layer.add_child(portrait)


# 身份证明优先使用由全身像中立帧统一裁切的标准头像；旧内容仍可回退到像素头像字段。
func _portrait_path(person_data: Dictionary) -> String:
	var standard_portrait := WorkdayContext.read_string(person_data, "standard_portrait_texture")
	return standard_portrait if not standard_portrait.is_empty() else WorkdayContext.read_string(person_data, "portrait_texture")


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
