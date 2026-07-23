extends Node2D

const WORKBENCH_TEXTURE := preload("res://assets/day1_8bit/background/office_validation_room.png")
const VALIDATION_TEXTURE := preload("res://assets/day1_8bit/interactive/validation_machine.png")
const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")
const APPROVE_STAMP_TEXTURE := preload("res://assets/day1_8bit/interactive/approve_stamp.png")
const RETURN_STAMP_TEXTURE := preload("res://assets/day1_8bit/interactive/return_stamp.png")

var case_index := 0
var current_case: Dictionary = {}
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


# 进入主工作台场景时调用。
# 依次构建完整的办公桌场景、创建第一份申请表单，为所有视差层记录基准位置，
# 并连接视口尺寸变化信号以持续适配 1280x720 的基准分辨率。
func _ready() -> void:
	build_scene()
	LevelDirector.ensure_active_level()
	current_case = LevelDirector.get_next_case()
	create_case()
	for layer in parallax_layers:
		layer.set_meta("base_position", layer.position)
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


# 创建 StyleBoxFlat 的辅助工厂方法。
# 可设置背景色、圆角、边框颜色与边框宽度；仅当 border 大于 0 时才配置四边边框，避免无意义的开销。
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


# 通用文本标签工厂方法。
# 在指定 parent 下创建 Label，配置字体大小、像素字体、颜色、位置、尺寸与智能自动换行，并返回 Label 引用供后续修改。
func add_text(parent: Node, text: String, size: int, color: Color, position: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = dimensions
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


# 构建整个主工作台视觉场景。
# 依次添加背景图、暗角、申请人档案卡、现实验收送交槽、状态栏、批准/驳回印章工具，
# 并调用 create_validation_overlay() 创建送交后的设施转场层。
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

	create_stamp_tool("批准", colors.green, Vector2(850, 565))
	create_stamp_tool("驳回", colors.red, Vector2(945, 565))
	create_validation_overlay()


# 创建送交申请后的“现实验收设施”转场动画层。
# 包含设施图片、半透明遮罩与提示文字，初始状态为隐藏，由 submit_form() 在完成送交后触发显示。
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
	validation_image.position = Vector2(425, 95)
	validation_image.size = Vector2(430, 470)
	validation_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	validation_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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


# 创建一枚可拖拽的印章工具。
# kind 为印章类型（“批准”或“驳回”），决定显示的印章纹理；color 用于悬停反馈；at 为印章默认位置。
# 设置 home 位置、类型元数据与拖拽标记，绑定 gui_input 与鼠标悬停事件，并加入 stamp_tools 数组统一管理。
func create_stamp_tool(kind: String, color: Color, at: Vector2) -> void:
	var tool := Panel.new()
	tool.name = kind + "Stamp"
	var visual_position := at - Vector2(18, 20)
	tool.position = visual_position
	tool.size = Vector2(140, 132)
	tool.set_meta("home", visual_position)
	tool.set_meta("kind", kind)
	tool.set_meta("dragging", false)
	tool.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tool.add_theme_stylebox_override("panel", style_box(Color(0, 0, 0, 0), 0))
	add_child(tool)
	stamp_tools.append(tool)
	var stamp_image := TextureRect.new()
	stamp_image.texture = APPROVE_STAMP_TEXTURE if kind == "批准" else RETURN_STAMP_TEXTURE
	stamp_image.position = Vector2.ZERO
	stamp_image.size = Vector2(140, 132)
	stamp_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stamp_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool.add_child(stamp_image)
	tool.gui_input.connect(_on_stamp_input.bind(tool))
	tool.mouse_entered.connect(_on_stamp_hover.bind(tool, true))
	tool.mouse_exited.connect(_on_stamp_hover.bind(tool, false))


# 鼠标进入或离开印章时的悬停反馈。
# 当印章未被拖拽时，通过 Tween 轻微放大（1.04）或恢复原始尺寸，增强交互感。
func _on_stamp_hover(tool: Panel, entered: bool) -> void:
	if bool(tool.get_meta("dragging")):
		return
	var tween := create_tween()
	tween.tween_property(tool, "scale", Vector2(1.04, 1.04) if entered else Vector2.ONE, 0.08)


# 印章的鼠标事件处理。
# 左键按下时开始拖拽，记录鼠标相对于印章的偏移、提升 z_index 并放大；
# 左键释放时取消拖拽，调用 try_apply_stamp() 尝试盖章，然后调用 return_stamp() 使印章归位；
# 鼠标移动且处于拖拽状态时，更新印章位置。
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


# 释放印章时判断是否盖到申请表上。
# 计算印章中心点，若该点位于申请表的全局矩形内，则在申请表本地坐标下盖上对应类型的印章。
func try_apply_stamp(tool: Panel) -> void:
	if not is_instance_valid(form):
		return
	var center := tool.get_global_rect().get_center()
	if form.get_global_rect().has_point(center):
		apply_stamp(String(tool.get_meta("kind")), center - form.global_position)


# 通过 Tween 将印章平滑归位到 home 位置并恢复原始缩放。
# 动画结束后将 z_index 重置为 0，避免影响后续交互层级。
func return_stamp(tool: Panel) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tool, "position", tool.get_meta("home"), 0.3)
	tween.tween_property(tool, "scale", Vector2.ONE, 0.18)
	tween.finished.connect(func(): tool.z_index = 0)


# 创建当前案件的申请表单。
# 先销毁旧表单（如果存在），重置盖章状态；从 CASES 数组中循环取出当前案件数据，更新右侧申请人档案卡；
# 然后新建申请表单面板、阴影、部门标题、申请表头、申请人信息、申请事项、形式审查复选框以及盖章标记占位。
func create_case() -> void:
	if is_instance_valid(form):
		form.queue_free()
	form_stamped = false
	form_stamp_type = ""
	var data := current_case
	if data.is_empty():
		applicant_card_label.text = "配置错误\n未能生成当前案件"
		status_label.text = "无法生成案件，请打开 DEV 控制台检查配置。"
		return
	applicant_card_label.text = "%s\n%s\n%s" % [data.applicant, data.code, data.department]
	form = Panel.new()
	form.name = "ApplicationForm"
	form.position = form_home
	form.size = Vector2(485, 475)
	form.pivot_offset = form.size / 2.0
	form.scale = form_base_scale
	form.add_theme_stylebox_override("panel", style_box(colors.paper, 2, Color("786f58"), 2))
	form.gui_input.connect(_on_form_input)
	form.mouse_default_cursor_shape = Control.CURSOR_MOVE
	form.mouse_entered.connect(_on_form_hover.bind(true))
	form.mouse_exited.connect(_on_form_hover.bind(false))
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
		check.add_theme_font_override("font", PIXEL_FONT)
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
	stamp_mark.add_theme_font_override("font", PIXEL_FONT)
	stamp_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	form.add_child(stamp_mark)


# 鼠标悬停在申请表上时的缩放反馈。
# 未拖拽时轻微放大表单（1.012 倍），模拟纸张被注意到的视觉效果；鼠标离开时恢复原始尺寸。
func _on_form_hover(entered: bool) -> void:
	if dragging_form or not is_instance_valid(form):
		return
	var target_scale := form_base_scale * (1.012 if entered else 1.0)
	var tween := create_tween()
	tween.tween_property(form, "scale", target_scale, 0.08)


# 申请表的拖拽与提交处理。
# 左键按下时开始拖拽，记录鼠标偏移、提升 z_index 并轻微倾斜放大；
# 左键释放时恢复形态，若表单矩形与送交槽相交则调用 submit_form() 完成送交；
# 鼠标移动且处于拖拽状态时，根据相对位移更新表单位置。
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


# 在申请表上生成“批准”或“驳回”的印章文字。
# kind 为印章类型；local_position 为印章中心相对于表单左上角的本地坐标。
# 记录盖章状态与类型，将印章位置裁剪到合理区域，设置对应颜色与描边，
# 并通过 Tween 播放从放大半透明到正常显示的动画，同时更新状态栏提示。
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


# 将处理完毕的表单送交现实验收。
# 若表单未盖章，则提示“材料退回”并通过 Tween 将表单弹回原位，同时闪烁红灯；
# 若已盖章，则将案件结果记录到 WorkdayState，闪烁绿灯，禁用表单交互，播放表单被吸入验收槽的动画，
# 动画结束后调用 show_validation_transition() 进入设施转场。
func submit_form() -> void:
	dragging_form = false
	if not form_stamped:
		status_label.text = "材料退回：未发现有效的形式处理印记。"
		flash_slot(colors.red)
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(form, "position", form_home, 0.45)
		return
	status_label.text = "材料已接收。批准不构成现实效力承诺。"
	WorkdayState.record_case(current_case, form_stamp_type)
	flash_slot(colors.green_glow)
	form.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target := slot.global_position + Vector2(80, 76)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(form, "global_position", target, 0.55)
	tween.tween_property(form, "scale", Vector2(0.28, 0.06), 0.55)
	tween.tween_property(form, "modulate:a", 0.0, 0.5).set_delay(0.18)
	tween.finished.connect(show_validation_transition)


# 播放现实验收设施的转场动画。
# 先淡入设施图片并伴随轻微缩放复位，停留约 1.35 秒后淡出；
# 若当日记录数量已达 CASES_PER_DAY 则切换到日报场景；否则调用 next_case() 继续处理下一份申请。
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
	if WorkdayState.should_show_report():
		var error: Error = get_tree().change_scene_to_file("res://scenes/daily_report.tscn")
		if error != OK:
			status_label.text = "内部日报生成失败，当前记录已保留。"
			next_case()
	else:
		next_case()


# 推进到下一个案件。
# 案件索引循环递增，短暂延迟后调用 create_case() 生成新表单，并播放从透明缩小到正常显示的入场动画，状态栏提示下一份申请已送达。
func next_case() -> void:
	case_index += 1
	await get_tree().create_timer(0.18).timeout
	current_case = LevelDirector.get_next_case()
	create_case()
	if not is_instance_valid(form):
		return
	form.modulate.a = 0.0
	form.scale = form_base_scale * 0.92
	var tween := create_tween().set_parallel(true)
	tween.tween_property(form, "modulate:a", 1.0, 0.25)
	tween.tween_property(form, "scale", form_base_scale, 0.3)
	status_label.text = "下一件申请已送达。"


# 让验收槽指示灯按指定颜色闪烁三次，用于提供视觉反馈。
# 闪烁结束后恢复为默认红色。
func flash_slot(color: Color) -> void:
	slot_light.color = color
	var tween := create_tween()
	for i in 3:
		tween.tween_property(slot_light, "modulate:a", 0.15, 0.1)
		tween.tween_property(slot_light, "modulate:a", 1.0, 0.1)
	tween.tween_callback(func(): slot_light.color = colors.red)


# 每帧更新背景视差效果。
# 根据鼠标位置相对于屏幕中心计算归一化偏移，使 parallax_layers 中的各层以不同幅度（i + 1）产生轻微移动，增强场景深度感。
func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var normalized := (get_viewport().get_mouse_position() / viewport_size - Vector2(0.5, 0.5))
	for i in parallax_layers.size():
		var layer := parallax_layers[i]
		if is_instance_valid(layer):
			layer.position += (layer.get_meta("base_position", layer.position) + normalized * float(i + 1) * 1.2 - layer.position) * 0.04


# 以 1280x720 为设计分辨率，按实际视口尺寸缩放整个 Node2D 并将位置归零。
# 该原型允许轻微形变以填满屏幕，避免黑边或裁剪。
func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	# Fill the complete live viewport; this prototype intentionally allows
	# slight aspect deformation instead of letterboxing or edge cropping.
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO
