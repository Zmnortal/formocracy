extends Control

const NARRATIVE_SCENE := "res://scenes/opening.tscn"
const GAME_SCENE := "res://main.tscn"
const TITLE_TEXTURE := preload("res://assets/menu/formocracy-title.png")
const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")

var start_button: Button
var exit_button: Button
var save_panel: Panel
var overwrite_dialog: ConfirmationDialog


func _ready() -> void:
	build_scene()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()
	start_button.grab_focus()


func build_scene() -> void:
	size = Vector2(1280, 720)
	var background := TextureRect.new()
	background.name = "TitleArtwork"
	background.texture = TITLE_TEXTURE
	background.size = size
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.02, 0.2)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var menu := VBoxContainer.new()
	menu.name = "PrimaryMenu"
	menu.position = Vector2(970, 525)
	menu.size = Vector2(260, 130)
	menu.add_theme_constant_override("separation", 14)
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
	build_overwrite_dialog()


func make_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(260, 54)
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 20)
	return button


func build_save_panel() -> void:
	save_panel = Panel.new()
	save_panel.name = "SaveChoicePanel"
	save_panel.position = Vector2(440, 430)
	save_panel.size = Vector2(400, 240)
	save_panel.visible = false
	add_child(save_panel)

	var title := Label.new()
	title.text = "检测到现有工作档案"
	title.position = Vector2(30, 22)
	title.size = Vector2(340, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", 19)
	save_panel.add_child(title)

	var choices := VBoxContainer.new()
	choices.position = Vector2(70, 70)
	choices.size = Vector2(260, 150)
	choices.add_theme_constant_override("separation", 8)
	save_panel.add_child(choices)
	var continue_button := make_button("继续游戏")
	continue_button.name = "ContinueButton"
	continue_button.pressed.connect(continue_game)
	choices.add_child(continue_button)
	var new_button := make_button("开始新游戏")
	new_button.name = "NewGameButton"
	new_button.pressed.connect(confirm_new_game)
	choices.add_child(new_button)
	var back_button := make_button("返回")
	back_button.name = "BackButton"
	back_button.pressed.connect(close_save_panel)
	choices.add_child(back_button)


func build_overwrite_dialog() -> void:
	overwrite_dialog = ConfirmationDialog.new()
	overwrite_dialog.title = "覆盖工作档案"
	overwrite_dialog.dialog_text = "开始新游戏会清除当前进度。是否继续？"
	overwrite_dialog.ok_button_text = "确认覆盖"
	overwrite_dialog.cancel_button_text = "取消"
	overwrite_dialog.confirmed.connect(start_new_game)
	add_child(overwrite_dialog)


func on_start_pressed() -> void:
	if WorkdayState.has_save():
		save_panel.visible = true
		var continue_button := save_panel.get_node("VBoxContainer/ContinueButton") as Button
		continue_button.grab_focus()
	else:
		start_new_game()


func close_save_panel() -> void:
	save_panel.visible = false
	start_button.grab_focus()


func confirm_new_game() -> void:
	overwrite_dialog.popup_centered(Vector2i(460, 180))


func start_new_game() -> void:
	WorkdayState.start_new_game()
	change_scene(NARRATIVE_SCENE)


func continue_game() -> void:
	if not WorkdayState.load_progress():
		start_new_game()
		return
	change_scene(GAME_SCENE)


func on_exit_pressed() -> void:
	if OS.has_feature("web"):
		exit_button.text = "请关闭浏览器页面"
		exit_button.disabled = true
	else:
		get_tree().quit()


func change_scene(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("场景切换失败：%s / %s" % [path, error_string(error)])


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if save_panel.visible:
			close_save_panel()
		else:
			on_exit_pressed()


func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO
	size = Vector2(1280, 720)
