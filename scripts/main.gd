extends Node2D

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
var form_home := Vector2(420, 166)
var dragging_form := false
var form_drag_offset := Vector2.ZERO
var form_stamped := false
var form_stamp_type := ""
var stamp_mark: Label
var status_label: Label
var slot: Panel
var slot_light: ColorRect
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
	var backdrop := ColorRect.new()
	backdrop.name = "OfficeBackdrop"
	backdrop.color = colors.wall
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(1280, 720)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var upper_wall := ColorRect.new()
	upper_wall.color = colors.wall_mid
	upper_wall.position = Vector2(0, 0)
	upper_wall.size = Vector2(1280, 280)
	upper_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(upper_wall)
	parallax_layers.append(upper_wall)

	var title := add_text(upper_wall, "中央现实管理局 · 第十二区", 20, Color("9aa398"), Vector2(42, 28), Vector2(520, 30))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", colors.wall)

	var terminal := Panel.new()
	terminal.name = "ApplicantTerminal"
	terminal.position = Vector2(42, 84)
	terminal.size = Vector2(290, 205)
	terminal.add_theme_stylebox_override("panel", style_box(Color("111816"), 8, colors.brass, 3))
	upper_wall.add_child(terminal)
	parallax_layers.append(terminal)
	add_text(terminal, "申请人通信终端", 15, colors.green_glow, Vector2(18, 14), Vector2(240, 25))
	add_text(terminal, "信号已建立\n身份影像：受限\n语音记录：等待调阅", 17, colors.green, Vector2(18, 58), Vector2(250, 110))

	slot = Panel.new()
	slot.name = "RealityValidationSlot"
	slot.position = Vector2(932, 62)
	slot.size = Vector2(300, 170)
	slot.add_theme_stylebox_override("panel", style_box(Color("101312"), 4, colors.brass, 3))
	upper_wall.add_child(slot)
	parallax_layers.append(slot)
	add_text(slot, "现实验收设施 / 接收口", 15, Color("bab09a"), Vector2(18, 14), Vector2(250, 25))
	var opening := ColorRect.new()
	opening.color = Color("050606")
	opening.position = Vector2(28, 72)
	opening.size = Vector2(244, 30)
	opening.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(opening)
	slot_light = ColorRect.new()
	slot_light.color = colors.red
	slot_light.position = Vector2(258, 18)
	slot_light.size = Vector2(14, 14)
	slot_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(slot_light)
	add_text(slot, "仅接收已完成形式处理之材料", 12, Color("766e60"), Vector2(28, 118), Vector2(250, 22))

	var desk_shadow := Polygon2D.new()
	desk_shadow.polygon = PackedVector2Array([Vector2(20, 302), Vector2(1260, 302), Vector2(1280, 720), Vector2(0, 720)])
	desk_shadow.color = colors.desk_edge
	add_child(desk_shadow)
	var desk := Polygon2D.new()
	desk.name = "DeskPerspective"
	desk.polygon = PackedVector2Array([Vector2(70, 320), Vector2(1210, 320), Vector2(1280, 690), Vector2(0, 690)])
	desk.color = colors.desk
	add_child(desk)

	var blotter := Polygon2D.new()
	blotter.polygon = PackedVector2Array([Vector2(310, 350), Vector2(930, 350), Vector2(1015, 690), Vector2(230, 690)])
	blotter.color = Color("28322d")
	add_child(blotter)

	status_label = add_text(self, "请完成申请的形式处理。", 16, Color("c7bda5"), Vector2(32, 680), Vector2(760, 28))

	create_stamp_tool("批准", colors.green, Vector2(1030, 440))
	create_stamp_tool("驳回", colors.red, Vector2(1135, 510))


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
	form = Panel.new()
	form.name = "ApplicationForm"
	form.position = form_home
	form.size = Vector2(485, 475)
	form.pivot_offset = form.size / 2.0
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
			tween.tween_property(form, "scale", Vector2(1.025, 1.025), 0.1)
			tween.tween_property(form, "rotation", -0.012, 0.1)
		else:
			dragging_form = false
			form.z_index = 5
			var tween := create_tween().set_parallel(true)
			tween.tween_property(form, "scale", Vector2.ONE, 0.12)
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
	tween.finished.connect(next_case)


func next_case() -> void:
	case_index = (case_index + 1) % CASES.size()
	await get_tree().create_timer(0.45).timeout
	create_case()
	form.modulate.a = 0.0
	form.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(form, "modulate:a", 1.0, 0.25)
	tween.tween_property(form, "scale", Vector2.ONE, 0.3)
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
