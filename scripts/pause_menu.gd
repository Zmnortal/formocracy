extends CanvasLayer

# 游戏暂停菜单。
# 在允许暂停的场景中通过 ESC 打开，提供继续、全屏切换、返回主菜单与退出等功能。

const MENU_SCENE := "res://scenes/main_menu.tscn"
const BureauModalScene := preload("res://scripts/ui/bureau_modal.gd")
const UI := preload("res://scripts/ui/bureau_ui.gd")

# 允许打开暂停菜单的场景路径白名单
const ALLOWED_SCENES := [
	"res://main.tscn",
	"res://scenes/daily_report.tscn",
	"res://scenes/validation_preview.tscn",
]

# 暂停菜单运行状态与 UI 引用
var is_open := false
var root_control: Control
var overlay: ColorRect
var resume_button: Button
var fullscreen_button: Button
var exit_button: Button
var music_slider: HSlider
var mute_button: Button
var menu_confirmation
var exit_confirmation


# 初始化暂停菜单层级、处理模式并构建 UI。
func _ready() -> void:
	layer = 900
	process_mode = Node.PROCESS_MODE_ALWAYS
	build_ui()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


# 创建统一的带边框面板风格。
func make_box(color: Color, border_color: Color) -> StyleBoxFlat:
	return UI.make_box(color, border_color)


# 构建暂停菜单的完整 UI：遮罩、面板、按钮、音乐控制与确认弹窗。
func build_ui() -> void:
	root_control = Control.new()
	root_control.name = "PauseRoot"
	root_control.size = Vector2(1280, 720)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	overlay = ColorRect.new()
	overlay.name = "PauseOverlay"
	overlay.color = UI.COLOR_BACKDROP
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	root_control.add_child(overlay)

	var panel := Panel.new()
	panel.name = "PausePanel"
	panel.position = Vector2(430, 70)
	panel.size = Vector2(420, 580)
	UI.style_panel(panel)
	overlay.add_child(panel)

	var heading := create_label("工作暂时中止", 25, Vector2(30, 28), Vector2(360, 42))
	panel.add_child(heading)
	var subheading := create_label("中央现实管理局 · 操作菜单", 14, Vector2(30, 74), Vector2(360, 28))
	subheading.add_theme_color_override("font_color", Color("7f9160"))
	panel.add_child(subheading)

	var buttons := VBoxContainer.new()
	buttons.position = Vector2(70, 125)
	buttons.size = Vector2(280, 300)
	buttons.add_theme_constant_override("separation", 14)
	panel.add_child(buttons)
	resume_button = create_menu_button("继续游戏")
	resume_button.pressed.connect(close_menu)
	buttons.add_child(resume_button)
	fullscreen_button = create_menu_button("")
	fullscreen_button.pressed.connect(toggle_fullscreen)
	buttons.add_child(fullscreen_button)
	var menu_button := create_menu_button("返回主菜单")
	menu_button.pressed.connect(confirm_return_to_menu)
	buttons.add_child(menu_button)
	exit_button = create_menu_button("退出游戏")
	exit_button.pressed.connect(confirm_exit_game)
	buttons.add_child(exit_button)

	build_music_controls(panel)

	var hint := create_label("ESC  继续", 13, Vector2(30, 535), Vector2(360, 24))
	hint.add_theme_color_override("font_color", Color("778166"))
	panel.add_child(hint)

	menu_confirmation = create_confirmation(
		"返回主菜单",
		"当前未提交的表单操作将被终止。\n是否返回中央现实管理局入口？",
		"return_menu"
	)
	menu_confirmation.action_pressed.connect(_on_confirmation_action)
	root_control.add_child(menu_confirmation)
	exit_confirmation = create_confirmation(
		"终止工作程序",
		"确认退出 FORMOCRACY？\n尚未封存的操作不会被保留。",
		"exit_game"
	)
	exit_confirmation.action_pressed.connect(_on_confirmation_action)
	root_control.add_child(exit_confirmation)
	refresh_fullscreen_label()


# 创建居中对齐的文本标签。
func create_label(text: String, size: int, at: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_label(label, size)
	return label


# 创建暂停菜单按钮。
func create_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 54)
	UI.style_button(button, 18)
	return button


# 构建背景音乐音量滑块与静音按钮。
func build_music_controls(panel: Panel) -> void:
	var separator := HSeparator.new()
	separator.position = Vector2(35, 398)
	separator.size = Vector2(350, 8)
	panel.add_child(separator)

	var label := create_label("背景音乐", 17, Vector2(35, 420), Vector2(92, 48))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)

	music_slider = HSlider.new()
	music_slider.name = "MusicVolume"
	music_slider.position = Vector2(128, 420)
	music_slider.size = Vector2(158, 48)
	music_slider.min_value = 0.0
	music_slider.max_value = 100.0
	music_slider.step = 5.0
	music_slider.value = OpeningMusic.volume_percent
	music_slider.value_changed.connect(on_music_volume_changed)
	UI.style_range(music_slider)
	panel.add_child(music_slider)

	mute_button = Button.new()
	mute_button.name = "MuteButton"
	mute_button.position = Vector2(298, 416)
	mute_button.size = Vector2(88, 54)
	UI.style_button(mute_button, 16)
	mute_button.pressed.connect(toggle_music_mute)
	panel.add_child(mute_button)
	refresh_music_controls()


# 音乐音量变化时同步到 OpeningMusic。
func on_music_volume_changed(value: float) -> void:
	OpeningMusic.set_volume_percent(value)


# 切换静音状态并刷新控件显示。
func toggle_music_mute() -> void:
	OpeningMusic.set_muted(not OpeningMusic.muted)
	refresh_music_controls()


# 刷新音量滑块与静音按钮文字。
func refresh_music_controls() -> void:
	music_slider.value = OpeningMusic.volume_percent
	mute_button.text = "恢复" if OpeningMusic.muted else "静音"


# 创建 BureauModal 确认弹窗，绑定动作回调。
func create_confirmation(title: String, message: String, confirm_action: String):
	var dialog = BureauModalScene.new()
	dialog.configure(title, message, Vector2(620, 330))
	dialog.add_action("cancel", "取消", true)
	dialog.add_action(confirm_action, "确认", false, true)
	dialog.set_cancel_action("cancel")
	return dialog


# 处理确认弹窗的按钮动作。
func _on_confirmation_action(action_id: String) -> void:
	match action_id:
		"cancel":
			menu_confirmation.close()
			exit_confirmation.close()
			resume_button.grab_focus()
		"return_menu":
			return_to_main_menu()
		"exit_game":
			exit_game()


# 全局键盘输入监听：ESC 打开/关闭菜单，开发控制台打开时优先关闭控制台。
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	var developer_console = get_tree().root.get_node_or_null("DeveloperConsole")
	if developer_console != null and bool(developer_console.is_open):
		return
	if is_open:
		if menu_confirmation.visible or exit_confirmation.visible:
			menu_confirmation.close()
			exit_confirmation.close()
			resume_button.grab_focus()
		else:
			close_menu()
		get_viewport().set_input_as_handled()
	elif is_current_scene_allowed():
		open_menu()
		get_viewport().set_input_as_handled()


# 打开暂停菜单并暂停游戏树。
func open_menu() -> void:
	if is_open or not is_current_scene_allowed():
		return
	is_open = true
	overlay.visible = true
	get_tree().paused = true
	refresh_fullscreen_label()
	refresh_music_controls()
	resume_button.grab_focus()


# 关闭暂停菜单并恢复游戏树。
func close_menu() -> void:
	is_open = false
	overlay.visible = false
	menu_confirmation.close()
	exit_confirmation.close()
	get_tree().paused = false


# 切换全屏/窗口模式，并延迟刷新按钮文字。
func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var fullscreen := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	call_deferred("refresh_fullscreen_label")


# 刷新全屏按钮文字。
func refresh_fullscreen_label() -> void:
	var mode := DisplayServer.window_get_mode()
	var fullscreen := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	fullscreen_button.text = "全屏：开" if fullscreen else "全屏：关"


# 打开返回主菜单确认弹窗。
func confirm_return_to_menu() -> void:
	menu_confirmation.open()


# 关闭暂停菜单并返回主菜单。
func return_to_main_menu() -> void:
	close_menu()
	var error := get_tree().change_scene_to_file(MENU_SCENE)
	if error != OK:
		push_error("返回主菜单失败：%s" % error_string(error))


# 打开退出游戏确认弹窗；Web 平台禁用退出按钮。
func confirm_exit_game() -> void:
	if OS.has_feature("web"):
		exit_button.text = "请关闭浏览器页面"
		exit_button.disabled = true
	else:
		exit_confirmation.open()


# 退出游戏。
func exit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


# 当前场景是否允许打开暂停菜单。
func is_current_scene_allowed() -> bool:
	return get_tree().current_scene != null and is_scene_allowed_path(get_tree().current_scene.scene_file_path)


# 判断给定场景路径是否在白名单中。
func is_scene_allowed_path(path: String) -> bool:
	return path in ALLOWED_SCENES


# 根据视口大小等比例缩放暂停菜单根节点。
func fit_to_window() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	root_control.scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)


# 若当前场景不再允许暂停，则自动关闭菜单。
func _process(_delta: float) -> void:
	if is_open and not is_current_scene_allowed():
		close_menu()
