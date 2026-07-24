extends Control

# 标题主菜单场景。
# 负责展示标题、背景、开始/退出按钮。
const WORKDAY_SELECTOR_SCENE := "res://scenes/workday_selector.tscn"
const TITLE_TEXTURE := preload("res://assets/menu/formocracy-title.png")
const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")

# UI 控件引用
var start_button: Button
var exit_button: Button


# 初始化主菜单：播放开场音乐、构建场景并聚焦开始按钮。
func _ready() -> void:
	OpeningMusic.play_opening()
	build_scene()
	start_button.grab_focus()


# 构建标题主菜单的完整 UI。
# 包含背景图、暗角、主菜单按钮列，以及保存选择和覆盖确认弹窗。
func build_scene() -> void:
	var background := TextureRect.new()
	background.name = "TitleArtwork"
	background.texture = TITLE_TEXTURE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.02, 0.2)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var menu := VBoxContainer.new()
	menu.name = "PrimaryMenu"
	menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	menu.position = Vector2(-430, -250)
	menu.size = Vector2(380, 190)
	menu.add_theme_constant_override("separation", 18)
	add_child(menu)

	start_button = make_button("游戏开始")
	start_button.name = "StartButton"
	start_button.pressed.connect(on_start_pressed)
	menu.add_child(start_button)

	exit_button = make_button("退出游戏")
	exit_button.name = "ExitButton"
	exit_button.pressed.connect(on_exit_pressed)
	menu.add_child(exit_button)



# 创建主菜单按钮，统一使用像素字体与固定最小尺寸。
func make_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(380, 76)
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 30)
	button.pressed.connect(func(): Sfx.play("ui_click"))
	button.mouse_entered.connect(func(): Sfx.play("ui_hover"))
	return button


# 点击“游戏开始”时调用。
# 始终进入独立的工作日选择场景。
func on_start_pressed() -> void:
	change_scene(WORKDAY_SELECTOR_SCENE)


# 点击“退出游戏”时调用。
# Web 平台仅禁用按钮并提示关闭浏览器，桌面平台直接退出。
func on_exit_pressed() -> void:
	if OS.has_feature("web"):
		exit_button.text = "请关闭浏览器页面"
		exit_button.disabled = true
	else:
		get_tree().quit()


# 切换场景，若失败则推送错误信息。
func change_scene(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("场景切换失败：%s / %s" % [path, error_string(error)])


# 全局键盘输入：ESC 退出游戏。
func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		on_exit_pressed()
