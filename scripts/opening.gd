extends Control

const MAIN_SCENE := "res://main.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const FORM_TEXTURE := preload("res://assets/opening/position-reinstatement-form-v2.png")
const MACHINE_TEXTURE := preload("res://assets/opening/opening-02-reality-effective-8bit-v1.png")
const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")
const SignaturePadScene := preload("res://scripts/ui/signature_pad.gd")
const HandwrittenCheckScene := preload("res://scripts/ui/handwritten_check.gd")
const UI := preload("res://scripts/ui/bureau_ui.gd")

var form_stage: Control
var machine: TextureRect
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
var submission_locked := false


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
	machine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	machine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	machine.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
	name_input.grab_focus()


func submit_form() -> void:
	if submission_locked or not confirm_button.visible:
		return
	submission_locked = true
	WorkdayState.player_name = name_input.text.strip_edges()
	WorkdayState.reinstatement_date = entered_date()
	WorkdayState.player_signature = signature_pad.serialize_strokes()
	WorkdayState.save_progress()
	set_form_interaction(false)
	await play_submission()
	enter_first_day()


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
	var machine_reveal := create_tween()
	machine_reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	machine_reveal.tween_property(machine, "modulate:a", 1.0, 1.25)
	await machine_reveal.finished

	var feed := create_tween()
	feed.set_parallel(true)
	feed.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	feed.tween_property(form_stage, "rotation_degrees", -7.0, 1.25)
	feed.tween_property(form_stage, "scale", Vector2(0.36, 0.36), 1.25)
	feed.tween_property(form_stage, "position", Vector2(0, 56), 1.25)
	await feed.finished

	var swallow := create_tween()
	swallow.set_parallel(true)
	swallow.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	swallow.tween_property(form_stage, "scale", Vector2(0.08, 0.08), 0.65)
	swallow.tween_property(form_stage, "position", Vector2(0, 8), 0.65)
	swallow.tween_property(form_stage, "modulate:a", 0.0, 0.65)
	await swallow.finished
	await get_tree().create_timer(0.45).timeout


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
