extends Control

const MAIN_SCENE := "res://main.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const FORM_TEXTURE := preload("res://assets/opening/position-reinstatement-form-v2.png")
const MACHINE_TEXTURE := preload("res://assets/day1_8bit/interactive/validation_machine.png")
const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")
const SignaturePadScene := preload("res://scripts/ui/signature_pad.gd")
const HandwrittenCheckScene := preload("res://scripts/ui/handwritten_check.gd")
const UI := preload("res://scripts/ui/bureau_ui.gd")
const APPROACH_FRAME_COUNT := 8
const INGEST_FRAME_COUNT := 10
const STOP_MOTION_FRAME_SECONDS := 0.25

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
var clear_signature_button: Button
var welcome_panel: Control
var pass_button: Button
var submission_locked := false
var submission_snap_count := 0
var submission_phase := "form"


func _ready() -> void:
	OpeningMusic.play_opening()
	build_scene()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()
	play_form_reveal()


func build_scene() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP

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

	add_form_copy()
	add_form_inputs()

	build_machine_foreground()
	build_welcome_panel()

func add_form_copy() -> void:
	var title := make_label("职位恢复申请", 30, Vector2(408, 122), Vector2(464, 42))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form_stage.add_child(title)
	var subtitle := make_label("中央现实管理局 · 人事复核处", 15, Vector2(408, 158), Vector2(464, 24), true)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form_stage.add_child(subtitle)
	var file_label := make_label("档案编号", 13, Vector2(642, 205), Vector2(88, 25), true)
	file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	form_stage.add_child(file_label)
	var file_number := make_label("R-01 / 恢复", 15, Vector2(752, 205), Vector2(148, 25))
	file_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form_stage.add_child(file_number)
	form_stage.add_child(make_label("法定姓名", 17, Vector2(360, 228), Vector2(160, 28)))
	form_stage.add_child(make_label("恢复日期（当天）", 17, Vector2(360, 315), Vector2(220, 28)))
	form_stage.add_child(make_label("申请人亲笔签名", 17, Vector2(455, 402), Vector2(220, 26)))


func add_form_inputs() -> void:
	name_input = make_line_edit(Vector2(372, 258), Vector2(536, 46), "请输入姓名")
	name_input.name = "NameInput"
	name_input.text_changed.connect(_on_form_changed)
	form_stage.add_child(name_input)

	var today := Time.get_date_dict_from_system()
	year_input = make_date_input(Vector2(365, 363), 140, "年", 4)
	month_input = make_date_input(Vector2(570, 363), 120, "月", 2)
	day_input = make_date_input(Vector2(755, 363), 120, "日", 2)
	year_input.placeholder_text = str(today.year)
	month_input.placeholder_text = "%02d" % today.month
	day_input.placeholder_text = "%02d" % today.day

	signature_pad = SignaturePadScene.new()
	signature_pad.name = "SignaturePad"
	signature_pad.position = Vector2(455, 442)
	signature_pad.size = Vector2(480, 80)
	signature_pad.signature_changed.connect(_on_signature_changed)
	form_stage.add_child(signature_pad)

	clear_signature_button = Button.new()
	clear_signature_button.text = "重签"
	clear_signature_button.position = Vector2(858, 398)
	clear_signature_button.size = Vector2(74, 32)
	UI.style_button(clear_signature_button, 13)
	clear_signature_button.pressed.connect(signature_pad.clear_signature)
	form_stage.add_child(clear_signature_button)

	confirmation = HandwrittenCheckScene.new()
	confirmation.name = "Confirmation"
	# 透明手写区刻意大于纸上的印刷方框，允许勾画自然越过边界。
	confirmation.position = Vector2(448, 525)
	confirmation.size = Vector2(72, 58)
	confirmation.toggled.connect(_on_confirmation_toggled)
	form_stage.add_child(confirmation)
	var confirmation_copy := make_label(
		"本人确认以上信息由本人填写，并接受职位恢复审查。",
		15,
		Vector2(515, 535),
		Vector2(415, 34)
	)
	confirmation_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	form_stage.add_child(confirmation_copy)

	status_label = make_label("请完整填写姓名、当天日期并亲笔签名", 14, Vector2(405, 606), Vector2(470, 24), true)
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


func build_machine_foreground() -> void:
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


func build_welcome_panel() -> void:
	welcome_panel = Control.new()
	welcome_panel.name = "WelcomePanel"
	welcome_panel.size = Vector2(1280, 720)
	welcome_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	welcome_panel.visible = false
	add_child(welcome_panel)

	var welcome := Label.new()
	welcome.text = "欢迎回来"
	welcome.position = Vector2(390, 262)
	welcome.size = Vector2(500, 72)
	welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_label(welcome, 42)
	welcome_panel.add_child(welcome)

	pass_button = Button.new()
	pass_button.name = "PassButton"
	pass_button.text = "我通过"
	pass_button.position = Vector2(500, 386)
	pass_button.size = Vector2(280, 62)
	UI.style_button(pass_button, 22)
	pass_button.pressed.connect(complete_reinstatement)
	welcome_panel.add_child(pass_button)


func make_label(text: String, font_size: int, at: Vector2, dimensions: Vector2, muted := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	UI.style_label(label, font_size, muted)
	label.add_theme_color_override("font_color", Color("45432e") if muted else Color("29291d"))
	return label


func make_line_edit(at: Vector2, dimensions: Vector2, placeholder: String) -> LineEdit:
	var input := LineEdit.new()
	input.position = at
	input.size = dimensions
	input.placeholder_text = placeholder
	input.add_theme_font_override("font", PIXEL_FONT)
	input.add_theme_font_size_override("font_size", 23)
	input.add_theme_color_override("font_color", Color("29291d"))
	input.add_theme_color_override("font_placeholder_color", Color(0.25, 0.25, 0.18, 0.48))
	input.add_theme_stylebox_override("normal", make_input_box(Color(0.94, 0.88, 0.69, 0.0)))
	input.add_theme_stylebox_override("focus", make_input_box(Color(0.94, 0.88, 0.69, 0.0)))
	return input


func make_input_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0
	return box


func make_date_input(at: Vector2, width: float, suffix: String, max_length: int) -> LineEdit:
	var input := make_line_edit(at, Vector2(width, 46), "")
	input.max_length = max_length
	input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	input.text_changed.connect(_on_date_changed.bind(input))
	form_stage.add_child(input)
	var suffix_label := make_label(suffix, 17, at + Vector2(width + 8, 10), Vector2(42, 28))
	form_stage.add_child(suffix_label)
	return input


func _on_date_changed(value: String, input: LineEdit) -> void:
	var digits := ""
	for character in value:
		if character >= "0" and character <= "9":
			digits += character
	if input.text != digits:
		input.text = digits
		input.caret_column = digits.length()
	_on_form_changed(digits)


func _on_form_changed(_value := "") -> void:
	Sfx.typewriter_tick()
	refresh_form_validity()


func _on_signature_changed(_has_signature: bool) -> void:
	refresh_form_validity()


func _on_confirmation_toggled(_pressed: bool) -> void:
	refresh_form_validity()


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


func entered_date() -> String:
	if year_input.text.is_empty() or month_input.text.is_empty() or day_input.text.is_empty():
		return ""
	return "%04d-%02d-%02d" % [int(year_input.text), int(month_input.text), int(day_input.text)]


func current_date() -> String:
	var today := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [today.year, today.month, today.day]


func play_form_reveal() -> void:
	await get_tree().create_timer(0.65).timeout
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(form_stage, "modulate:a", 1.0, 1.15)
	await reveal.finished
	if not submission_locked:
		name_input.grab_focus()


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
	clear_signature_button.visible = false
	await prepare_projected_form()
	await play_submission()


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
	clear_signature_button.disabled = not enabled


func play_submission() -> void:
	await play_stop_motion_approach()
	await play_stop_motion_ingestion()
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.5).timeout
	await fade_machine_out()
	await show_welcome()


func prepare_projected_form() -> void:
	projected_form = Polygon2D.new()
	projected_form.name = "ProjectedForm"
	if DisplayServer.get_name() == "headless":
		# Headless 渲染器不推进 SubViewport 捕获；测试使用静态纹理验证几何与时序。
		projected_form.texture = FORM_TEXTURE
		form_stage.visible = false
	else:
		form_viewport = SubViewport.new()
		form_viewport.name = "FormCaptureViewport"
		form_viewport.size = Vector2i(1280, 720)
		form_viewport.transparent_bg = true
		form_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(form_viewport)
		form_stage.reparent(form_viewport)
		form_stage.position = Vector2.ZERO
		form_stage.scale = Vector2.ONE
		form_stage.rotation_degrees = 0.0
		projected_form.texture = form_viewport.get_texture()
	projected_form.uv = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1280, 0),
		Vector2(1280, 720),
		Vector2(0, 720),
	])
	set_projected_form_pose(1.0, 1.0, 0.0, 0.0)
	add_child(projected_form)
	move_child(projected_form, machine_foreground.get_index())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func play_stop_motion_approach() -> void:
	submission_phase = "approach"
	submission_snap_count = 0
	var machine_reveal := create_tween()
	machine_reveal.set_parallel(true)
	machine_reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	machine_reveal.tween_property(machine, "modulate:a", 1.0, APPROACH_FRAME_COUNT * STOP_MOTION_FRAME_SECONDS)

	for frame in range(1, APPROACH_FRAME_COUNT + 1):
		var t := float(frame) / float(APPROACH_FRAME_COUNT)
		set_projected_form_pose(
			lerpf(1.0, 0.64, t),
			lerpf(1.0, 0.48, t),
			lerpf(0.0, 0.24, t),
			lerpf(0.0, 12.0, t)
		)
		submission_snap_count += 1
		if DisplayServer.get_name() != "headless":
			await get_tree().create_timer(STOP_MOTION_FRAME_SECONDS).timeout
	if DisplayServer.get_name() == "headless":
		machine_reveal.kill()
	# 定格循环与淡入时长相同；循环结束时 Tween 可能已经发出 finished。
	# 此处直接收束到目标状态，避免等待一个已经错过的信号而永久卡住演出。
	machine.modulate.a = 1.0


func play_stop_motion_ingestion() -> void:
	submission_phase = "ingestion"
	Sfx.start_conveyor()
	# 遮挡只在纸张真正进入插槽时出现；靠近机器时不能盖住表单。
	machine_foreground.modulate.a = 1.0
	for frame in range(1, INGEST_FRAME_COUNT + 1):
		var t := float(frame) / float(INGEST_FRAME_COUNT)
		set_projected_form_pose(
			lerpf(0.64, 0.035, t),
			lerpf(0.48, 0.012, t),
			lerpf(0.24, 0.42, t),
			lerpf(12.0, 20.0, t)
		)
		submission_snap_count += 1
		if DisplayServer.get_name() != "headless":
			await get_tree().create_timer(STOP_MOTION_FRAME_SECONDS).timeout
	projected_form.visible = false
	Sfx.stop_conveyor()


func set_projected_form_pose(width_scale: float, height_scale: float, perspective: float, offset_y: float) -> void:
	var center := Vector2(640.0, 360.0 + offset_y)
	var bottom_width := 1280.0 * width_scale
	var top_width := bottom_width * (1.0 - perspective)
	var height := 720.0 * height_scale
	var top_y := center.y - height * 0.5
	var bottom_y := center.y + height * 0.5
	projected_form.polygon = PackedVector2Array([
		Vector2(center.x - top_width * 0.5, top_y),
		Vector2(center.x + top_width * 0.5, top_y),
		Vector2(center.x + bottom_width * 0.5, bottom_y),
		Vector2(center.x - bottom_width * 0.5, bottom_y),
	])


func fade_machine_out() -> void:
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


func show_welcome() -> void:
	submission_phase = "welcome"
	Sfx.play("bling")
	welcome_panel.modulate.a = 0.0
	welcome_panel.visible = true
	if DisplayServer.get_name() == "headless":
		welcome_panel.modulate.a = 1.0
		return
	var reveal := create_tween()
	reveal.tween_property(welcome_panel, "modulate:a", 1.0, 0.8)
	await reveal.finished
	pass_button.grab_focus()


func complete_reinstatement() -> void:
	if not submission_locked:
		return
	Sfx.play("start")
	WorkdayState.create_initial_checkpoint()
	enter_first_day()


func return_to_menu() -> void:
	if submission_locked:
		return
	var error := get_tree().change_scene_to_file(MENU_SCENE)
	if error != OK:
		push_error("无法返回主菜单：%s" % error_string(error))


func enter_first_day() -> void:
	var error := get_tree().change_scene_to_file(MAIN_SCENE)
	if error != OK:
		push_error("无法进入第一工作日：%s" % error_string(error))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		return_to_menu()


func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO
	size = Vector2(1280, 720)
