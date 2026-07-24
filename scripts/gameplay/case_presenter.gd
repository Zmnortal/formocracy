class_name CasePresenter
extends RefCounted

# 单个案件的视觉与状态管理。
# 负责创建/销毁申请表、文件袋、证明材料；处理盖章与装袋状态。

const APPROVE_STAMP_TEXTURE := preload("res://assets/day1_8bit/interactive/approve_stamp.png")
const RETURN_STAMP_TEXTURE := preload("res://assets/day1_8bit/interactive/return_stamp.png")

var root: Node2D
var desk: DeskNodes

var current_case: Dictionary = {}
var form: Panel
var form_stamped := false
var form_stamp_type := ""
var stamp_mark: Label
var envelope: Panel
var envelope_flap: Button
var envelope_opened := false
var envelope_on_desk := false
var document_panels: Array[Panel] = []
var packed_document_ids: Array[String] = []
var primary_document_id := ""
var case_started_at := 0.0


func _init(owner_root: Node2D, owner_desk: DeskNodes) -> void:
	root = owner_root
	desk = owner_desk


# 开始展示一个案件：销毁旧节点，创建新的表单、文件袋与材料。
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
		desk.queue_label.text = "%s\n正在进场\n后续排队：%d 人" % [
			display_name, LevelDirector.get_gameplay_queue().size()
		]
	Sfx.play_voice(String(current_case.get("person", {}).get("id", "")))

	_create_form()
	_create_documents(current_case.get("documents", []))
	_create_envelope()

	if is_instance_valid(desk.status_label):
		desk.status_label.text = "请完成申请的形式处理。"


# 清理当前案件创建的所有动态节点与状态。
func clear_case() -> void:
	if is_instance_valid(form):
		form.queue_free()
	if is_instance_valid(envelope):
		envelope.queue_free()
	for document in document_panels:
		if is_instance_valid(document):
			document.queue_free()
	document_panels.clear()
	packed_document_ids.clear()
	primary_document_id = ""
	form_stamped = false
	form_stamp_type = ""
	envelope_opened = false
	envelope_on_desk = false


func _create_form() -> void:
	form = Panel.new()
	form.name = "ApplicationForm"
	form.position = desk.form_home
	form.size = Vector2(485, 475)
	form.pivot_offset = form.size / 2.0
	form.scale = desk.form_base_scale
	form.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(WorkbenchUI.COLORS.paper, 2, Color("786f58"), 2)
	)
	form.mouse_default_cursor_shape = Control.CURSOR_MOVE
	form.visible = false
	form.z_index = 5
	root.add_child(form)

	var shadow := Panel.new()
	shadow.name = "PaperShadow"
	shadow.position = Vector2(10, 12)
	shadow.size = form.size
	shadow.show_behind_parent = true
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color(0, 0, 0, 0.34), 3)
	)
	form.add_child(shadow)

	var data := current_case
	WorkbenchUI.add_text(form, data.department, 15, WorkbenchUI.COLORS.ink, Vector2(28, 20), Vector2(390, 24))
	var heading := WorkbenchUI.add_text(form, "现实事项申请表", 28, WorkbenchUI.COLORS.ink, Vector2(28, 52), Vector2(420, 42))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	WorkbenchUI.add_text(form, data.code, 13, Color("565647"), Vector2(28, 100), Vector2(420, 22))
	WorkbenchUI.add_text(form, "申请人", 12, Color("666252"), Vector2(28, 135), Vector2(80, 20))
	WorkbenchUI.add_text(form, data.applicant, 17, WorkbenchUI.COLORS.ink, Vector2(28, 157), Vector2(420, 27))
	WorkbenchUI.add_text(form, "申请事项", 12, Color("666252"), Vector2(28, 198), Vector2(80, 20))
	WorkbenchUI.add_text(form, data.request, 16, WorkbenchUI.COLORS.ink, Vector2(28, 220), Vector2(420, 48))
	WorkbenchUI.add_text(form, "形式审查", 13, Color("666252"), Vector2(28, 278), Vector2(120, 22))

	for i in data.checks.size():
		var check := CheckBox.new()
		check.text = data.checks[i]
		check.position = Vector2(28, 305 + i * 35)
		check.size = Vector2(420, 30)
		check.add_theme_font_size_override("font_size", 14)
		check.add_theme_font_override("font", WorkbenchUI.PIXEL_FONT)
		check.add_theme_color_override("font_color", WorkbenchUI.COLORS.ink)
		check.add_theme_color_override("font_pressed_color", WorkbenchUI.COLORS.ink)
		form.add_child(check)

	WorkbenchUI.add_text(
		form,
		"批准不构成生效、时限或行政承诺。",
		12,
		Color("6b5747"),
		Vector2(28, 422),
		Vector2(420, 24)
	)

	stamp_mark = Label.new()
	stamp_mark.position = Vector2(300, 342)
	stamp_mark.size = Vector2(150, 62)
	stamp_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp_mark.rotation = -0.12
	stamp_mark.add_theme_font_size_override("font_size", 27)
	stamp_mark.add_theme_font_override("font", WorkbenchUI.PIXEL_FONT)
	stamp_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	form.add_child(stamp_mark)


func _create_envelope() -> void:
	envelope = Panel.new()
	envelope.name = "CaseEnvelope"
	envelope.position = Vector2(94, 470)
	envelope.size = Vector2(285, 155)
	envelope.z_index = 12
	envelope.mouse_default_cursor_shape = Control.CURSOR_MOVE
	envelope.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color("ad9162"), 4, Color("6e5534"), 3)
	)
	root.add_child(envelope)

	WorkbenchUI.add_text(envelope, "封存文件袋", 19, WorkbenchUI.COLORS.ink, Vector2(18, 15), Vector2(245, 26))
	WorkbenchUI.add_text(
		envelope,
		"%s\n%s\n目录：%d 份材料" % [
			current_case.applicant, current_case.code, current_case.get("documents", []).size()
		],
		13,
		WorkbenchUI.COLORS.ink,
		Vector2(18, 50),
		Vector2(250, 80)
	)

	envelope_flap = Button.new()
	envelope_flap.name = "EnvelopeFlap"
	envelope_flap.text = "按住或点击封口拆开"
	envelope_flap.position = Vector2(18, 120)
	envelope_flap.size = Vector2(248, 28)
	envelope_flap.disabled = true
	envelope.add_child(envelope_flap)
	envelope_flap.button_down.connect(_on_flap_pressed)

	var delivery := root.create_tween()
	delivery.tween_property(envelope, "position", Vector2(115, 320), 0.28)


func _on_flap_pressed() -> void:
	if envelope_on_desk:
		open_envelope()


func _create_documents(raw_documents: Array) -> void:
	var index := 0
	for document_data in raw_documents:
		var type_data := ConfigDatabase.get_ontology(
			"document_types", String(document_data.get("document_type_id", ""))
		)
		if bool(type_data.get("is_primary", false)):
			primary_document_id = String(document_data.get("id", ""))
			continue

		var document := Panel.new()
		document.name = String(document_data.get("id", "Document"))
		document.position = Vector2(350 + index * 54, 230 + index * 32)
		document.size = Vector2(300, 230)
		document.z_index = 6 + index
		document.visible = false
		document.set_meta("document_id", String(document_data.get("id", "")))
		document.set_meta("dragging", false)
		document.add_theme_stylebox_override(
			"panel",
			WorkbenchUI.style_box(Color("d8cba7"), 2, Color("746a52"), 2)
		)
		document.mouse_default_cursor_shape = Control.CURSOR_MOVE
		root.add_child(document)

		WorkbenchUI.add_text(
			document,
			String(document_data.get("title", "证明材料")),
			19,
			WorkbenchUI.COLORS.ink,
			Vector2(18, 14),
			Vector2(260, 28)
		)
		var lines: Array[String] = []
		for field_name in document_data.get("fields", {}):
			lines.append("%s：%s" % [field_name, str(document_data.fields[field_name])])
		WorkbenchUI.add_text(
			document,
			"\n".join(lines),
			14,
			WorkbenchUI.COLORS.ink,
			Vector2(18, 55),
			Vector2(260, 145)
		)
		document_panels.append(document)
		index += 1


# 设置文件袋已放置在工作台上，并启用封口按钮。
func set_envelope_on_desk(value: bool) -> void:
	envelope_on_desk = value
	if is_instance_valid(envelope_flap):
		envelope_flap.disabled = not value


# 拆开文件袋，显示表单与材料。
func open_envelope() -> void:
	if envelope_opened or not envelope_on_desk:
		return
	envelope_opened = true
	Sfx.play("ui_switch")
	envelope.visible = true
	envelope.position = Vector2(78, 505)
	envelope.z_index = 4
	if is_instance_valid(envelope_flap):
		envelope_flap.disabled = true
		envelope_flap.text = "将盖章表单与证明材料拖回袋中"
	form.visible = true
	for document in document_panels:
		document.visible = true
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "文件袋已拆开：展开主表单与 %d 份证明材料。" % document_panels.size()


# 将指定材料标记为已装袋并隐藏对应面板。
# 返回是否已装袋全部材料。
func pack_document(document_id: String) -> bool:
	if not packed_document_ids.has(document_id) and not document_id.is_empty():
		packed_document_ids.append(document_id)
		Sfx.play("ui_click")
	for document in document_panels:
		if String(document.get_meta("document_id")) == document_id:
			document.visible = false

	if packed_document_ids.size() == current_case.get("documents", []).size():
		if is_instance_valid(form):
			form.visible = false
		if is_instance_valid(envelope):
			envelope.visible = true
			envelope.z_index = 12
		if is_instance_valid(envelope_flap):
			envelope_flap.text = "材料已封装，可送入中央验收机器"
		if is_instance_valid(desk.status_label):
			desk.status_label.text = "全部材料已重新装袋，可送入验收区。"
		return true
	return false


# 一键装袋所有材料（主材料 + 全部证明材料）。
func pack_all_documents() -> void:
	pack_document(primary_document_id)
	for document in document_panels:
		pack_document(String(document.get_meta("document_id")))


# 在申请表上生成印章标记。
func apply_stamp(kind: String, local_position: Vector2) -> void:
	form_stamped = true
	form_stamp_type = kind
	stamp_mark.text = kind + "\n已作形式处理"
	stamp_mark.position = Vector2(
		clamp(local_position.x - 75, 20, 315),
		clamp(local_position.y - 31, 300, 390)
	)
	var color: Color = WorkbenchUI.COLORS.green if kind == "批准" else WorkbenchUI.COLORS.red
	stamp_mark.add_theme_color_override("font_color", color)
	stamp_mark.add_theme_constant_override("outline_size", 2)
	stamp_mark.add_theme_color_override("font_outline_color", Color(color, 0.25))
	stamp_mark.scale = Vector2(1.45, 1.45)
	stamp_mark.modulate.a = 0.35

	var tween := root.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(stamp_mark, "scale", Vector2.ONE, 0.2)
	tween.tween_property(stamp_mark, "modulate:a", 0.88, 0.28)

	if is_instance_valid(desk.status_label):
		desk.status_label.text = "已加盖“%s”印章，可送交现实验收。" % kind


func is_stamped() -> bool:
	return form_stamped


func stamp_type() -> String:
	return form_stamp_type


func all_documents_packed() -> bool:
	return packed_document_ids.size() == current_case.get("documents", []).size()
