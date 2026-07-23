extends Control

const MAIN_SCENE := "res://main.tscn"
const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")
const SLIDES := [
	preload("res://assets/opening/opening-01-identity-form-8bit-v1.png"),
	preload("res://assets/opening/opening-02-reality-effective-8bit-v1.png"),
	preload("res://assets/opening/opening-03-day-one-reveal-8bit-v1.png"),
]
const AUTO_ADVANCE_SECONDS := 2.5

var slide_index := 0
var transition_locked := false
var auto_timer: Timer
var slide_texture: TextureRect
var fade: ColorRect
var progress_label: Label
var start_panel: Control


# 开场场景初始化。
# 构建包含幻灯片、跳过按钮、进度标签、开始按钮与自动推进计时器的完整 UI，
# 显示第一张幻灯片（无淡入动画），并连接视口尺寸变化信号以适配窗口。
func _ready() -> void:
	OpeningMusic.play_opening()
	build_scene()
	show_slide(0, false)
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


# 构建开场场景的全部 UI 元素。
# 包括全屏幻灯片 TextureRect、暗角遮罩、跳过开场按钮、档案影像进度标签、
# “开始第一天”按钮面板、黑色淡入淡出 ColorRect，以及用于自动轮播的 Timer。
func build_scene() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP

	slide_texture = TextureRect.new()
	slide_texture.name = "OpeningImage"
	slide_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slide_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slide_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	slide_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slide_texture)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.015, 0.01, 0.13)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var skip_button := Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "跳过开场  >>"
	skip_button.position = Vector2(930, 26)
	skip_button.size = Vector2(150, 42)
	skip_button.add_theme_font_override("font", PIXEL_FONT)
	skip_button.pressed.connect(show_final_slide)
	add_child(skip_button)

	progress_label = Label.new()
	progress_label.position = Vector2(34, 666)
	progress_label.size = Vector2(260, 32)
	progress_label.add_theme_font_size_override("font_size", 15)
	progress_label.add_theme_font_override("font", PIXEL_FONT)
	progress_label.add_theme_color_override("font_color", Color("d8cfad"))
	progress_label.add_theme_constant_override("outline_size", 5)
	progress_label.add_theme_color_override("font_outline_color", Color("171811"))
	add_child(progress_label)

	start_panel = Control.new()
	start_panel.name = "StartDayPanel"
	start_panel.position = Vector2(430, 585)
	start_panel.size = Vector2(420, 100)
	start_panel.visible = false
	add_child(start_panel)

	var prompt := Label.new()
	prompt.text = "第 1 工作日 · 现实事项验收处"
	prompt.position = Vector2.ZERO
	prompt.size = Vector2(420, 34)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_font_override("font", PIXEL_FONT)
	prompt.add_theme_color_override("font_color", Color("e4d8b2"))
	prompt.add_theme_constant_override("outline_size", 6)
	prompt.add_theme_color_override("font_outline_color", Color("11130f"))
	start_panel.add_child(prompt)

	var start_button := Button.new()
	start_button.name = "StartDayButton"
	start_button.text = "开始第一天"
	start_button.position = Vector2(90, 42)
	start_button.size = Vector2(240, 50)
	start_button.add_theme_font_size_override("font_size", 20)
	start_button.add_theme_font_override("font", PIXEL_FONT)
	start_button.pressed.connect(start_first_day)
	start_panel.add_child(start_button)

	fade = ColorRect.new()
	fade.name = "Fade"
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	auto_timer = Timer.new()
	auto_timer.one_shot = true
	auto_timer.wait_time = AUTO_ADVANCE_SECONDS
	auto_timer.timeout.connect(advance_slide)
	add_child(auto_timer)


# 显示指定索引的幻灯片。
# index 为目标幻灯片索引；animate 控制是否播放淡出/淡入转场。
# 会自动限制索引范围，更新进度文字，在最后一张幻灯片时显示开始面板；
# 非最后一张时启动 AUTO_ADVANCE_SECONDS 的自动计时器。
func show_slide(index: int, animate := true) -> void:
	slide_index = clampi(index, 0, SLIDES.size() - 1)
	start_panel.visible = slide_index == SLIDES.size() - 1
	progress_label.text = "档案影像  %02d / %02d" % [slide_index + 1, SLIDES.size()]
	auto_timer.stop()
	if animate:
		transition_locked = true
		var out_tween := create_tween()
		out_tween.tween_property(fade, "color:a", 1.0, 0.22)
		await out_tween.finished
	slide_texture.texture = SLIDES[slide_index]
	fade.color.a = 1.0
	var in_tween := create_tween()
	in_tween.tween_property(fade, "color:a", 0.0, 0.45)
	await in_tween.finished
	transition_locked = false
	if slide_index < SLIDES.size() - 1:
		auto_timer.start()


# 自动推进到下一幻灯片。
# 若当前正在转场或已是最后一张，则不做任何操作。
func advance_slide() -> void:
	if transition_locked or slide_index >= SLIDES.size() - 1:
		return
	show_slide(slide_index + 1)


# “跳过开场”按钮回调。
# 若当前不是最后一张且未处于转场中，直接跳转到最后一张幻灯片。
func show_final_slide() -> void:
	if slide_index == SLIDES.size() - 1 or transition_locked:
		return
	show_slide(SLIDES.size() - 1)


# “开始第一天”按钮回调。
# 停止自动推进计时器并切换到主工作台场景；切换失败时输出错误信息到 Godot 错误日志。
func start_first_day() -> void:
	auto_timer.stop()
	WorkdayState.save_progress()
	var error := get_tree().change_scene_to_file(MAIN_SCENE)
	if error != OK:
		push_error("无法进入第一工作日：%s" % error_string(error))


# 点击开场画面任意位置时推进幻灯片。
# 仅在检测到鼠标左键按下时调用 advance_slide()。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance_slide()


# 键盘事件处理。
# 空格或回车推进幻灯片；若已在最后一张，则相当于点击“开始第一天”。ESC 直接跳到最后一张。
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
		if slide_index == SLIDES.size() - 1:
			start_first_day()
		else:
			advance_slide()
	elif event.keycode == KEY_ESCAPE:
		show_final_slide()


# 以 1280x720 为基准缩放开场场景并铺满视口，同时保持自身 size 属性。
func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO
	size = Vector2(1280, 720)
