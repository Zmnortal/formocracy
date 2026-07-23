extends Node2D

const WORKBENCH_TEXTURE := preload("res://assets/concepts/clerk-desk.png")
const VALIDATION_TEXTURE := preload("res://assets/concepts/validation-machine.png")

const CASES := [
	{
		"department": "第十二区居住配置处",
		"code": "R-12/住房用途变更申请",
		"applicant": "林默，公民序号 74-119-02",
		"request": "申请将单人居住配额变更为二人共同配额。",
		"checks": ["身份记录与现居地址一致", "共同居住人已提交知情声明", "申请未形成事实性居住承诺"]
	},
	{
		"department": "公共供给连续性办公室",
		"code": "W-08/饮水额度临时调整",
		"applicant": "周循，公民序号 20-441-88",
		"request": "因家庭照护事项申请临时提高净水领取额度。",
		"checks": ["申报家庭成员记录完整", "照护事由证明处于有效期", "申请人已知悉调整不保证供给"]
	},
	{
		"department": "中央医疗秩序协调科",
		"code": "M-31/非计划医疗通行申请",
		"applicant": "许桥，公民序号 51-004-63",
		"request": "申请于限制时段前往第五诊疗站接受复查。",
		"checks": ["诊疗站回执编号可辨认", "通行时段与复查安排相符", "紧急程度未由申请人自行认定"]
	}
]

var case_index := 0
var form: Panel
var form_home := Vector2(435, 252)
var form_base_scale := Vector2(0.86, 0.86)
var dragging_form := false
var form_drag_offset := Vector2.ZERO
var form_stamped := false
var form_stamp_type := ""
var stamp_mark: Label
var status_label: Label
var slot: Panel
var slot_light: ColorRect
var applicant_card_label: Label
var validation_overlay: Control
var validation_image: TextureRect
var parallax_layers: Array[Control] = []
var stamp_tools: Array[Panel] = []

var colors := {
	"wall": Color("171b1a"),
	"wall_mid": Color("232a27"),
	"desk": Color("493a2d"),
	"desk_edge": Color("281f19"),
	"paper": Color("ded2ad"),
	"ink": Color("252923"),
	"green": Color("667a55"),
	"green_glow": Color("9cbb74"),
	"red": Color("8f332d"),
	"brass": Color("9a7844")
}


func _ready() -> void:
	build_scene()
	create_case()
	for layer in parallax_layers:
		layer.set_meta("base_position", layer.position)
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


func style_box(color: Color, radius := 0, border_color := Color.TRANSPARENT, border := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	if border > 0:
		box.border_width_left = border
		box.border_width_top = border
		box.border_width_right = border
		box.border_width_bottom = border
		box.border_color = border_color
	return box


func add_text(parent: Node, text: String, size: int, color: Color, position: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = dimensions
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func build_scene() -> void:
	var backdrop := TextureRect.new()
	backdrop.name = "ClerkDeskConcept"
	backdrop.texture = WORKBENCH_TEXTURE
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(1280, 720)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var vignette := ColorRect.new()
	vignette.name = "InteractionContrast"
	vignette.color = Color(0.04, 0.045, 0.04, 0.18)
	vignette.position = Vector2.ZERO
	vignette.size = Vector2(1280, 720)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	var case_card := Panel.new()
	case_card.name = "ApplicantCard"
	case_card.position = Vector2(1010, 350)
	case_card.size = Vector2(235, 112)
	case_card.add_theme_stylebox_override("panel", style_box(Color(0.08, 0.075, 0.06, 0.94), 4, colors.brass, 2))
	add_child(case_card)
	add_text(case_card, "当前申请人档案", 12, Color("b9aa88"), Vector2(14, 10), Vector2(200, 20))
	applicant_card_label = add_text(case_card, "", 14, Color("ddd0ac"), Vector2(14, 35), Vector2(207, 67))

	slot = Panel.new()
	slot.name = "RealityValidationSlot"
	slot.position = Vector2(1010, 475)
	slot.size = Vector2(235, 92)
	slot.add_theme_stylebox_override("panel", style_box(Color(0.035, 0.035, 0.03, 0.96), 5, colors.brass, 3))
	add_child(slot)
	add_text(slot, "送交中央现实验收", 15, Color("d0c09b"), Vector2(16, 11), Vector2(190, 22))
	var opening := ColorRect.new()
	opening.color = Color("030303")
	opening.position = Vector2(16, 47)
	opening.size = Vector2(202, 20)
	opening.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(opening)
	slot_light = ColorRect.new()
	slot_light.color = colors.red
	slot_light.position = Vector2(207, 13)
	slot_light.size = Vector2(10, 10)
	slot_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(slot_light)

	var status_back := Panel.new()
	status_back.position = Vector2(370, 680)
	status_back.size = Vector2(540, 34)
	status_back.add_theme_stylebox_override("panel", style_box(Color(0.04, 0.035, 0.025, 0.92), 4, colors.brass, 1))
	add_child(status_back)
	status_label = add_text(status_back, "请完成申请的形式处理。", 14, Color("d8c9a9"), Vector2(14, 6), Vector2(510, 22))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	create_stamp_tool("批准", colors.green, Vector2(275, 535))
	create_stamp_tool("驳回", colors.red, Vector2(900, 535))
	create_validation_overlay()


func create_validation_overlay() -> void:
	validation_overlay = Control.new()
	validation_overlay.name = "ValidationTransition"
	validation_overlay.position = Vector2.ZERO
	validation_overlay.size = Vector2(1280, 720)
	validation_overlay.z_index = 100
	validation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	validation_overlay.visible = false
	add_child(validation_overlay)
	validation_image = TextureRect.new()
	validation_image.texture = VALIDATION_TEXTURE
	validation_image.size = Vector2(1280, 720)
	validation_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	validation_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	validation_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	validation_overlay.add_child(validation_image)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.2)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	validation_overlay.add_child(shade)
	var receipt := add_text(validation_overlay, "现实效力请求已进入设施队列", 24, Color("e1d3b0"), Vector2(370, 646), Vector2(540, 42))
	receipt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	receipt.add_theme_constant_override("outline_size", 6)
	receipt.add_theme_color_override("font_outline_color", Color("16120e"))


func create_stamp_tool(kind: String, color: Color, at: Vector2) -> void:
	var tool := Panel.new()
	tool.name = kind + "Stamp"
	tool.position = at
	tool.size = Vector2(104, 92)
	tool.set_meta("home", at)
	tool.set_meta("kind", kind)
	tool.set_meta("dragging", false)
	tool.add_theme_stylebox_override("panel", style_box(Color("28221c"), 10, colors.brass, 3))
	add_child(tool)
	stamp_tools.append(tool)
	var handle := ColorRect.new()
	handle.color = Color("6c573c")
	handle.position = Vector2(34, 8)
	handle.size = Vector2(36, 34)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool.add_child(handle)
	var face := Label.new()
	face.text = kind
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.position = Vector2(10, 47)
	face.size = Vector2(84, 34)
	face.add_theme_font_size_override("font_size", 20)
	face.add_theme_color_override("font_color", color)
	face.add_theme_stylebox_override("normal", style_box(Color("d0c3a1"), 2, color, 3))
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool.add_child(face)
	tool.gui_input.connect(_on_stamp_input.bind(tool))


func _on_stamp_input(event: InputEvent, tool: Panel) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tool.set_meta("dragging", true)
			tool.set_meta("offset", event.position)
			tool.z_index = 20
			var tween := create_tween()
			tween.tween_property(tool, "scale", Vector2(1.08, 1.08), 0.08)
		else:
			tool.set_meta("dragging", false)
			try_apply_stamp(tool)
			return_stamp(tool)
	elif event is InputEventMouseMotion and tool.get_meta("dragging"):
		tool.position += event.relative


func try_apply_stamp(tool: Panel) -> void:
	if not is_instance_valid(form):
		return
	var center := tool.get_global_rect().get_center()
	if form.get_global_rect().has_point(center):
		apply_stamp(String(tool.get_meta("kind")), center - form.global_position)


func return_stamp(tool: Panel) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tool, "position", tool.get_meta("home"), 0.3)
	tween.tween_property(tool, "scale", Vector2.ONE, 0.18)
	tween.finished.connect(func(): tool.z_index = 0)


func create_case() -> void:
	if is_instance_valid(form):
		form.queue_free()
	form_stamped = false
	form_stamp_type = ""
	var data: Dictionary = CASES[case_index % CASES.size()]
	applicant_card_label.text = "%s\n%s\n%s" % [data.applicant, data.code, data.department]
	form = Panel.new()
	form.name = "ApplicationForm"
	form.position = form_home
	form.size = Vector2(485, 475)
	form.pivot_offset = form.size / 2.0
	form.scale = form_base_scale
	form.add_theme_stylebox_override("panel", style_box(colors.paper, 2, Color("786f58"), 2))
	form.gui_input.connect(_on_form_input)
	add_child(form)
	form.z_index = 5

	var shadow := Panel.new()
	shadow.name = "PaperShadow"
	shadow.position = Vector2(10, 12)
	shadow.size = form.size
	shadow.show_behind_parent = true
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", style_box(Color(0, 0, 0, 0.34), 3))
	form.add_child(shadow)

	add_text(form, data.department, 15, colors.ink, Vector2(28, 20), Vector2(390, 24))
	var heading := add_text(form, "现实事项申请表", 28, colors.ink, Vector2(28, 52), Vector2(420, 42))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_text(form, data.code, 13, Color("565647"), Vector2(28, 100), Vector2(420, 22))
	add_text(form, "申请人", 12, Color("666252"), Vector2(28, 135), Vector2(80, 20))
	add_text(form, data.applicant, 17, colors.ink, Vector2(28, 157), Vector2(420, 27))
	add_text(form, "申请事项", 12, Color("666252"), Vector2(28, 198), Vector2(80, 20))
	add_text(form, data.request, 16, colors.ink, Vector2(28, 220), Vector2(420, 48))
	add_text(form, "形式审查", 13, Color("666252"), Vector2(28, 278), Vector2(120, 22))
	for i in data.checks.size():
		var check := CheckBox.new()
		check.text = data.checks[i]
		check.position = Vector2(28, 305 + i * 35)
		check.size = Vector2(420, 30)
		check.add_theme_font_size_override("font_size", 14)
		check.add_theme_color_override("font_color", colors.ink)
		check.add_theme_color_override("font_pressed_color", colors.ink)
		form.add_child(check)

	add_text(form, "批准不构成生效、时限或行政承诺。", 12, Color("6b5747"), Vector2(28, 422), Vector2(420, 24))
	stamp_mark = Label.new()
	stamp_mark.position = Vector2(300, 342)
	stamp_mark.size = Vector2(150, 62)
	stamp_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp_mark.rotation = -0.12
	stamp_mark.add_theme_font_size_override("font_size", 27)
	stamp_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	form.add_child(stamp_mark)


func _on_form_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging_form = true
			form_drag_offset = event.position
			form.z_index = 10
			var tween := create_tween().set_parallel(true)
			tween.tween_property(form, "scale", form_base_scale * 1.035, 0.1)
			tween.tween_property(form, "rotation", -0.012, 0.1)
		else:
			dragging_form = false
			form.z_index = 5
			var tween := create_tween().set_parallel(true)
			tween.tween_property(form, "scale", form_base_scale, 0.12)
			tween.tween_property(form, "rotation", 0.0, 0.12)
			if form.get_global_rect().intersects(slot.get_global_rect()):
				submit_form()
	elif event is InputEventMouseMotion and dragging_form:
		form.position += event.relative


func apply_stamp(kind: String, local_position: Vector2) -> void:
	form_stamped = true
	form_stamp_type = kind
	stamp_mark.text = kind + "\n已作形式处理"
	stamp_mark.position = Vector2(clamp(local_position.x - 75, 20, 315), clamp(local_position.y - 31, 300, 390))
	var color: Color = colors.green if kind == "批准" else colors.red
	stamp_mark.add_theme_color_override("font_color", color)
	stamp_mark.add_theme_constant_override("outline_size", 2)
	stamp_mark.add_theme_color_override("font_outline_color", Color(color, 0.25))
	stamp_mark.scale = Vector2(1.45, 1.45)
	stamp_mark.modulate.a = 0.35
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(stamp_mark, "scale", Vector2.ONE, 0.2)
	tween.tween_property(stamp_mark, "modulate:a", 0.88, 0.28)
	status_label.text = "已加盖“%s”印章，可送交现实验收。" % kind


func submit_form() -> void:
	dragging_form = false
	if not form_stamped:
		status_label.text = "材料退回：未发现有效的形式处理印记。"
		flash_slot(colors.red)
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(form, "position", form_home, 0.45)
		return
	status_label.text = "材料已接收。批准不构成现实效力承诺。"
	flash_slot(colors.green_glow)
	form.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target := slot.global_position + Vector2(80, 76)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(form, "global_position", target, 0.55)
	tween.tween_property(form, "scale", Vector2(0.28, 0.06), 0.55)
	tween.tween_property(form, "modulate:a", 0.0, 0.5).set_delay(0.18)
	tween.finished.connect(show_validation_transition)


func show_validation_transition() -> void:
	validation_overlay.visible = true
	validation_overlay.modulate.a = 0.0
	validation_image.scale = Vector2(1.035, 1.035)
	validation_image.pivot_offset = validation_image.size / 2.0
	var fade_in := create_tween().set_parallel(true)
	fade_in.tween_property(validation_overlay, "modulate:a", 1.0, 0.28)
	fade_in.tween_property(validation_image, "scale", Vector2.ONE, 1.4)
	await get_tree().create_timer(1.35).timeout
	var fade_out := create_tween()
	fade_out.tween_property(validation_overlay, "modulate:a", 0.0, 0.32)
	await fade_out.finished
	validation_overlay.visible = false
	next_case()


func next_case() -> void:
	case_index = (case_index + 1) % CASES.size()
	await get_tree().create_timer(0.18).timeout
	create_case()
	form.modulate.a = 0.0
	form.scale = form_base_scale * 0.92
	var tween := create_tween().set_parallel(true)
	tween.tween_property(form, "modulate:a", 1.0, 0.25)
	tween.tween_property(form, "scale", form_base_scale, 0.3)
	status_label.text = "下一件申请已送达。"


func flash_slot(color: Color) -> void:
	slot_light.color = color
	var tween := create_tween()
	for i in 3:
		tween.tween_property(slot_light, "modulate:a", 0.15, 0.1)
		tween.tween_property(slot_light, "modulate:a", 1.0, 0.1)
	tween.tween_callback(func(): slot_light.color = colors.red)


func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var normalized := (get_viewport().get_mouse_position() / viewport_size - Vector2(0.5, 0.5))
	for i in parallax_layers.size():
		var layer := parallax_layers[i]
		if is_instance_valid(layer):
			layer.position += (layer.get_meta("base_position", layer.position) + normalized * float(i + 1) * 1.2 - layer.position) * 0.04


func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	# Fill the complete live viewport; this prototype intentionally allows
	# slight aspect deformation instead of letterboxing or edge cropping.
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO
