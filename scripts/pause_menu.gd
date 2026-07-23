extends CanvasLayer

const MENU_SCENE := "res://scenes/main_menu.tscn"
const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")
const ALLOWED_SCENES := [
	"res://main.tscn",
	"res://scenes/daily_report.tscn",
	"res://scenes/validation_preview.tscn",
]

var is_open := false
var root_control: Control
var overlay: ColorRect
var resume_button: Button
var fullscreen_button: Button
var exit_button: Button
var menu_confirmation: ConfirmationDialog
var exit_confirmation: ConfirmationDialog


func _ready() -> void:
	layer = 900
	process_mode = Node.PROCESS_MODE_ALWAYS
	build_ui()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


func make_box(color: Color, border_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(3)
	box.set_corner_radius_all(5)
	return box


func build_ui() -> void:
	root_control = Control.new()
	root_control.name = "PauseRoot"
	root_control.size = Vector2(1280, 720)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	overlay = ColorRect.new()
	overlay.name = "PauseOverlay"
	overlay.color = Color(0.015, 0.02, 0.015, 0.8)
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	root_control.add_child(overlay)

	var panel := Panel.new()
	panel.name = "PausePanel"
	panel.position = Vector2(430, 115)
	panel.size = Vector2(420, 490)
	panel.add_theme_stylebox_override("panel", make_box(Color("0a110d"), Color("84945c")))
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

	var hint := create_label("ESC  继续", 13, Vector2(30, 444), Vector2(360, 24))
	hint.add_theme_color_override("font_color", Color("778166"))
	panel.add_child(hint)

	menu_confirmation = create_confirmation("返回主菜单", "返回主菜单会结束当前未提交的表单操作。是否继续？")
	menu_confirmation.confirmed.connect(return_to_main_menu)
	root_control.add_child(menu_confirmation)
	exit_confirmation = create_confirmation("退出游戏", "确认退出 FORMOCRACY？")
	exit_confirmation.confirmed.connect(exit_game)
	root_control.add_child(exit_confirmation)
	refresh_fullscreen_label()


func create_label(text: String, size: int, at: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("d8d1a8"))
	return label


func create_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 54)
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 18)
	return button


func create_confirmation(title: String, message: String) -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = "确认"
	dialog.cancel_button_text = "取消"
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	return dialog


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	var developer_console = get_tree().root.get_node_or_null("DeveloperConsole")
	if developer_console != null and bool(developer_console.is_open):
		return
	if is_open:
		close_menu()
		get_viewport().set_input_as_handled()
	elif is_current_scene_allowed():
		open_menu()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	if is_open or not is_current_scene_allowed():
		return
	is_open = true
	overlay.visible = true
	get_tree().paused = true
	refresh_fullscreen_label()
	resume_button.grab_focus()


func close_menu() -> void:
	is_open = false
	overlay.visible = false
	menu_confirmation.hide()
	exit_confirmation.hide()
	get_tree().paused = false


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var fullscreen := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	call_deferred("refresh_fullscreen_label")


func refresh_fullscreen_label() -> void:
	var mode := DisplayServer.window_get_mode()
	var fullscreen := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	fullscreen_button.text = "全屏：开" if fullscreen else "全屏：关"


func confirm_return_to_menu() -> void:
	menu_confirmation.popup_centered(Vector2i(520, 190))


func return_to_main_menu() -> void:
	close_menu()
	var error := get_tree().change_scene_to_file(MENU_SCENE)
	if error != OK:
		push_error("返回主菜单失败：%s" % error_string(error))


func confirm_exit_game() -> void:
	if OS.has_feature("web"):
		exit_button.text = "请关闭浏览器页面"
		exit_button.disabled = true
	else:
		exit_confirmation.popup_centered(Vector2i(430, 170))


func exit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func is_current_scene_allowed() -> bool:
	return get_tree().current_scene != null and is_scene_allowed_path(get_tree().current_scene.scene_file_path)


func is_scene_allowed_path(path: String) -> bool:
	return path in ALLOWED_SCENES


func fit_to_window() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	root_control.scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)


func _process(_delta: float) -> void:
	if is_open and not is_current_scene_allowed():
		close_menu()
