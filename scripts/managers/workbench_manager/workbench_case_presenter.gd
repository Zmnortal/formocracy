class_name WorkbenchCasePresenter
extends RefCounted

# 单个案件的文件袋、文件视图、缩略图、印章和实时容器状态。

const ENVELOPE_DESK_SIDE := preload("res://assets/documents/envelopes/bureau_envelope_desk_side.png")
const ENVELOPE_CLOSED := preload("res://assets/documents/envelopes/bureau_envelope_closed.png")
const ENVELOPE_UNSTRUNG := preload("res://assets/documents/envelopes/bureau_envelope_unstrung.png")
const ENVELOPE_OPEN_EMPTY := preload("res://assets/documents/envelopes/bureau_envelope_open_empty.png")
const ENVELOPE_OUTLINE_SHADER := preload("res://shaders/envelope_outline.gdshader")
const ENVELOPE_DRAG_SURFACE := preload("res://scripts/ui/envelope_drag_surface.gd")
const DOCUMENT_INSPECTION_SCALE := Vector2(0.36, 0.36)
const DOCUMENT_DESK_SCALE := Vector2(0.36, 0.28)
const DOCUMENT_PEEK_SCALE := Vector2(0.17, 0.17)
const DOCUMENT_INSPECTION_POSITION := Vector2(340, 78)
const DOCUMENT_INSPECTION_RIGHT_BOUND := 748.0
const ENVELOPE_DESK_SIZE := Vector2(180, 126)
const ENVELOPE_BILLBOARD_SIZE := Vector2(500, 620)
const ENVELOPE_DELIVERY_POSITION := Vector2(550, 420)
const ENVELOPE_DESK_POSITION := Vector2(550, 548)
const ENVELOPE_BILLBOARD_POSITION := Vector2(390, 48)
const ENVELOPE_DESK_LAYER := 12
const INSPECTION_DISMISS_LAYER := 43
const ENVELOPE_BILLBOARD_LAYER := 44
const ENVELOPE_TRANSITION_DURATION := 0.24
const ENVELOPE_OPEN_FRAME_DURATION := 0.08
const DOCUMENT_EXTRACT_DURATION := 0.28
const DOCUMENT_RAISE_DURATION := 0.22
const ENVELOPE_FRONT_POSITION := Vector2(48, 200)
const ENVELOPE_FRONT_SIZE := Vector2(405, 420)
const ENVELOPE_POCKET_WINDOW_POSITION := Vector2(86, 132)
const ENVELOPE_POCKET_WINDOW_SIZE := Vector2(328, 68)
const ENVELOPE_POCKET_EXPOSED_HEIGHT := 38.0
const ENVELOPE_POCKET_STACK_OFFSET_X := 10.0
const ENVELOPE_VISIBLE_BOUNDS := Rect2(82, 30, 348, 559)
# 文件袋父节点可以在抓取时占用 999；其余桌面物件会依次降到 998、997……
# 全部视觉子节点统一固定在父节点 -2，因此封皮最高只能是 997：
# 既严格小于 999，也不会与重新计算后的最前普通物件（998）发生并列抢占。
const ENVELOPE_ATOMIC_CONTENT_LAYER := -2
const ENVELOPE_REPACK_ZONE := [
	Vector2(86, 136),
	Vector2(414, 136),
	Vector2(250, 248),
]

var root: Node2D
var desk: DeskNodes
var desk_items: DeskItemController

var current_case: Dictionary = {}
var form: DocumentView
var document_panels: Array[Panel] = []
var all_document_views: Array[DocumentView] = []
var document_by_id: Dictionary = {}
var thumbnail_by_id: Dictionary = {}

var envelope: Panel
var envelope_image: TextureRect
var envelope_outline_material: ShaderMaterial
var envelope_repack_outline: Panel
var envelope_front_cover: TextureRect
var envelope_case_label: Label
var envelope_flap: Button
var envelope_drag_handle: Button
var thumbnail_tray: Panel
var inspection_dismiss_layer: Control
var envelope_opened := false
var envelope_on_desk := false
var envelope_billboard_expanded := false
var envelope_transitioning := false
var envelope_desk_position := ENVELOPE_DESK_POSITION
var packed_document_ids: Array[String] = []
var pocket_stack_ids: Array[String] = []
var primary_document_id := ""

var form_stamped := false
var form_stamp_type := ""
var stamp_records: Array[Dictionary] = []
var next_document_layer := 14
var case_started_at := 0.0


# 初始化案件呈现器，绑定根节点与桌面节点引用。
func _init(owner_root: Node2D, owner_desk: DeskNodes, item_controller: DeskItemController = null) -> void:
	root = owner_root
	desk = owner_desk
	desk_items = item_controller


# 开始展示新案件：清理旧案件、设置申请人信息、创建文档与信封。
func start_case(data: Dictionary) -> void:
	clear_case()
	current_case = data
	case_started_at = Time.get_ticks_msec() / 1000.0

	if current_case.is_empty():
		if is_instance_valid(desk.applicant_card_label):
			desk.applicant_card_label.text = "配置错误\n未能生成当前案件"
		if is_instance_valid(desk.status_label):
			desk.status_label.text = "无法生成案件，请打开 DEV 控制台检查配置。"
		return

	if is_instance_valid(desk.applicant_card_label):
		desk.applicant_card_label.text = (
			"%s\n%s\n%s"
			% [
				WorkdayContext.read_string(current_case, "applicant", "身份受限"),
				WorkdayContext.read_string(current_case, "code", "未编号"),
				WorkdayContext.read_string(current_case, "department", "部门未登记"),
			]
		)
	var person := WorkdayContext.read_dictionary(current_case, "person")
	if is_instance_valid(desk.queue_label):
		var display_name := WorkdayContext.read_string(person, "display_name", "身份受限")
		desk.queue_label.text = "%s\n窗口就位\n后续排队：%d 人" % [display_name, LevelDirector.get_gameplay_queue().size()]
	Sfx.play_voice(WorkdayContext.read_string(person, "id"))

	_create_documents(WorkdayContext.read_array(current_case, "documents"))
	_create_envelope()
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "申请人已递交封存文件袋。"


# 清理当前案件的所有节点与状态。
func clear_case() -> void:
	if is_instance_valid(inspection_dismiss_layer):
		inspection_dismiss_layer.visible = false
		inspection_dismiss_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inspection_dismiss_layer.queue_free()
	if is_instance_valid(envelope):
		envelope.queue_free()
	for document in all_document_views:
		if is_instance_valid(document):
			document.queue_free()
	form = null
	document_panels.clear()
	all_document_views.clear()
	document_by_id.clear()
	thumbnail_by_id.clear()
	packed_document_ids.clear()
	pocket_stack_ids.clear()
	stamp_records.clear()
	primary_document_id = ""
	form_stamped = false
	form_stamp_type = ""
	envelope_opened = false
	envelope_on_desk = false
	envelope_billboard_expanded = false
	envelope_transitioning = false
	envelope_desk_position = ENVELOPE_DESK_POSITION
	envelope_outline_material = null
	envelope_repack_outline = null
	inspection_dismiss_layer = null
	next_document_layer = 14


# 根据案件数据创建所有 DocumentView 文件面板。
func _create_documents(raw_documents: Array) -> void:
	var index := 0
	for raw_document: Variant in raw_documents:
		if not raw_document is Dictionary:
			continue
		@warning_ignore("unsafe_cast")
		var document_data: Dictionary = raw_document
		var type_data := ConfigDatabase.get_ontology("document_types", WorkdayContext.read_string(document_data, "document_type_id"))
		var document := DocumentView.new()
		document.configure(document_data, type_data, WorkdayContext.read_dictionary(current_case, "person"), WorkdayContext.read_string(current_case, "code"))
		var inspection_position := _inspection_position_for(document, index)
		document.position = inspection_position
		document.scale = DOCUMENT_INSPECTION_SCALE
		document.set_meta("inspection_position", inspection_position)
		document.set_meta("document_state", "BAG")
		document.set_meta("desk_base_scale", DOCUMENT_INSPECTION_SCALE)
		document.z_index = next_document_layer + index
		document.visible = false
		root.add_child(document)

		all_document_views.append(document)
		document_by_id[document.document_id] = document
		packed_document_ids.append(document.document_id)
		pocket_stack_ids.append(document.document_id)
		if document.is_primary:
			form = document
			primary_document_id = document.document_id
		else:
			document_panels.append(document)
		index += 1

	if form == null and not all_document_views.is_empty():
		form = all_document_views[0]
		form.is_primary = true
		primary_document_id = form.document_id


# 根据每类文件真实长宽比安排查验位置，避免横向卡片遮住桌面右侧印章工具。
func _inspection_position_for(document: DocumentView, index: int) -> Vector2:
	var position := DOCUMENT_INSPECTION_POSITION + Vector2(index * 24, index * 18)
	var pivot_to_right_edge := document.size.x * 0.5 * (1.0 + DOCUMENT_INSPECTION_SCALE.x)
	position.x = minf(position.x, DOCUMENT_INSPECTION_RIGHT_BOUND - pivot_to_right_edge)
	return position


# 创建并递送案件信封，包含封口按钮、缩略图托盘与案件标签。
func _create_envelope() -> void:
	_create_inspection_dismiss_layer()
	envelope = Panel.new()
	envelope.name = "CaseEnvelope"
	envelope.position = ENVELOPE_DELIVERY_POSITION
	envelope.size = ENVELOPE_DESK_SIZE
	envelope.z_index = ENVELOPE_DESK_LAYER
	envelope.mouse_default_cursor_shape = Control.CURSOR_ARROW
	envelope.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color.TRANSPARENT, 0))
	root.add_child(envelope)

	envelope_image = TextureRect.new()
	envelope_image.name = "EnvelopeImage"
	envelope_image.texture = ENVELOPE_DESK_SIDE
	envelope_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	envelope_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	envelope_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	envelope_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	envelope_outline_material = ShaderMaterial.new()
	envelope_outline_material.shader = ENVELOPE_OUTLINE_SHADER
	envelope_outline_material.set_shader_parameter("outline_enabled", false)
	envelope_image.material = envelope_outline_material
	envelope.add_child(envelope_image)

	envelope_repack_outline = Panel.new()
	envelope_repack_outline.name = "EnvelopeRepackOutline"
	envelope_repack_outline.position = ENVELOPE_VISIBLE_BOUNDS.position
	envelope_repack_outline.size = ENVELOPE_VISIBLE_BOUNDS.size
	envelope_repack_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope_repack_outline.visible = false
	envelope_repack_outline.z_index = ENVELOPE_ATOMIC_CONTENT_LAYER
	envelope_repack_outline.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color.TRANSPARENT, 8, Color.WHITE, 3))
	envelope.add_child(envelope_repack_outline)

	envelope_case_label = (
		WorkbenchUI
		. add_text(
			envelope,
			(
				"%s\n%s"
				% [
					current_case.get("applicant", "身份受限"),
					current_case.get("code", "未编号"),
				]
			),
			6,
			Color("34362c"),
			Vector2(18, 86),
			Vector2(144, 30)
		)
	)
	envelope_case_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	envelope_case_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	envelope_case_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope_case_label.z_index = ENVELOPE_ATOMIC_CONTENT_LAYER

	envelope_flap = Button.new()
	envelope_flap.name = "EnvelopeUpperOpenHitArea"
	envelope_flap.text = ""
	envelope_flap.tooltip_text = "点击圆环或上部封盖拆开文件袋"
	envelope_flap.disabled = true
	envelope_flap.visible = false
	envelope_flap.z_index = ENVELOPE_ATOMIC_CONTENT_LAYER
	envelope_flap.focus_mode = Control.FOCUS_NONE
	envelope_flap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var transparent_button := WorkbenchUI.style_box(Color.TRANSPARENT, 0)
	envelope_flap.add_theme_stylebox_override("normal", transparent_button)
	envelope_flap.add_theme_stylebox_override("hover", transparent_button)
	envelope_flap.add_theme_stylebox_override("pressed", transparent_button)
	envelope_flap.add_theme_stylebox_override("disabled", transparent_button)
	envelope.add_child(envelope_flap)
	CursorManager.watch(envelope_flap, CursorManager.Cursor.OPEN_ENVELOPE)
	envelope_flap.button_down.connect(_on_flap_pressed)

	thumbnail_tray = Panel.new()
	thumbnail_tray.name = "DocumentPocketContents"
	thumbnail_tray.visible = false
	thumbnail_tray.z_index = ENVELOPE_ATOMIC_CONTENT_LAYER
	thumbnail_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail_tray.clip_contents = true
	thumbnail_tray.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color.TRANSPARENT, 0))
	envelope.add_child(thumbnail_tray)
	_create_thumbnails()

	envelope_front_cover = TextureRect.new()
	envelope_front_cover.name = "EnvelopeFrontPocketCover"
	envelope_front_cover.position = ENVELOPE_FRONT_POSITION
	envelope_front_cover.size = ENVELOPE_FRONT_SIZE
	envelope_front_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	envelope_front_cover.stretch_mode = TextureRect.STRETCH_SCALE
	envelope_front_cover.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	envelope_front_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope_front_cover.z_index = ENVELOPE_ATOMIC_CONTENT_LAYER
	envelope_front_cover.visible = false
	envelope.add_child(envelope_front_cover)

	envelope_drag_handle = ENVELOPE_DRAG_SURFACE.new()
	envelope_drag_handle.name = "EnvelopeDragHandle"
	envelope_drag_handle.text = ""
	envelope_drag_handle.tooltip_text = "拖动文件袋"
	envelope_drag_handle.visible = false
	envelope_drag_handle.z_index = ENVELOPE_ATOMIC_CONTENT_LAYER
	envelope_drag_handle.focus_mode = Control.FOCUS_NONE
	envelope_drag_handle.mouse_default_cursor_shape = Control.CURSOR_DRAG
	envelope_drag_handle.set("hit_test", _envelope_drag_surface_has_point)
	var drag_handle_style := WorkbenchUI.style_box(Color.TRANSPARENT, 0)
	envelope_drag_handle.add_theme_stylebox_override("normal", drag_handle_style)
	envelope_drag_handle.add_theme_stylebox_override("hover", drag_handle_style)
	envelope_drag_handle.add_theme_stylebox_override("pressed", drag_handle_style)
	envelope.add_child(envelope_drag_handle)
	_order_envelope_atomic_layers()


# 当前指针下若存在更前方的文件或桌面道具，封皮拖拽面主动退出 GUI 命中。
func _envelope_drag_surface_has_point(surface: Control, local_point: Vector2) -> bool:
	if desk_items == null:
		return true
	var global_point := surface.get_global_transform() * local_point
	var frontmost := desk_items._frontmost_item_at_global(global_point)
	return not is_instance_valid(frontmost) or frontmost == envelope


# 文件袋对外只占父节点的一个 Z-index；所有视觉子节点绑定在同一相对层。
# 父节点抓取上限是 999，所以这里强制为 -2 后，有效层级最高为 997。
# 文件袋内部的前后关系只由节点顺序决定，禁止再使用“父层级 + N”的算法。
func _order_envelope_atomic_layers() -> void:
	for child_node: Node in envelope.get_children():
		if child_node is CanvasItem:
			var child := child_node as CanvasItem
			child.z_as_relative = true
			child.z_index = ENVELOPE_ATOMIC_CONTENT_LAYER
	envelope.move_child(envelope_image, 0)
	envelope.move_child(thumbnail_tray, 1)
	envelope.move_child(envelope_front_cover, 2)
	envelope.move_child(envelope_case_label, 3)
	envelope.move_child(envelope_flap, 4)
	envelope.move_child(envelope_drag_handle, 5)
	envelope.move_child(envelope_repack_outline, 6)


# 创建查验态标记层；实际袋外点击由主场景的未处理输入接收，避免透明层拦住桌面工具。
func _create_inspection_dismiss_layer() -> void:
	inspection_dismiss_layer = Control.new()
	inspection_dismiss_layer.name = "EnvelopeInspectionDismissLayer"
	inspection_dismiss_layer.position = Vector2.ZERO
	inspection_dismiss_layer.size = DeskGeometry.design_size()
	inspection_dismiss_layer.z_index = INSPECTION_DISMISS_LAYER
	inspection_dismiss_layer.visible = false
	inspection_dismiss_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inspection_dismiss_layer)


# 处理未被桌面物件消费的输入；点击空白区域时收回查验层。
func handle_unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button: InputEventMouseButton = event
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
		lower_raised_documents_to_desk()
		if envelope_billboard_expanded:
			collapse_envelope_billboard()
		else:
			_refresh_inspection_dismiss_layer()


# 为每份真实案件文件创建袋口预览；这些预览替代原始组图中的假文件占位。
func _create_thumbnails() -> void:
	var index := 0
	var raw_documents := WorkdayContext.read_array(current_case, "documents")
	for document in all_document_views:
		var thumbnail := Button.new()
		thumbnail.name = "PocketDocument_%s" % document.document_id
		thumbnail.position = Vector2(34, 32)
		thumbnail.size = Vector2(150, 110)
		thumbnail.pivot_offset = thumbnail.size * 0.5
		thumbnail.rotation = -0.04
		thumbnail.z_index = 0
		thumbnail.icon = document.visual_texture(DocumentView.VISUAL_POCKET)
		thumbnail.expand_icon = true
		thumbnail.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		thumbnail.focus_mode = Control.FOCUS_NONE
		thumbnail.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var title := "正式文件"
		if index < raw_documents.size() and raw_documents[index] is Dictionary:
			@warning_ignore("unsafe_cast")
			var document_data: Dictionary = raw_documents[index]
			title = WorkdayContext.read_string(document_data, "title", title)
		thumbnail.tooltip_text = "抽出：%s" % title
		thumbnail.set_meta("document_id", document.document_id)
		var preview_normal := WorkbenchUI.style_box(Color.TRANSPARENT, 0)
		var preview_hover := WorkbenchUI.style_box(Color(0.95, 0.86, 0.60, 0.12), 1, WorkbenchUI.COLORS.green_glow, 2)
		thumbnail.add_theme_stylebox_override("normal", preview_normal)
		thumbnail.add_theme_stylebox_override("hover", preview_hover)
		thumbnail.add_theme_stylebox_override("pressed", preview_hover)
		thumbnail.pressed.connect(open_document.bind(document.document_id))
		thumbnail_tray.add_child(thumbnail)
		thumbnail_by_id[document.document_id] = thumbnail
		index += 1


# 信封封口被按下时，若已放置在工作台上则拆封。
func _on_flap_pressed() -> void:
	if envelope_on_desk and envelope_billboard_expanded:
		open_envelope()


# 设置信封是否已放置到工作台上，并更新封口按钮状态。
func set_envelope_on_desk(value: bool) -> void:
	envelope_on_desk = value
	if is_instance_valid(envelope_flap):
		envelope_flap.disabled = not value or not envelope_billboard_expanded


# 点击桌面平放文件袋后，将其放大到遮挡 NPC 的 billboard 交互层。
func expand_envelope_billboard() -> void:
	if not envelope_on_desk or envelope_billboard_expanded or envelope_transitioning:
		return
	envelope_transitioning = true
	envelope_billboard_expanded = true
	envelope_desk_position = envelope.position
	inspection_dismiss_layer.visible = true
	envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope.set_meta("desk_drag_locked", false)
	envelope.set_meta("context_cursor", CursorManager.Cursor.GRAB)
	if desk_items != null:
		desk_items.focus_item(envelope)
	else:
		envelope.z_index = ENVELOPE_BILLBOARD_LAYER
	envelope_image.texture = ENVELOPE_OPEN_EMPTY if envelope_opened else ENVELOPE_CLOSED
	_layout_billboard_controls()
	Sfx.play("ui_switch")

	var expand := root.create_tween().set_parallel(true)
	expand.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	expand.tween_property(envelope, "position", ENVELOPE_BILLBOARD_POSITION, ENVELOPE_TRANSITION_DURATION)
	expand.tween_property(envelope, "size", ENVELOPE_BILLBOARD_SIZE, ENVELOPE_TRANSITION_DURATION)
	expand.tween_property(envelope, "rotation", 0.0, ENVELOPE_TRANSITION_DURATION)
	expand.tween_property(envelope, "scale", Vector2.ONE, ENVELOPE_TRANSITION_DURATION)
	await expand.finished
	envelope_transitioning = false
	envelope_flap.disabled = envelope_opened
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "文件袋已重新展开。" if envelope_opened else "点击文件袋上部圆环或封盖拆开。"


# 直接切换为 billboard 布局，供测试与程序化打开流程使用。
func _show_billboard_immediate() -> void:
	envelope_billboard_expanded = true
	envelope_desk_position = envelope.position
	inspection_dismiss_layer.visible = true
	envelope.position = ENVELOPE_BILLBOARD_POSITION
	envelope.size = ENVELOPE_BILLBOARD_SIZE
	if desk_items != null:
		desk_items.focus_item(envelope)
	else:
		envelope.z_index = ENVELOPE_BILLBOARD_LAYER
	envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope.set_meta("desk_drag_locked", false)
	envelope.set_meta("context_cursor", CursorManager.Cursor.GRAB)
	envelope_image.texture = ENVELOPE_OPEN_EMPTY if envelope_opened else ENVELOPE_CLOSED
	_layout_billboard_controls()


# 应用 billboard 状态下的标签、上部拆封热区与袋口真实文件布局。
func _layout_billboard_controls() -> void:
	envelope_case_label.position = Vector2(92, 454)
	envelope_case_label.size = Vector2(316, 58)
	envelope_case_label.add_theme_font_size_override("font_size", 14)
	envelope_flap.position = Vector2(96, 18)
	envelope_flap.size = Vector2(308, 166)
	envelope_flap.visible = not envelope_opened
	envelope_front_cover.position = ENVELOPE_FRONT_POSITION
	envelope_front_cover.size = ENVELOPE_FRONT_SIZE
	envelope_front_cover.visible = false
	envelope_repack_outline.position = ENVELOPE_VISIBLE_BOUNDS.position
	envelope_repack_outline.size = ENVELOPE_VISIBLE_BOUNDS.size
	envelope_drag_handle.position = Vector2(48, 278)
	envelope_drag_handle.size = Vector2(405, 310)
	envelope_drag_handle.visible = true
	thumbnail_tray.position = ENVELOPE_POCKET_WINDOW_POSITION
	thumbnail_tray.size = ENVELOPE_POCKET_WINDOW_SIZE
	_refresh_document_previews()


# 打开信封，显示缩略图托盘并允许展开文档。
func open_envelope() -> void:
	if envelope_opened or not envelope_on_desk:
		return
	if not envelope_billboard_expanded:
		_show_billboard_immediate()
	envelope_opened = true
	Sfx.play("ui_switch")
	envelope.visible = true
	if desk_items != null:
		desk_items.focus_item(envelope)
	else:
		envelope.z_index = ENVELOPE_BILLBOARD_LAYER
	# 文件抽出后只需排到文件袋父层级之上；不再额外 +N 制造失控的层级。
	next_document_layer = maxi(next_document_layer, ENVELOPE_BILLBOARD_LAYER)
	envelope_flap.disabled = true
	envelope_flap.visible = false
	envelope_front_cover.visible = false
	_play_opening_frames()
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "正在拆开文件袋……"


# 按原始档案组播放松绳和开盖，再叠加当前案件的真实文件。
func _play_opening_frames() -> void:
	var active_envelope := envelope
	envelope_image.texture = ENVELOPE_UNSTRUNG
	await root.get_tree().create_timer(ENVELOPE_OPEN_FRAME_DURATION).timeout
	if not is_instance_valid(active_envelope) or active_envelope != envelope or not envelope_billboard_expanded:
		return
	envelope_image.texture = ENVELOPE_OPEN_EMPTY
	await root.get_tree().create_timer(ENVELOPE_OPEN_FRAME_DURATION).timeout
	if not is_instance_valid(active_envelope) or active_envelope != envelope or not envelope_billboard_expanded:
		return
	envelope_front_cover.visible = false
	_refresh_document_previews()
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "文件袋已拆开：点击袋口露出的真实文件并抽出。"


# 从袋口抽出文件，或将桌面平放文件重新立到查验层。
func open_document(document_id: String) -> void:
	var document: DocumentView = document_by_id.get(document_id)
	if not is_instance_valid(document):
		return
	var state := WorkdayContext.stringify_value(document.get_meta("document_state", "BAG"))
	if state == "BAG" and not envelope_opened:
		return
	match state:
		"BAG":
			_extract_document_from_bag(document)
		"DESK":
			_raise_document_from_desk(document)
		_:
			document.visible = true
			_show_inspection_dismiss_layer()
	bring_document_to_front(document_id)
	Sfx.play("ui_click")
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "“%s”已立到查验层；向下拖动可重新平放。" % document.name


# 从袋口预览位置起步，将同一份 DocumentView 抽出并放大到查验层。
func _extract_document_from_bag(document: DocumentView) -> void:
	var target_position := _read_document_vector(document, "inspection_position", DOCUMENT_INSPECTION_POSITION)
	var thumbnail: Button = thumbnail_by_id.get(document.document_id)
	document.apply_visual_state(DocumentView.VISUAL_INSPECTION)
	var start_center := target_position + document.size * DOCUMENT_INSPECTION_SCALE * 0.5
	if is_instance_valid(thumbnail):
		var preview_center_global := thumbnail.get_global_transform() * (thumbnail.size * 0.5)
		start_center = root.to_local(preview_center_global)
		thumbnail.visible = false
	packed_document_ids.erase(document.document_id)
	pocket_stack_ids.erase(document.document_id)
	document.pivot_offset = document.size * 0.5
	document.position = start_center - document.pivot_offset
	document.scale = DOCUMENT_PEEK_SCALE
	document.rotation = -0.055
	document.visible = true
	document.set_meta("desk_base_scale", DOCUMENT_INSPECTION_SCALE)
	document.set_meta("document_state", "INSPECTION")
	document.remove_meta("desk_home_position")
	document.remove_meta("desk_home_layer")
	_refresh_document_previews()
	_show_inspection_dismiss_layer()
	var extract := _replace_document_tween(document)
	extract.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	extract.tween_property(document, "position", target_position, DOCUMENT_EXTRACT_DURATION)
	extract.parallel().tween_property(document, "scale", DOCUMENT_INSPECTION_SCALE, DOCUMENT_EXTRACT_DURATION)
	extract.parallel().tween_property(document, "rotation", 0.0, DOCUMENT_EXTRACT_DURATION)


# 记录桌面落点，并从该位置把平放文件抬起到查验层。
func _raise_document_from_desk(document: DocumentView) -> void:
	var desk_scale := _read_document_vector(document, "desk_base_scale", DOCUMENT_DESK_SCALE)
	var desk_center := document.position + document.size * desk_scale * 0.5
	document.set_meta("desk_home_position", document.position)
	document.set_meta("desk_home_layer", document.z_index)
	document.set_meta("document_state", "INSPECTION")
	document.apply_visual_state(DocumentView.VISUAL_INSPECTION)
	document.pivot_offset = document.size * 0.5
	document.position = desk_center - document.pivot_offset
	document.scale = desk_scale
	document.rotation = 0.0
	document.visible = true
	document.set_meta("desk_base_scale", DOCUMENT_INSPECTION_SCALE)
	_show_inspection_dismiss_layer()
	var target_position := _read_document_vector(document, "inspection_position", DOCUMENT_INSPECTION_POSITION)
	var raise := _replace_document_tween(document)
	raise.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	raise.tween_property(document, "position", target_position, DOCUMENT_RAISE_DURATION)
	raise.parallel().tween_property(document, "scale", DOCUMENT_INSPECTION_SCALE, DOCUMENT_RAISE_DURATION)


# 将由桌面抬起的文件放回原桌面落点；袋内刚抽出的文件仍等待玩家向下拖放。
func lower_raised_documents_to_desk() -> bool:
	var lowered_any := false
	for document in all_document_views:
		if not is_instance_valid(document):
			continue
		if WorkdayContext.stringify_value(document.get_meta("document_state", "BAG")) != "INSPECTION":
			continue
		if not document.has_meta("desk_home_position"):
			continue
		_lower_document_to_saved_desk_position(document)
		lowered_any = true
	return lowered_any


# 播放立起文件回落到桌面的反向动画。
func _lower_document_to_saved_desk_position(document: DocumentView) -> void:
	var home_position := _read_document_vector(document, "desk_home_position", document.position)
	var home_layer := WorkdayContext.to_int(document.get_meta("desk_home_layer", ENVELOPE_DESK_LAYER + 1))
	document.apply_visual_state(DocumentView.VISUAL_DESK)
	var target_center := home_position + document.size * DOCUMENT_DESK_SCALE * 0.5
	var target_position_with_center_pivot := target_center - document.pivot_offset
	document.set_meta("document_state", "DESK")
	document.set_meta("desk_base_scale", DOCUMENT_DESK_SCALE)
	document.z_index = home_layer
	var lower := _replace_document_tween(document)
	lower.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	lower.tween_property(document, "position", target_position_with_center_pivot, DOCUMENT_RAISE_DURATION)
	lower.parallel().tween_property(document, "scale", DOCUMENT_DESK_SCALE, DOCUMENT_RAISE_DURATION)
	lower.parallel().tween_property(document, "rotation", 0.0, DOCUMENT_RAISE_DURATION)
	lower.finished.connect(_finish_lower_document.bind(document, home_position))


# 回落结束后恢复桌面物件以左上角为枢轴的坐标语义。
func _finish_lower_document(document: DocumentView, home_position: Vector2) -> void:
	if not is_instance_valid(document):
		return
	document.pivot_offset = Vector2.ZERO
	document.position = home_position
	document.scale = DOCUMENT_DESK_SCALE
	document.remove_meta("desk_home_position")
	document.remove_meta("desk_home_layer")
	_refresh_inspection_dismiss_layer()


# 将查验文件切换为桌面平躺态；之后由 DeskItemController 完成落点与重力。
func place_document_on_desk(document_id: String) -> void:
	var document: DocumentView = document_by_id.get(document_id)
	if not is_instance_valid(document):
		return
	if WorkdayContext.stringify_value(document.get_meta("document_state", "BAG")) == "DESK":
		return
	_kill_document_tween(document)
	var inspection_center := document.position + document.pivot_offset
	document.set_meta("document_state", "DESK")
	document.set_meta("desk_base_scale", DOCUMENT_DESK_SCALE)
	document.remove_meta("desk_home_position")
	document.remove_meta("desk_home_layer")
	document.apply_visual_state(DocumentView.VISUAL_DESK)
	document.pivot_offset = Vector2.ZERO
	document.position = inspection_center - document.size * DOCUMENT_DESK_SCALE * 0.5
	document.scale = DOCUMENT_DESK_SCALE * 1.025
	document.rotation = 0.0
	document.set_meta("debug_zone_label", "桌面平躺文件")
	Sfx.play("ui_switch")
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "文件已从查验层放到桌面。"
	_refresh_inspection_dismiss_layer()


# 将指定文档提升到当前最高显示层级。
func bring_document_to_front(document_id: String) -> void:
	var document: DocumentView = document_by_id.get(document_id)
	if not is_instance_valid(document):
		return
	if desk_items != null:
		desk_items.focus_item(document)
		return
	next_document_layer += 1
	document.z_index = next_document_layer


# 让仍处于查验层的文件在释放后原地回正，不进入桌面重力流程。
func _settle_inspection_document(document_id: String) -> void:
	var document: DocumentView = document_by_id.get(document_id)
	if not is_instance_valid(document):
		return
	if WorkdayContext.stringify_value(document.get_meta("document_state", "BAG")) != "INSPECTION":
		return
	_kill_document_tween(document)
	# 查验层内只回正材料，不应抹掉玩家通过滚轮选择的阅读倍率。
	var inspection_scale := _read_document_vector(document, "desk_base_scale", DOCUMENT_INSPECTION_SCALE)
	bring_document_to_front(document_id)
	var settle := _replace_document_tween(document)
	settle.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(document, "rotation", 0.0, 0.12)
	settle.parallel().tween_property(document, "scale", inspection_scale, 0.12)
	_refresh_inspection_dismiss_layer()


# 判断全局点是否位于打开文件袋上方的三角形收口区。
func _is_global_point_in_repack_zone(global_point: Vector2) -> bool:
	if not envelope_opened or not envelope_billboard_expanded or not is_instance_valid(envelope):
		return false
	var local_point := envelope.get_global_transform().affine_inverse() * global_point
	return Geometry2D.is_point_in_polygon(local_point, PackedVector2Array(ENVELOPE_REPACK_ZONE))


# 切换有效归袋反馈；只有真正进入三角袋口时才显示整袋白色描边。
func _set_repack_preview(active: bool) -> void:
	var should_show := active and envelope_opened and envelope_billboard_expanded
	if is_instance_valid(envelope):
		envelope.set_meta("repack_preview_active", should_show)
	if is_instance_valid(envelope_outline_material):
		envelope_outline_material.set_shader_parameter("outline_enabled", should_show)
	if is_instance_valid(envelope_repack_outline):
		envelope_repack_outline.visible = should_show


# 将指定文档放回袋内；放回后仍可再次取出，不改变文件袋移动与归档权限。
func pack_document(document_id: String) -> bool:
	if document_id.is_empty() or packed_document_ids.has(document_id):
		return not document_id.is_empty()
	var document: DocumentView = document_by_id.get(document_id)
	if not is_instance_valid(document):
		return false
	_set_repack_preview(false)
	packed_document_ids.append(document_id)
	pocket_stack_ids.erase(document_id)
	pocket_stack_ids.append(document_id)
	_kill_document_tween(document)
	document.visible = false
	document.set_meta("document_state", "BAG")
	document.remove_meta("desk_home_position")
	document.remove_meta("desk_home_layer")
	var thumbnail: Button = thumbnail_by_id.get(document_id)
	if is_instance_valid(thumbnail):
		thumbnail.visible = true
	Sfx.play("ui_click")

	_refresh_document_previews()
	_refresh_inspection_dismiss_layer()
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "文件已放回袋内；仍可再次取出、移动或直接归档。"
	return true


# 一键将所有文档重新装袋。
func pack_all_documents() -> void:
	for document in all_document_views:
		pack_document(document.document_id)


# 将 billboard 收回桌面平放态；未归袋的文件继续留在桌面上。
func _collapse_to_desk_flat() -> void:
	if not envelope_billboard_expanded or envelope_transitioning:
		return
	_set_repack_preview(false)
	envelope_transitioning = true
	envelope_billboard_expanded = false
	inspection_dismiss_layer.visible = false
	envelope_image.texture = ENVELOPE_DESK_SIDE
	envelope_front_cover.visible = false
	envelope_flap.visible = false
	envelope_drag_handle.visible = false
	thumbnail_tray.visible = false
	envelope_case_label.position = Vector2(18, 86)
	envelope_case_label.size = Vector2(144, 30)
	envelope_case_label.add_theme_font_size_override("font_size", 6)

	var collapse := root.create_tween().set_parallel(true)
	collapse.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	collapse.tween_property(envelope, "position", envelope_desk_position, ENVELOPE_TRANSITION_DURATION)
	collapse.tween_property(envelope, "size", ENVELOPE_DESK_SIZE, ENVELOPE_TRANSITION_DURATION)
	collapse.tween_property(envelope, "rotation", 0.0, ENVELOPE_TRANSITION_DURATION)
	collapse.tween_property(envelope, "scale", Vector2.ONE, ENVELOPE_TRANSITION_DURATION)
	await collapse.finished
	envelope.position = envelope_desk_position
	envelope.size = ENVELOPE_DESK_SIZE
	envelope.rotation = 0.0
	envelope.scale = Vector2.ONE
	if desk_items == null:
		envelope.z_index = ENVELOPE_DESK_LAYER
	envelope.mouse_filter = Control.MOUSE_FILTER_STOP
	envelope.set_meta("desk_drag_locked", false)
	envelope.set_meta("context_cursor", CursorManager.Cursor.GRAB)
	envelope_transitioning = false
	_refresh_inspection_dismiss_layer()


# 从袋外空白区域关闭查验层；未取出的文件仍保留在袋内，桌面文件保持原位。
func collapse_envelope_billboard() -> void:
	if not envelope_billboard_expanded or envelope_transitioning:
		return
	_collapse_to_desk_flat()


# 显示全部袋内真实文件；前袋直接使用原图并由裁切窗口遮挡，避免重复叠画造成色差。
func _refresh_document_previews() -> void:
	if not is_instance_valid(thumbnail_tray):
		return
	for thumbnail_value: Variant in thumbnail_by_id.values():
		var thumbnail_to_hide := thumbnail_value as Button
		if is_instance_valid(thumbnail_to_hide):
			thumbnail_to_hide.visible = false

	var visible_document_ids: Array[String] = []
	for document_id: String in pocket_stack_ids:
		var document: DocumentView = document_by_id.get(document_id)
		if is_instance_valid(document) and WorkdayContext.stringify_value(document.get_meta("document_state", "BAG")) == "BAG":
			visible_document_ids.append(document_id)

	for slot: int in visible_document_ids.size():
		var document_id := visible_document_ids[slot]
		var thumbnail: Button = thumbnail_by_id.get(document_id)
		if not is_instance_valid(thumbnail):
			continue
		thumbnail.visible = true
		_layout_document_preview_slot(thumbnail, slot, visible_document_ids.size())
	# 即使文件已全部抽出也保留透明袋口投放区，否则最后一份文件将没有可归还目标。
	thumbnail_tray.visible = envelope_billboard_expanded and envelope_opened


# 将袋内文件紧凑堆叠在袋口，只露出顶部边角；最后回插的文件位于堆顶。
func _layout_document_preview_slot(thumbnail: Button, slot: int, total: int) -> void:
	var document_id := WorkdayContext.stringify_value(thumbnail.get_meta("document_id"))
	var document: DocumentView = document_by_id.get(document_id)
	var pocket_size := Vector2(150, 110)
	if is_instance_valid(document):
		pocket_size = document.visual_size(DocumentView.VISUAL_POCKET)
	thumbnail.size = pocket_size
	thumbnail.pivot_offset = thumbnail.size * 0.5
	var stack_offset := minf(ENVELOPE_POCKET_STACK_OFFSET_X, maxf(0.0, thumbnail_tray.size.x - thumbnail.size.x) / float(maxi(1, total - 1)))
	var stack_width := thumbnail.size.x + stack_offset * float(maxi(0, total - 1))
	var stack_left := maxf(0.0, (thumbnail_tray.size.x - stack_width) * 0.5)
	thumbnail.position = Vector2(stack_left + stack_offset * float(slot), thumbnail_tray.size.y - ENVELOPE_POCKET_EXPOSED_HEIGHT)
	thumbnail.rotation = 0.0
	# 袋内缩略图与文件袋共用一个原子层，堆叠顺序由 move_child 决定。
	# 禁止按 slot 增加 Z-index，否则父节点位于 999 时会再次突破层级上限。
	thumbnail.z_index = 0
	thumbnail_tray.move_child(thumbnail, thumbnail_tray.get_child_count() - 1)


# 激活位于查验物件下方的空白点击层。
func _show_inspection_dismiss_layer() -> void:
	if not is_instance_valid(inspection_dismiss_layer):
		return
	inspection_dismiss_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspection_dismiss_layer.visible = true


# 仅在文件袋展开或仍有立起文件时保留空白点击层。
func _refresh_inspection_dismiss_layer() -> void:
	if not is_instance_valid(inspection_dismiss_layer):
		return
	var has_inspection_document := false
	for document in all_document_views:
		if not is_instance_valid(document) or not document.visible:
			continue
		if WorkdayContext.stringify_value(document.get_meta("document_state", "BAG")) == "INSPECTION":
			has_inspection_document = true
			break
	var should_show := envelope_billboard_expanded or has_inspection_document
	inspection_dismiss_layer.visible = should_show
	inspection_dismiss_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


# 替换一份文件当前正在播放的空间动画。
func _replace_document_tween(document: DocumentView) -> Tween:
	_kill_document_tween(document)
	var tween := root.create_tween()
	document.set_meta("document_inspection_tween", tween)
	return tween


# 停止一份文件当前正在播放的空间动画。
func _kill_document_tween(document: DocumentView) -> void:
	if not document.has_meta("document_inspection_tween"):
		return
	var tween_value: Variant = document.get_meta("document_inspection_tween")
	if is_instance_valid(tween_value) and tween_value is Tween:
		var tween: Tween = tween_value
		tween.kill()
	document.remove_meta("document_inspection_tween")


# 返回鼠标点击位置最上层可见文档。
func find_document_at_global(global_point: Vector2) -> DocumentView:
	var hit: DocumentView
	var highest_layer := -999999
	for document in all_document_views:
		if document.visible and document.get_global_rect().has_point(global_point) and document.z_index >= highest_layer:
			hit = document
			highest_layer = document.z_index
	return hit


# 在目标文档或主文档上指定位置加盖印章。
func apply_stamp(kind: String, target: Variant, position: Variant = null) -> void:
	var document_id := primary_document_id
	var local_position := Vector2.ZERO
	if target is Vector2:
		local_position = target
	else:
		document_id = WorkdayContext.stringify_value(target, primary_document_id)
		if position is Vector2:
			local_position = position
	var document: DocumentView = document_by_id.get(document_id)
	if not is_instance_valid(document):
		return
	var record := document.add_stamp(kind, local_position)
	record["global_order"] = stamp_records.size()
	stamp_records.append(record)
	form_stamped = true
	if document_id == primary_document_id:
		form_stamp_type = kind
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "已在“%s”加盖“%s”章；同一文件可保留多枚章。" % [document.name, kind]


# 返回主文档是否已被盖章。
func is_stamped() -> bool:
	return form_stamped


# 返回主文档上的印章类型。
func stamp_type() -> String:
	return form_stamp_type


# 检查是否存在同一文件上盖章冲突。
func has_stamp_conflict() -> bool:
	for document: DocumentView in all_document_views:
		if document.has_stamp_conflict():
			return true
	return false


# 返回全部盖章记录副本。
func get_stamp_records() -> Array[Dictionary]:
	return stamp_records.duplicate(true)


# 判断当前袋内是否包含案件预期的全部文档；只供最终提交检查，禁止作为交互门禁。
func all_documents_packed() -> bool:
	return packed_document_ids.size() == all_document_views.size()


# 在归档落下的一刻捕获文件袋内容，供评分、存档和日终验收读取。
func _capture_envelope_snapshot() -> Dictionary:
	var expected_document_ids: Array[String] = []
	for document: DocumentView in all_document_views:
		if is_instance_valid(document):
			expected_document_ids.append(document.document_id)
	var contained_document_ids: Array[String] = packed_document_ids.duplicate()
	var missing_document_ids: Array[String] = []
	for document_id: String in expected_document_ids:
		if not contained_document_ids.has(document_id):
			missing_document_ids.append(document_id)
	var unexpected_document_ids: Array[String] = []
	for document_id: String in contained_document_ids:
		if not expected_document_ids.has(document_id):
			unexpected_document_ids.append(document_id)
	return {
		"captured_at_msec": Time.get_ticks_msec(),
		"envelope_opened": envelope_opened,
		"envelope_on_desk": envelope_on_desk,
		"document_count": contained_document_ids.size(),
		"document_ids": contained_document_ids,
		"expected_document_ids": expected_document_ids,
		"missing_document_ids": missing_document_ids,
		"unexpected_document_ids": unexpected_document_ids,
	}


# 从文件元数据读取 Vector2，避免交互状态直接依赖 Variant。
func _read_document_vector(document: DocumentView, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = document.get_meta(key, fallback)
	return value if value is Vector2 else fallback
