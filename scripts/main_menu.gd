extends Control

# 标题主菜单场景。
# 负责展示标题、背景、开始/退出按钮，以及检测到存档时的继续/新游戏选择弹窗。
const NARRATIVE_SCENE := "res://scenes/opening.tscn"
const GAME_SCENE := "res://main.tscn"
const TITLE_TEXTURE := preload("res://assets/menu/formocracy-title.png")
const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")
const BureauModalScene := preload("res://scripts/ui/bureau_modal.gd")

# UI 控件引用
var start_button: Button
var exit_button: Button
var continue_button: Button
var new_game_button: Button
var save_panel
var overwrite_panel
var overwrite_confirm_button: Button


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

	build_save_panel()
	build_overwrite_panel()


# 创建主菜单按钮，统一使用像素字体与固定最小尺寸。
func make_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(380, 76)
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 30)
	return button


# 构建“检测到现有工作档案”选择弹窗。
# 提供继续游戏、开始新游戏和返回三个操作，并记录关键按钮引用以便聚焦。
func build_save_panel() -> void:
	save_panel = BureauModalScene.new()
	save_panel.name = "SaveChoicePanel"
	save_panel.configure(
		"检测到现有工作档案",
		"档案仍在流转中。请选择继续处理，或开始新的工作记录。",
		Vector2(560, 440),
		true
	)
	save_panel.action_pressed.connect(_on_save_action)
	add_child(save_panel)
	continue_button = save_panel.add_action("continue", "继续游戏", true)
	continue_button.name = "ContinueButton"
	new_game_button = save_panel.add_action("new_game", "开始新游戏")
	new_game_button.name = "NewGameButton"
	var back_button: Button = save_panel.add_action("back", "返回")
	back_button.name = "BackButton"
	save_panel.set_cancel_action("back")


# 构建“覆盖工作档案”确认弹窗。
# 用于在开始新游戏时提醒玩家当前进度将被清除，避免误操作。
func build_overwrite_panel() -> void:
	overwrite_panel = BureauModalScene.new()
	overwrite_panel.name = "OverwritePanel"
	overwrite_panel.z_index = 20
	overwrite_panel.configure(
		"覆盖工作档案",
		"开始新游戏会清除当前进度。\n此操作无法撤销，是否继续？",
		Vector2(680, 360)
	)
	overwrite_panel.action_pressed.connect(_on_overwrite_action)
	add_child(overwrite_panel)
	var cancel_button: Button = overwrite_panel.add_action("cancel", "取消")
	cancel_button.name = "CancelButton"
	overwrite_confirm_button = overwrite_panel.add_action("confirm", "确认覆盖", true, true)
	overwrite_confirm_button.name = "ConfirmButton"
	overwrite_panel.set_cancel_action("cancel")


# 处理存档选择弹窗的按钮动作。
func _on_save_action(action_id: String) -> void:
	match action_id:
		"continue":
			continue_game()
		"new_game":
			confirm_new_game()
		"back":
			close_save_panel()


# 处理覆盖确认弹窗的按钮动作。
func _on_overwrite_action(action_id: String) -> void:
	match action_id:
		"confirm":
			start_new_game()
		"cancel":
			close_overwrite_panel()


# 点击“游戏开始”时调用。
# 若存在存档则打开选择弹窗，否则直接进入新游戏叙事流程。
func on_start_pressed() -> void:
	if WorkdayState.has_save():
		save_panel.open()
	else:
		start_new_game()


# 关闭存档选择弹窗并恢复开始按钮焦点。
func close_save_panel() -> void:
	save_panel.close()
	start_button.grab_focus()


# 确认要开始新游戏：打开覆盖确认弹窗。
func confirm_new_game() -> void:
	overwrite_panel.open()


# 关闭覆盖确认弹窗并恢复新游戏按钮焦点。
func close_overwrite_panel() -> void:
	overwrite_panel.close()
	new_game_button.grab_focus()


# 开始新游戏：重置存档并进入开场叙事场景。
func start_new_game() -> void:
	WorkdayState.start_new_game()
	change_scene(NARRATIVE_SCENE)


# 继续游戏：加载存档并进入主工作台；若加载失败则开始新游戏。
func continue_game() -> void:
	if not WorkdayState.load_progress():
		start_new_game()
		return
	change_scene(GAME_SCENE)


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


# 全局键盘输入：ESC 关闭弹窗或退出游戏。
func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if overwrite_panel.visible:
			close_overwrite_panel()
		elif save_panel.visible:
			close_save_panel()
		else:
			on_exit_pressed()
