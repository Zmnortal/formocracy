extends Control

const PRE_WORK_SCENE := "res://scenes/pre_work_sequence.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const FORM_TEXTURE := preload("res://assets/opening/position-reinstatement-form-v2.png")
const MACHINE_TEXTURE := preload("res://assets/day1_8bit/interactive/validation_machine.png")
const PIXEL_FONT := preload("res://assets/fonts/unifont/unifont_ui.tres")
const PIXEL_THEME := preload("res://themes/pixel_theme.tres")
const SignaturePadScene := preload("res://scripts/ui/signature_pad.gd")
const HandwrittenCheckScene := preload("res://scripts/ui/handwritten_check.gd")
const PaperReplaceHandleScene := preload("res://scripts/ui/paper_replace_handle.gd")
const UI := preload("res://scripts/ui/bureau_ui.gd")
const APPROACH_FRAME_COUNT := 8
const INGEST_FRAME_COUNT := 10
const STOP_MOTION_FRAME_SECONDS := 0.25
# 只捕获纸张本体。旧实现捕获整张 1280×720 场景，纸外的黑色背景也会
# 被 Polygon2D 压成一个黑框；同时透视顶点围绕整屏而不是纸张四边计算。
const FORM_CAPTURE_RECT := Rect2i(325, 30, 634, 662)
# 纸张先以完整矩形出现，再让远端边朝机器口移动、近端边留在传送带前方。
# 明确记录四边的目标位置，避免用中心缩放造成“从纸张中间向内塌缩”的观感。
const FORM_START_TOP_WIDTH := 634.0
const FORM_START_BOTTOM_WIDTH := 634.0
const FORM_START_TOP_Y := 30.0
const FORM_START_BOTTOM_Y := 692.0
const FORM_APPROACH_TOP_WIDTH := 208.0
const FORM_APPROACH_BOTTOM_WIDTH := 440.0
const FORM_APPROACH_TOP_Y := 332.0
const FORM_APPROACH_BOTTOM_Y := 628.0
const FORM_INGEST_TOP_WIDTH := 180.0
const FORM_INGEST_BOTTOM_WIDTH := 204.0
const FORM_INGEST_TOP_Y := 346.0
const FORM_INGEST_BOTTOM_Y := 374.0

var form_stage: Control
var form_viewport: SubViewport
var projected_form: Polygon2D
var machine: TextureRect
var machine_foreground: TextureRect
var black: ColorRect
var name_input: LineEdit
var year_input: LineEdit
var month_input: LineEdit
var day_input: LineEdit
var signature_pad
var confirmation
var confirm_button: Button
var status_label: Label
var paper_replace_handle
var opening_exiting := false
var submission_locked := false
var replacing_form := false
var submission_snap_count := 0
var submission_phase := "form"
var opening_pixel_font: FontVariation


# 播放开场音乐、搭建场景并启动表单浮现动画。
func _ready() -> void:
	OpeningMusic.play_opening()
	_configure_pixel_font_rendering()
	_build_scene()
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	_play_form_reveal()


# 强制开场中文字体使用无抗锯齿栅格，并以最近邻方式随画布缩放。
# 字体导入虽然已经关闭抗锯齿，但默认线性过滤仍会在窗口拉伸时重新模糊字形边缘。
func _configure_pixel_font_rendering() -> void:
	# 通过运行时引用配置预载资源；GDScript 不允许直接给 const 资源属性赋值。
	opening_pixel_font = PIXEL_FONT
	var primary_font := opening_pixel_font.base_font as FontFile
	primary_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	primary_font.generate_mipmaps = false
	primary_font.multichannel_signed_distance_field = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


# 构建开场全部节点：黑幕、验收机器、表单舞台与欢迎面板。
func _build_scene() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = PIXEL_THEME

	black = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)

	machine = TextureRect.new()
	machine.name = "ValidationMachine"
	machine.texture = MACHINE_TEXTURE
	machine.position = Vector2(417, 96)
	machine.size = Vector2(446, 502)
	machine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	machine.stretch_mode = TextureRect.STRETCH_SCALE
	machine.modulate.a = 0.0
	add_child(machine)

	form_stage = Control.new()
	form_stage.name = "ReinstatementForm"
	form_stage.size = Vector2(1280, 720)
	form_stage.pivot_offset = Vector2(640, 360)
	form_stage.modulate.a = 0.0
	add_child(form_stage)

	var form_image := TextureRect.new()
	form_image.name = "FormArtwork"
	form_image.texture = FORM_TEXTURE
	form_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	form_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	form_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	form_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	form_stage.add_child(form_image)

	_add_form_copy()
	_add_form_inputs()

	_build_machine_foreground()


# 在表单舞台上添加标题、档案编号等印刷文案标签。
func _add_form_copy() -> void:
	var title := _make_label("职位恢复申请", 30, Vector2(408, 122), Vector2(464, 42))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form_stage.add_child(title)
	var subtitle := _make_label("中央现实管理局 · 人事复核处", 15, Vector2(408, 158), Vector2(464, 24), true)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form_stage.add_child(subtitle)
	var file_label := _make_label("档案编号", 13, Vector2(642, 205), Vector2(88, 25), true)
	file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	form_stage.add_child(file_label)
	var file_number := _make_label("R-01 / 恢复", 15, Vector2(752, 205), Vector2(148, 25))
	file_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form_stage.add_child(file_number)
	form_stage.add_child(_make_label("法定姓名", 17, Vector2(360, 228), Vector2(160, 28)))
	form_stage.add_child(_make_label("恢复日期（当天）", 17, Vector2(360, 315), Vector2(220, 28)))
	form_stage.add_child(_make_label("申请人亲笔签名", 17, Vector2(455, 402), Vector2(220, 26)))


# 创建姓名、日期输入框、签名板、确认勾选与提交按钮。
func _add_form_inputs() -> void:
	name_input = _make_line_edit(Vector2(372, 258), Vector2(536, 46), "请输入姓名")
	name_input.name = "NameInput"
	name_input.text_changed.connect(_on_form_changed)
	form_stage.add_child(name_input)

	var today := Time.get_date_dict_from_system()
	year_input = _make_date_input(Vector2(365, 363), 140, "年", 4)
	month_input = _make_date_input(Vector2(570, 363), 120, "月", 2)
	day_input = _make_date_input(Vector2(755, 363), 120, "日", 2)
	year_input.placeholder_text = str(today.year)
	month_input.placeholder_text = "%02d" % today.month
	day_input.placeholder_text = "%02d" % today.day

	signature_pad = SignaturePadScene.new()
	signature_pad.name = "SignaturePad"
	signature_pad.position = Vector2(455, 442)
	signature_pad.size = Vector2(480, 80)
	signature_pad.signature_changed.connect(_on_signature_changed)
	form_stage.add_child(signature_pad)

	paper_replace_handle = PaperReplaceHandleScene.new()
	paper_replace_handle.name = "PaperReplaceHandle"
	paper_replace_handle.position = Vector2(895, 630)
	paper_replace_handle.size = Vector2(48, 48)
	paper_replace_handle.replacement_requested.connect(replace_entire_form)
	form_stage.add_child(paper_replace_handle)

	confirmation = HandwrittenCheckScene.new()
	confirmation.name = "Confirmation"
	# 透明手写区刻意大于纸上的印刷方框，允许勾画自然越过边界。
	confirmation.position = Vector2(448, 525)
	confirmation.size = Vector2(72, 58)
	confirmation.toggled.connect(_on_confirmation_toggled)
	form_stage.add_child(confirmation)
	var confirmation_copy := _make_label("本人确认以上信息由本人填写，并接受职位恢复审查。", 15, Vector2(515, 535), Vector2(415, 34))
	confirmation_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	form_stage.add_child(confirmation_copy)

	status_label = _make_label("请完整填写姓名、当天日期并亲笔签名", 14, Vector2(405, 606), Vector2(470, 24), true)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form_stage.add_child(status_label)

	confirm_button = Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = "确认并提交"
	confirm_button.position = Vector2(500, 622)
	confirm_button.size = Vector2(280, 54)
	UI.style_button(confirm_button, 20)
	confirm_button.visible = false
	confirm_button.pressed.connect(submit_form)
	form_stage.add_child(confirm_button)


# 裁切机器插槽下沿作为前景遮挡层，用于吞入阶段的遮挡效果。
func _build_machine_foreground() -> void:
	var mouth_texture := AtlasTexture.new()
	mouth_texture.atlas = MACHINE_TEXTURE
	# 只分离机器插槽的下沿。大块矩形裁切会像一张贴图压在纸面上，
	# 这里保留很窄的一层，用来在吞入阶段建立“纸张进入插槽后方”的遮挡。
	mouth_texture.region = Rect2(83, 164, 164, 48)
	machine_foreground = TextureRect.new()
	machine_foreground.name = "MachineMouthForeground"
	machine_foreground.texture = mouth_texture
	machine_foreground.position = Vector2(529, 318)
	machine_foreground.size = Vector2(222, 65)
	machine_foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	machine_foreground.stretch_mode = TextureRect.STRETCH_SCALE
	machine_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	machine_foreground.modulate.a = 0.0
	add_child(machine_foreground)


# 创建带纸面配色的文本标签。
func _make_label(text: String, font_size: int, at: Vector2, dimensions: Vector2, muted := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	UI.style_label(label, font_size, muted)
	label.add_theme_color_override("font_color", Color("45432e") if muted else Color("29291d"))
	return label


# 创建透明底、像素字体样式的单行输入框。
func _make_line_edit(at: Vector2, dimensions: Vector2, placeholder: String) -> LineEdit:
	var input := LineEdit.new()
	input.position = at
	input.size = dimensions
	input.placeholder_text = placeholder
	input.add_theme_font_override("font", PIXEL_FONT)
	input.add_theme_font_size_override("font_size", 23)
	input.add_theme_color_override("font_color", Color("29291d"))
	input.add_theme_color_override("font_placeholder_color", Color(0.25, 0.25, 0.18, 0.48))
	input.add_theme_stylebox_override("normal", _make_input_box(Color(0.94, 0.88, 0.69, 0.0)))
	input.add_theme_stylebox_override("focus", _make_input_box(Color(0.94, 0.88, 0.69, 0.0)))
	return input


# 创建输入框使用的纯色内边距样式盒。
func _make_input_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0
	return box


# 创建限制长度的数字日期输入框并附加单位后缀标签。
func _make_date_input(at: Vector2, width: float, suffix: String, max_length: int) -> LineEdit:
	var input := _make_line_edit(at, Vector2(width, 46), "")
	input.max_length = max_length
	input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	input.text_changed.connect(_on_date_changed.bind(input))
	form_stage.add_child(input)
	var suffix_label := _make_label(suffix, 17, at + Vector2(width + 8, 10), Vector2(42, 28))
	form_stage.add_child(suffix_label)
	return input


# 日期输入变化时过滤非数字字符并刷新表单校验。
func _on_date_changed(value: String, input: LineEdit) -> void:
	var digits := ""
	for character in value:
		if character >= "0" and character <= "9":
			digits += character
	if input.text != digits:
		input.text = digits
		input.caret_column = digits.length()
	_on_form_changed(digits)


# 表单内容变化时播放打字音效并刷新校验状态。
func _on_form_changed(_value := "") -> void:
	Sfx.typewriter_tick()
	refresh_form_validity()


# 签名状态变化时刷新表单校验。
func _on_signature_changed(_has_signature: bool) -> void:
	refresh_form_validity()


# 声明勾选状态变化时刷新表单校验。
func _on_confirmation_toggled(_pressed: bool) -> void:
	refresh_form_validity()


# 校验姓名、日期、签名与勾选，更新提示文案与提交按钮可见性。
func refresh_form_validity() -> void:
	if confirm_button == null:
		return
	var name_valid := name_input.text.strip_edges().length() >= 2
	var date_valid := entered_date() == current_date()
	var signature_valid: bool = signature_pad.has_signature()
	var ready: bool = name_valid and date_valid and signature_valid and bool(confirmation.button_pressed)
	confirm_button.visible = ready
	if not name_valid:
		status_label.text = "请填写法定姓名"
	elif not date_valid:
		status_label.text = "恢复日期必须填写今天：%s" % current_date()
	elif not signature_valid:
		status_label.text = "请在签名栏内亲笔签名"
	elif not confirmation.button_pressed:
		status_label.text = "请在声明框内亲手画勾"
	else:
		status_label.text = "表单已完整，可以提交验收"


# 返回用户填写的日期字符串，未填完整时返回空串。
func entered_date() -> String:
	if year_input.text.is_empty() or month_input.text.is_empty() or day_input.text.is_empty():
		return ""
	return "%04d-%02d-%02d" % [int(year_input.text), int(month_input.text), int(day_input.text)]


# 返回系统当天日期的格式化字符串。
func current_date() -> String:
	var today := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [today.year, today.month, today.day]


# 延迟后淡入表单舞台，完成后聚焦姓名输入框。
func _play_form_reveal() -> void:
	await get_tree().create_timer(0.65).timeout
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(form_stage, "modulate:a", 1.0, 1.15)
	await reveal.finished
	if not submission_locked:
		name_input.grab_focus()


# 作废当前纸张并换取空白新表：旧表被抽走，新表从另一侧铺回，所有字段一起清空。
func replace_entire_form() -> void:
	if submission_locked or replacing_form:
		return
	replacing_form = true
	set_form_interaction(false)
	Sfx.play("ui_switch", -3.0, 0.86)
	status_label.text = "当前表单作废，正在换取空白新表……"
	confirm_button.visible = false

	var duration := 0.0 if DisplayServer.get_name() == "headless" else 0.42
	var discard := create_tween()
	discard.set_parallel(true)
	discard.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	discard.tween_property(form_stage, "position", Vector2(-420, 72), duration)
	discard.tween_property(form_stage, "rotation_degrees", -4.0, duration)
	discard.tween_property(form_stage, "scale", Vector2(0.96, 0.96), duration)
	discard.tween_property(form_stage, "modulate:a", 0.0, duration)
	await discard.finished

	_clear_entire_form()
	form_stage.position = Vector2(380, -36)
	form_stage.rotation_degrees = 3.5
	form_stage.scale = Vector2(0.97, 0.97)
	form_stage.modulate.a = 0.0

	var replace_duration := 0.0 if DisplayServer.get_name() == "headless" else 0.56
	var replacement := create_tween()
	replacement.set_parallel(true)
	replacement.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	replacement.tween_property(form_stage, "position", Vector2.ZERO, replace_duration)
	replacement.tween_property(form_stage, "rotation_degrees", 0.0, replace_duration)
	replacement.tween_property(form_stage, "scale", Vector2.ONE, replace_duration)
	replacement.tween_property(form_stage, "modulate:a", 1.0, replace_duration)
	await replacement.finished

	replacing_form = false
	set_form_interaction(true)
	name_input.grab_focus()


# 清空整张申请表，而不是只擦除签名。
func _clear_entire_form() -> void:
	name_input.text = ""
	year_input.text = ""
	month_input.text = ""
	day_input.text = ""
	signature_pad.clear_signature()
	confirmation.drawing = false
	confirmation.button_pressed = false
	status_label.visible = true
	status_label.text = "请完整填写姓名、当天日期并亲笔签名"
	confirm_button.visible = false


# 提交表单：锁定交互、保存填写信息并播放吞入动画。
func submit_form() -> void:
	if submission_locked or not confirm_button.visible:
		return
	submission_locked = true
	Sfx.play("ui_click")
	WorkdayState.player_name = name_input.text.strip_edges()
	WorkdayState.reinstatement_date = entered_date()
	WorkdayState.player_signature = signature_pad.serialize_strokes()
	set_form_interaction(false)
	# 只捕获完成后的纸面内容，开发交互控件不应进入吞噬动画。
	confirm_button.visible = false
	status_label.visible = false
	paper_replace_handle.visible = false
	await _prepare_projected_form()
	await _play_submission()


# 统一开关表单各输入控件的交互与焦点能力。
func set_form_interaction(enabled: bool) -> void:
	for input: LineEdit in [name_input, year_input, month_input, day_input]:
		# 不使用 editable/disabled 状态，避免提交后 Godot 自动切换输入框颜色。
		input.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		input.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		if not enabled:
			input.release_focus()
	signature_pad.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	confirmation.disabled = not enabled
	confirm_button.disabled = not enabled
	paper_replace_handle.disabled = not enabled


# 依次播放靠近、吞入和机器淡出，随后进入每日晨间上班序列。
func _play_submission() -> void:
	await _play_stop_motion_approach()
	await _play_stop_motion_ingestion()
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.5).timeout
	await _fade_machine_out()
	complete_reinstatement()


# 将表单内容捕获为投影多边形纹理，供定格动画变形使用。
func _prepare_projected_form() -> void:
	projected_form = Polygon2D.new()
	projected_form.name = "ProjectedForm"
	if DisplayServer.get_name() == "headless":
		# Headless 渲染器不推进 SubViewport 捕获；测试使用静态纹理验证几何与时序。
		projected_form.texture = FORM_TEXTURE
		form_stage.visible = false
	else:
		form_viewport = SubViewport.new()
		form_viewport.name = "FormCaptureViewport"
		form_viewport.size = FORM_CAPTURE_RECT.size
		form_viewport.transparent_bg = true
		form_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(form_viewport)
		form_stage.reparent(form_viewport)
		# 把纸张区域的左上角移动到捕获视口原点，完全排除纸外黑色背景。
		form_stage.position = -Vector2(FORM_CAPTURE_RECT.position)
		form_stage.scale = Vector2.ONE
		form_stage.rotation_degrees = 0.0
		projected_form.texture = form_viewport.get_texture()
	var capture_size := Vector2(FORM_CAPTURE_RECT.size)
	projected_form.uv = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(capture_size.x, 0),
			capture_size,
			Vector2(0, capture_size.y),
		]
	)
	_set_projected_form_edges(FORM_START_TOP_WIDTH, FORM_START_BOTTOM_WIDTH, FORM_START_TOP_Y, FORM_START_BOTTOM_Y)
	add_child(projected_form)
	move_child(projected_form, machine_foreground.get_index())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


# 播放纸张逐帧缩小靠近机器的定格动画，同时淡入机器。
func _play_stop_motion_approach() -> void:
	submission_phase = "approach"
	submission_snap_count = 0
	var machine_reveal := create_tween()
	machine_reveal.set_parallel(true)
	machine_reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	machine_reveal.tween_property(machine, "modulate:a", 1.0, APPROACH_FRAME_COUNT * STOP_MOTION_FRAME_SECONDS)

	for frame in range(1, APPROACH_FRAME_COUNT + 1):
		var t := float(frame) / float(APPROACH_FRAME_COUNT)
		_set_projected_form_edges(
			lerpf(FORM_START_TOP_WIDTH, FORM_APPROACH_TOP_WIDTH, t),
			lerpf(FORM_START_BOTTOM_WIDTH, FORM_APPROACH_BOTTOM_WIDTH, t),
			lerpf(FORM_START_TOP_Y, FORM_APPROACH_TOP_Y, t),
			lerpf(FORM_START_BOTTOM_Y, FORM_APPROACH_BOTTOM_Y, t)
		)
		submission_snap_count += 1
		if DisplayServer.get_name() != "headless":
			await get_tree().create_timer(STOP_MOTION_FRAME_SECONDS).timeout
	if DisplayServer.get_name() == "headless":
		machine_reveal.kill()
	# 定格循环与淡入时长相同；循环结束时 Tween 可能已经发出 finished。
	# 此处直接收束到目标状态，避免等待一个已经错过的信号而永久卡住演出。
	machine.modulate.a = 1.0


# 播放纸张被机器逐帧吞入的定格动画并控制传送带音效。
func _play_stop_motion_ingestion() -> void:
	submission_phase = "ingestion"
	Sfx.start_conveyor()
	# 遮挡只在纸张真正进入插槽时出现；靠近机器时不能盖住表单。
	machine_foreground.modulate.a = 1.0
	for frame in range(1, INGEST_FRAME_COUNT + 1):
		var t := float(frame) / float(INGEST_FRAME_COUNT)
		_set_projected_form_edges(
			lerpf(FORM_APPROACH_TOP_WIDTH, FORM_INGEST_TOP_WIDTH, t),
			lerpf(FORM_APPROACH_BOTTOM_WIDTH, FORM_INGEST_BOTTOM_WIDTH, t),
			lerpf(FORM_APPROACH_TOP_Y, FORM_INGEST_TOP_Y, t),
			lerpf(FORM_APPROACH_BOTTOM_Y, FORM_INGEST_BOTTOM_Y, t)
		)
		submission_snap_count += 1
		if DisplayServer.get_name() != "headless":
			await get_tree().create_timer(STOP_MOTION_FRAME_SECONDS).timeout
	projected_form.visible = false
	Sfx.stop_conveyor()


# 根据纸张四边的绝对位置生成稳定梯形。
# 远端边和近端边各自沿传送带移动，不围绕中心点对称缩放。
func _set_projected_form_edges(top_width: float, bottom_width: float, top_y: float, bottom_y: float) -> void:
	var center_x := float(FORM_CAPTURE_RECT.position.x) + float(FORM_CAPTURE_RECT.size.x) * 0.5
	projected_form.polygon = PackedVector2Array(
		[
			Vector2(center_x - top_width * 0.5, top_y),
			Vector2(center_x + top_width * 0.5, top_y),
			Vector2(center_x + bottom_width * 0.5, bottom_y),
			Vector2(center_x - bottom_width * 0.5, bottom_y),
		]
	)


# 将验收机器与前景遮挡层淡出至消失。
func _fade_machine_out() -> void:
	submission_phase = "machine_fade"
	if DisplayServer.get_name() == "headless":
		machine.modulate.a = 0.0
		machine_foreground.modulate.a = 0.0
		return
	var fade_out := create_tween()
	fade_out.set_parallel(true)
	fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(machine, "modulate:a", 0.0, 3.0)
	fade_out.tween_property(machine_foreground, "modulate:a", 0.0, 3.0)
	await fade_out.finished


# 职位恢复表通过后创建初始存档，并进入首日的家中晨报。
func complete_reinstatement() -> void:
	if not submission_locked or opening_exiting:
		return
	opening_exiting = true
	Sfx.play("start")
	WorkdayState.save_system.create_initial_checkpoint()
	_enter_first_day()


# 在未提交表单时返回主菜单场景。
func _return_to_menu() -> void:
	if submission_locked:
		return
	var error := get_tree().change_scene_to_file(MENU_SCENE)
	if error != OK:
		push_error("无法返回主菜单：%s" % error_string(error))


# 切换到第一工作日的晨间上班序列。
func _enter_first_day() -> void:
	var error := get_tree().change_scene_to_file(PRE_WORK_SCENE)
	if error != OK:
		push_error("无法进入第一工作日：%s" % error_string(error))


# 按下 ESC 键时返回主菜单。
func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_return_to_menu()


# 按窗口尺寸缩放 1280x720 的画布以铺满视口。
func _fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO
	size = Vector2(1280, 720)
