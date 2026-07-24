class_name CasePresenter
extends RefCounted

# 单个案件的文件袋、文件视图、缩略图、印章和重新装袋状态。

const ENVELOPE_CLOSED := preload("res://assets/documents/envelopes/standard_closed.png")
const ENVELOPE_OPEN := preload("res://assets/documents/envelopes/standard_open.png")
const DOCUMENT_SCALE := Vector2(0.64, 0.64)
const ENVELOPE_SIZE := Vector2(320, 192)

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
var envelope_flap: Button
var thumbnail_tray: Panel
var envelope_opened := false
var envelope_on_desk := false
var packed_document_ids: Array[String] = []
var primary_document_id := ""

var form_stamped := false
var form_stamp_type := ""
var stamp_records: Array[Dictionary] = []
var next_document_layer := 14
var case_started_at := 0.0


func _init(owner_root: Node2D, owner_desk: DeskNodes) -> void:
	root = owner_root
	desk = owner_desk


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
		desk.applicant_card_label.text = "%s\n%s\n%s" % [
			current_case.applicant, current_case.code, current_case.department
		]
	if is_instance_valid(desk.queue_label):
		var display_name := String(current_case.get("person", {}).get("display_name", "身份受限"))
		desk.queue_label.text = "%s\n窗口就位\n后续排队：%d 人" % [
			display_name, LevelDirector.get_gameplay_queue().size()
		]
	Sfx.play_voice(String(current_case.get("person", {}).get("id", "")))

	_create_documents(current_case.get("documents", []))
	_create_envelope()
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "申请人已递交封存文件袋。"


func clear_case() -> void:
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
	next_document_layer = 14


func _create_documents(raw_documents: Array) -> void:
	var index := 0
	for raw_document in raw_documents:
		var document_data: Dictionary = raw_document
		var type_data := ConfigDatabase.get_ontology(
			"document_types", String(document_data.get("document_type_id", ""))
		)
		var document := DocumentView.new()
		document.configure(
			document_data,
			type_data,
			current_case.get("person", {}),
			String(current_case.get("code", ""))
		)
		document.position = Vector2(180 + index * 70, 80 + index * 40)
		document.scale = DOCUMENT_SCALE
		document.set_meta("desk_base_scale", DOCUMENT_SCALE)
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


func _create_envelope() -> void:
	envelope = Panel.new()
	envelope.name = "CaseEnvelope"
	envelope.position = Vector2(600, 430)
	envelope.size = ENVELOPE_SIZE
	envelope.z_index = 12
	envelope.mouse_default_cursor_shape = Control.CURSOR_ARROW
	envelope.add_theme_stylebox_override(
		"panel", WorkbenchUI.style_box(Color.TRANSPARENT, 0)
	)
	root.add_child(envelope)

	envelope_image = TextureRect.new()
	envelope_image.name = "EnvelopeImage"
	envelope_image.texture = ENVELOPE_CLOSED
	envelope_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	envelope_image.stretch_mode = TextureRect.STRETCH_SCALE
	envelope_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	envelope_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope_image.size = ENVELOPE_SIZE
	envelope.add_child(envelope_image)

	var case_label := WorkbenchUI.add_text(
		envelope,
		"%s\n%s" % [
			current_case.get("applicant", "身份受限"),
			current_case.get("code", "未编号"),
		],
		12,
		Color("34362c"),
		Vector2(202, 106),
		Vector2(100, 50)
	)
	case_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	case_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	case_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	envelope_flap = Button.new()
	envelope_flap.name = "EnvelopeFlap"
	envelope_flap.text = "放上工作台后拆封"
	envelope_flap.position = Vector2(72, 152)
	envelope_flap.size = Vector2(176, 30)
	envelope_flap.disabled = true
	envelope_flap.add_theme_font_override("font", WorkbenchUI.PIXEL_FONT)
	envelope_flap.add_theme_font_size_override("font_size", 12)
	envelope_flap.add_theme_color_override("font_color", Color("e1d2a5"))
	envelope_flap.add_theme_stylebox_override(
		"normal", WorkbenchUI.style_box(Color(0.08, 0.09, 0.07, 0.82), 2)
	)
	envelope.add_child(envelope_flap)
	CursorManager.watch(envelope_flap, CursorManager.Cursor.OPEN_ENVELOPE)
	envelope_flap.button_down.connect(_on_flap_pressed)

	thumbnail_tray = Panel.new()
	thumbnail_tray.name = "DocumentThumbnails"
	thumbnail_tray.position = Vector2(4, -146)
	thumbnail_tray.size = Vector2(312, 150)
	thumbnail_tray.visible = false
	thumbnail_tray.mouse_filter = Control.MOUSE_FILTER_PASS
	thumbnail_tray.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color(0.07, 0.08, 0.06, 0.92), 3, Color("706344"), 2)
	)
	envelope.add_child(thumbnail_tray)
	_create_thumbnails()

	var delivery := root.create_tween()
	delivery.tween_property(envelope, "position", Vector2(250, 505), 0.28)


func _create_thumbnails() -> void:
	var index := 0
	for document in all_document_views:
		var thumbnail := Button.new()
		thumbnail.name = "Thumbnail_%s" % document.document_id
		thumbnail.position = Vector2(7 + (index % 3) * 101, 7 + (index / 3) * 68)
		thumbnail.size = Vector2(94, 61)
		thumbnail.icon = document.background.texture
		thumbnail.expand_icon = true
		thumbnail.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		thumbnail.tooltip_text = "展开：%s" % String(
			current_case.get("documents", [])[index].get("title", "正式文件")
		)
		thumbnail.add_theme_stylebox_override(
			"normal",
			WorkbenchUI.style_box(Color("bcae83"), 1, Color("6a6047"), 1)
		)
		thumbnail.add_theme_stylebox_override(
			"hover",
			WorkbenchUI.style_box(Color("e2d5ac"), 1, WorkbenchUI.COLORS.green_glow, 2)
		)
		thumbnail.pressed.connect(open_document.bind(document.document_id))
		thumbnail_tray.add_child(thumbnail)
		thumbnail_by_id[document.document_id] = thumbnail
		index += 1


func _on_flap_pressed() -> void:
	if envelope_on_desk:
		open_envelope()


func set_envelope_on_desk(value: bool) -> void:
	envelope_on_desk = value
	if is_instance_valid(envelope_flap):
		envelope_flap.disabled = not value
		envelope_flap.text = "拆开封口" if value else "放上工作台后拆封"


func open_envelope() -> void:
	if envelope_opened or not envelope_on_desk:
		return
	envelope_opened = true
	Sfx.play("ui_switch")
	envelope.visible = true
	envelope_image.texture = ENVELOPE_OPEN
	envelope.position = Vector2(250, 505)
	envelope.z_index = 10
	thumbnail_tray.visible = true
	envelope_flap.disabled = true
	envelope_flap.text = "逐份展开并处理袋内文件"
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "文件袋已拆开：点击袋内缩略图展开文件。"


func open_document(document_id: String) -> void:
	if not envelope_opened or packed_document_ids.has(document_id):
		return
	var document: DocumentView = document_by_id.get(document_id)
	if not is_instance_valid(document):
		return
	document.visible = true
	bring_document_to_front(document_id)
	Sfx.play("ui_click")
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "已展开“%s”；可继续打开其他文件并交叠核对。" % document.name


func bring_document_to_front(document_id: String) -> void:
	var document: DocumentView = document_by_id.get(document_id)
	if not is_instance_valid(document):
		return
	next_document_layer += 1
	document.z_index = next_document_layer


func pack_document(document_id: String) -> bool:
	if document_id.is_empty() or packed_document_ids.has(document_id):
		return all_documents_packed()
	var document: DocumentView = document_by_id.get(document_id)
	if not is_instance_valid(document):
		return all_documents_packed()
	packed_document_ids.append(document_id)
	document.visible = false
	var thumbnail: Button = thumbnail_by_id.get(document_id)
	if is_instance_valid(thumbnail):
		thumbnail.visible = false
	Sfx.play("ui_click")

	if all_documents_packed():
		thumbnail_tray.visible = false
		envelope_image.texture = ENVELOPE_CLOSED
		envelope.z_index = 12
		envelope_flap.text = "材料已封装，可送入中央验收机器"
		if is_instance_valid(desk.status_label):
			desk.status_label.text = "全部文件已重新装袋，可送入验收区。"
		return true
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "已收回文件；袋内仍缺 %d 份。" % (
			all_document_views.size() - packed_document_ids.size()
		)
	return false


func pack_all_documents() -> void:
	for document in all_document_views:
		pack_document(document.document_id)


func find_document_at_global(global_point: Vector2) -> DocumentView:
	var hit: DocumentView
	var highest_layer := -999999
	for document in all_document_views:
		if (
			document.visible
			and document.get_global_rect().has_point(global_point)
			and document.z_index >= highest_layer
		):
			hit = document
			highest_layer = document.z_index
	return hit


func apply_stamp(kind: String, target: Variant, position: Variant = null) -> void:
	var document_id := primary_document_id
	var local_position := Vector2.ZERO
	if target is Vector2:
		local_position = target
	else:
		document_id = String(target)
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
		desk.status_label.text = "已在“%s”加盖“%s”章；同一文件可保留多枚章。" % [
			document.name, kind
		]


func is_stamped() -> bool:
	return form_stamped


func stamp_type() -> String:
	return form_stamp_type


func has_stamp_conflict() -> bool:
	return all_document_views.any(func(document): return document.has_stamp_conflict())


func get_stamp_records() -> Array[Dictionary]:
	return stamp_records.duplicate(true)


func all_documents_packed() -> bool:
	return packed_document_ids.size() == all_document_views.size()
