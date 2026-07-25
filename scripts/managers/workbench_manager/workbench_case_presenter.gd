class_name WorkbenchCasePresenter
extends RefCounted

# 单个案件的文件袋、文件视图、缩略图、印章和重新装袋状态。

const ENVELOPE_DESK_SIDE := preload("res://assets/documents/envelopes/bureau_envelope_desk_side.png")
const ENVELOPE_CLOSED := preload("res://assets/documents/envelopes/bureau_envelope_closed.png")
const ENVELOPE_UNSTRUNG := preload("res://assets/documents/envelopes/bureau_envelope_unstrung.png")
const ENVELOPE_OPEN_EMPTY := preload("res://assets/documents/envelopes/bureau_envelope_open_empty.png")
const ENVELOPE_OUTLINE_SHADER := preload("res://shaders/envelope_outline.gdshader")
const DOCUMENT_INSPECTION_SCALE := Vector2(0.64, 0.64)
const DOCUMENT_DESK_SCALE := Vector2(0.36, 0.28)
const DOCUMENT_PEEK_SCALE := Vector2(0.17, 0.17)
const DOCUMENT_INSPECTION_POSITION := Vector2(340, 78)
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
const ENVELOPE_FRONT_REGION := Rect2(0, 168, 340, 352)
const ENVELOPE_FRONT_POSITION := Vector2(48, 200)
const ENVELOPE_FRONT_SIZE := Vector2(405, 420)
const ENVELOPE_CONTENT_OVERLAY_TOP := 12
const ENVELOPE_REPACK_ZONE := [
	Vector2(86, 136),
	Vector2(414, 136),
	Vector2(250, 248),
]

var root: Node2D
var desk: DeskNodes

var current_case: Dictionary = {}
var form: DocumentView
var document_panels: Array[Panel] = []
var all_document_views: Array[DocumentView] = []
var document_by_id: Dictionary = {}
var thumbnail_by_id: Dictionary = {}

var envelope: Panel
var envelope_image: TextureRect
var envelope_outline_material: ShaderMaterial
var envelope_front_cover: TextureRect
var envelope_case_label: Label
var envelope_flap: Button
var thumbnail_tray: Panel
var inspection_dismiss_layer: Control
var envelope_opened := false
var envelope_on_desk := false
var envelope_billboard_expanded := false
var envelope_transitioning := false
var envelope_desk_position := ENVELOPE_DESK_POSITION
var packed_document_ids: Array[String] = []
var primary_document_id := ""

var form_stamped := false
var form_stamp_type := ""
var stamp_records: Array[Dictionary] = []
var next_document_layer := 14
var case_started_at := 0.0


# 初始化案件呈现器，绑定根节点与桌面节点引用。
func _init(owner_root: Node2D, owner_desk: DeskNodes) -> void:
	root = owner_root
	desk = owner_desk


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
		var inspection_position := DOCUMENT_INSPECTION_POSITION + Vector2(index * 24, index * 18)
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
	envelope_case_label.z_index = ENVELOPE_CONTENT_OVERLAY_TOP - 1

	envelope_flap = Button.new()
	envelope_flap.name = "EnvelopeUpperOpenHitArea"
	envelope_flap.text = ""
	envelope_flap.tooltip_text = "点击圆环或上部封盖拆开文件袋"
	envelope_flap.disabled = true
	envelope_flap.visible = false
	envelope_flap.z_index = ENVELOPE_CONTENT_OVERLAY_TOP
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
	thumbnail_tray.z_index = 1
	thumbnail_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail_tray.clip_contents = true
	thumbnail_tray.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color.TRANSPARENT, 0))
	envelope.add_child(thumbnail_tray)
	_create_thumbnails()

	var front_atlas := AtlasTexture.new()
	front_atlas.atlas = ENVELOPE_OPEN_EMPTY
	front_atlas.region = ENVELOPE_FRONT_REGION
	envelope_front_cover = TextureRect.new()
	envelope_front_cover.name = "EnvelopeFrontPocketCover"
	envelope_front_cover.texture = front_atlas
	envelope_front_cover.position = ENVELOPE_FRONT_POSITION
	envelope_front_cover.size = ENVELOPE_FRONT_SIZE
	envelope_front_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	envelope_front_cover.stretch_mode = TextureRect.STRETCH_SCALE
	envelope_front_cover.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	envelope_front_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope_front_cover.z_index = ENVELOPE_CONTENT_OVERLAY_TOP - 2
	envelope_front_cover.visible = false
	envelope.add_child(envelope_front_cover)


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
		thumbnail.z_index = 1
		thumbnail.icon = document.background.texture
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
	if not envelope_on_desk or all_documents_packed() or envelope_billboard_expanded or envelope_transitioning:
		return
	envelope_transitioning = true
	envelope_billboard_expanded = true
	envelope_desk_position = envelope.position
	inspection_dismiss_layer.visible = true
	envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope.set_meta("desk_drag_locked", true)
	envelope.set_meta("context_cursor", CursorManager.Cursor.OPEN_ENVELOPE)
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
	envelope.z_index = ENVELOPE_BILLBOARD_LAYER
	envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope.set_meta("desk_drag_locked", true)
	envelope.set_meta("context_cursor", CursorManager.Cursor.OPEN_ENVELOPE)
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
	envelope_front_cover.visible = envelope_opened
	thumbnail_tray.position = Vector2(86, 132)
	thumbnail_tray.size = Vector2(328, 132)
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
	envelope.z_index = ENVELOPE_BILLBOARD_LAYER
	next_document_layer = maxi(next_document_layer, ENVELOPE_BILLBOARD_LAYER + ENVELOPE_CONTENT_OVERLAY_TOP)
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
	envelope_front_cover.visible = true
	_refresh_document_previews()
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "文件袋已拆开：点击袋口露出的真实文件并抽出。"


# 从袋口抽出文件，或将桌面平放文件重新立到查验层。
func open_document(document_id: String) -> void:
	if packed_document_ids.has(document_id):
		return
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
	var start_center := target_position + document.size * DOCUMENT_INSPECTION_SCALE * 0.5
	if is_instance_valid(thumbnail):
		var preview_center_global := thumbnail.get_global_transform() * (thumbnail.size * 0.5)
		start_center = root.to_local(preview_center_global)
		thumbnail.visible = false
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
	document.set_meta("desk_base_scale", DOCUMENT_INSPECTION_SCALE)
	bring_document_to_front(document_id)
	var settle := _replace_document_tween(document)
	settle.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(document, "rotation", 0.0, 0.12)
	settle.parallel().tween_property(document, "scale", DOCUMENT_INSPECTION_SCALE, 0.12)
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


# 将指定文档重新装袋；若全部装袋则提示可送入验收机器。
func pack_document(document_id: String) -> bool:
	if document_id.is_empty() or packed_document_ids.has(document_id):
		return all_documents_packed()
	var document: DocumentView = document_by_id.get(document_id)
	if not is_instance_valid(document):
		return all_documents_packed()
	_set_repack_preview(false)
	packed_document_ids.append(document_id)
	_kill_document_tween(document)
	document.visible = false
	document.set_meta("document_state", "BAG")
	document.remove_meta("desk_home_position")
	document.remove_meta("desk_home_layer")
	var thumbnail: Button = thumbnail_by_id.get(document_id)
	if is_instance_valid(thumbnail):
		thumbnail.visible = false
	Sfx.play("ui_click")

	if all_documents_packed():
		thumbnail_tray.visible = false
		_collapse_to_desk_flat()
		if is_instance_valid(desk.status_label):
			desk.status_label.text = "全部文件已重新装袋，可送入验收区。"
		return true
	_refresh_document_previews()
	_refresh_inspection_dismiss_layer()
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "已收回文件；袋内仍缺 %d 份。" % (all_document_views.size() - packed_document_ids.size())
	return false


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
	envelope.z_index = ENVELOPE_DESK_LAYER
	envelope.mouse_filter = Control.MOUSE_FILTER_STOP
	var ready_for_archive := all_documents_packed()
	envelope.set_meta("desk_drag_locked", not ready_for_archive)
	envelope.set_meta("context_cursor", CursorManager.Cursor.GRAB if ready_for_archive else CursorManager.Cursor.OPEN_ENVELOPE)
	envelope_transitioning = false
	_refresh_inspection_dismiss_layer()


# 从袋外空白区域关闭查验层；未取出的文件仍保留在袋内，桌面文件保持原位。
func collapse_envelope_billboard() -> void:
	if not envelope_billboard_expanded or envelope_transitioning:
		return
	_collapse_to_desk_flat()


# 只显示仍在袋中的真实文件预览；袋体始终使用不含假文件的 open_empty 原图。
func _refresh_document_previews() -> void:
	if not is_instance_valid(thumbnail_tray):
		return
	var visible_slot := 0
	for document in all_document_views:
		var thumbnail: Button = thumbnail_by_id.get(document.document_id)
		if not is_instance_valid(thumbnail):
			continue
		var remains_in_bag := WorkdayContext.stringify_value(document.get_meta("document_state", "BAG")) == "BAG" and not packed_document_ids.has(document.document_id)
		var should_show := remains_in_bag and visible_slot < 2
		thumbnail.visible = should_show
		if should_show:
			_layout_document_preview_slot(thumbnail, visible_slot)
			visible_slot += 1
	# 即使文件已全部抽出也保留透明袋口投放区，否则最后一份文件将没有可归还目标。
	thumbnail_tray.visible = envelope_billboard_expanded and envelope_opened


# 袋口始终只露出最上方两份真实文件；抽走一份后下一份自动补到袋口。
func _layout_document_preview_slot(thumbnail: Button, slot: int) -> void:
	thumbnail.size = Vector2(150, 110)
	thumbnail.pivot_offset = thumbnail.size * 0.5
	if slot == 0:
		thumbnail.position = Vector2(34, 32)
		thumbnail.rotation = -0.04
		thumbnail.z_index = 1
	else:
		thumbnail.position = Vector2(144, 20)
		thumbnail.rotation = 0.035
		thumbnail.z_index = 2


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


# 判断是否所有文档都已重新装袋。
func all_documents_packed() -> bool:
	return packed_document_ids.size() == all_document_views.size()


# 从文件元数据读取 Vector2，避免交互状态直接依赖 Variant。
func _read_document_vector(document: DocumentView, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = document.get_meta(key, fallback)
	return value if value is Vector2 else fallback
