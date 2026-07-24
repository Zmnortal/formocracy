extends Control

const MENU_SCENE := "res://scenes/main_menu.tscn"
const OPENING_SCENE := "res://scenes/opening.tscn"
const GAME_SCENE := "res://main.tscn"
const UI := preload("res://scripts/ui/bureau_ui.gd")

var canvas: Control
var title_label: Label
var timeline: Control
var new_game_button: Button
var save_button: Button
var back_button: Button
var delete_button: Button
var confirmation_layer: Control
var confirmation_title: Label
var confirmation_copy: Label
var confirm_button: Button
var cancel_button: Button
var pending_action := ""


func _ready() -> void:
	OpeningMusic.play_opening()
	build_scene()
	refresh_save_slot()
	fit_to_window()
	get_viewport().size_changed.connect(fit_to_window)
	new_game_button.grab_focus()


func build_scene() -> void:
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.size = Vector2(1280, 720)
	add_child(canvas)

	var background := ColorRect.new()
	background.color = Color("020403")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)

	title_label = make_label("选择一天来继续或者从头开始游戏", 32, Vector2(240, 58), Vector2(800, 62))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(title_label)
	canvas.add_child(make_line(Vector2(0, 132), Vector2(1280, 2)))
	canvas.add_child(make_line(Vector2(0, 630), Vector2(1280, 2)))

	timeline = Control.new()
	timeline.name = "Timeline"
	timeline.position = Vector2(24, 150)
	timeline.size = Vector2(900, 300)
	canvas.add_child(timeline)

	var node_one := make_label("※\n1", 16, Vector2(42, 0), Vector2(70, 62), true)
	node_one.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timeline.add_child(node_one)

	new_game_button = make_timeline_button("新游戏", Vector2(0, 72), Vector2(150, 92))
	new_game_button.name = "NewGameButton"
	new_game_button.pressed.connect(request_new_game)
	timeline.add_child(new_game_button)

	var connector := make_line(Vector2(150, 117), Vector2(32, 2))
	connector.name = "SaveConnector"
	timeline.add_child(connector)

	var node_two := make_label("※\n2", 16, Vector2(194, 0), Vector2(70, 62), true)
	node_two.name = "SaveNodeNumber"
	node_two.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timeline.add_child(node_two)

	save_button = make_timeline_button("", Vector2(182, 72), Vector2(150, 92))
	save_button.name = "SaveButton"
	save_button.pressed.connect(request_continue_game)
	timeline.add_child(save_button)

	back_button = make_footer_button("返回", Vector2(470, 650), Vector2(340, 52))
	back_button.name = "BackButton"
	back_button.pressed.connect(return_to_menu)
	canvas.add_child(back_button)

	delete_button = make_footer_button("", Vector2(1180, 648), Vector2(62, 56))
	delete_button.name = "DeleteButton"
	delete_button.pressed.connect(request_delete_save)
	canvas.add_child(delete_button)
	add_trash_icon(delete_button)

	build_confirmation_layer()


func build_confirmation_layer() -> void:
	confirmation_layer = Control.new()
	confirmation_layer.name = "ConfirmationLayer"
	confirmation_layer.size = Vector2(1280, 720)
	confirmation_layer.visible = false
	confirmation_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(confirmation_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_layer.add_child(backdrop)

	var panel := Panel.new()
	panel.name = "ConfirmationPanel"
	panel.position = Vector2(350, 190)
	panel.size = Vector2(580, 340)
	UI.style_panel(panel)
	confirmation_layer.add_child(panel)

	confirmation_title = make_label("", 32, Vector2(40, 38), Vector2(500, 52))
	confirmation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(confirmation_title)
	confirmation_copy = make_label("", 16, Vector2(55, 112), Vector2(470, 80), true)
	confirmation_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirmation_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(confirmation_copy)

	confirm_button = make_timeline_button("确认", Vector2(62, 230), Vector2(210, 62))
	confirm_button.name = "ConfirmActionButton"
	confirm_button.pressed.connect(confirm_pending_action)
	panel.add_child(confirm_button)
	cancel_button = make_timeline_button("返回", Vector2(308, 230), Vector2(210, 62))
	cancel_button.name = "CancelActionButton"
	cancel_button.pressed.connect(close_confirmation)
	panel.add_child(cancel_button)


func refresh_save_slot() -> void:
	var has_save := WorkdayState.has_save()
	save_button.visible = has_save
	timeline.get_node("SaveConnector").visible = has_save
	timeline.get_node("SaveNodeNumber").visible = has_save
	delete_button.visible = has_save
	if has_save:
		var summary: Dictionary = WorkdayState.get_save_summary()
		save_button.text = "%s  %s\n第 %d 工作日" % [
			String(summary.get("date", "--/--")),
			String(summary.get("time", "--:--")),
			int(summary.get("day_number", 1)),
		]


func request_new_game() -> void:
	if WorkdayState.has_save():
		open_confirmation(
			"覆盖工作档案",
			"开始新游戏会清除当前工作进度。\n此操作无法撤销。",
			"new_game"
		)
	else:
		open_confirmation(
			"开始新的工作记录",
			"将从职位恢复审查开始新的工作。\n是否继续？",
			"new_game"
		)


func request_continue_game() -> void:
	if not WorkdayState.has_save():
		refresh_save_slot()
		return
	open_confirmation(
		"继续工作日",
		"将读取所选工作档案并返回工作岗位。\n是否继续？",
		"continue"
	)


func request_delete_save() -> void:
	if not WorkdayState.has_save():
		return
	open_confirmation(
		"销毁工作档案",
		"所选工作日及全部后续记录将被永久销毁。\n是否继续？",
		"delete"
	)


func open_confirmation(heading: String, copy: String, action: String) -> void:
	pending_action = action
	confirmation_title.text = heading
	confirmation_copy.text = copy
	match action:
		"new_game":
			confirm_button.text = "确认开始"
		"continue":
			confirm_button.text = "确认继续"
		"delete":
			confirm_button.text = "确认销毁"
	confirmation_layer.visible = true
	confirm_button.grab_focus()


func close_confirmation() -> void:
	confirmation_layer.visible = false
	pending_action = ""
	new_game_button.grab_focus()


func confirm_pending_action() -> void:
	match pending_action:
		"new_game":
			start_new_game()
		"continue":
			continue_game()
		"delete":
			WorkdayState.delete_save()
			close_confirmation()
			refresh_save_slot()


func start_new_game() -> void:
	Sfx.play("start")
	WorkdayState.start_new_game()
	change_scene(OPENING_SCENE)


func continue_game() -> void:
	if WorkdayState.load_progress():
		Sfx.play("start")
		change_scene(GAME_SCENE)
	else:
		refresh_save_slot()
		new_game_button.grab_focus()


func return_to_menu() -> void:
	change_scene(MENU_SCENE)


func change_scene(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("场景切换失败：%s / %s" % [path, error_string(error)])


func make_label(text: String, font_size: int, at: Vector2, dimensions: Vector2, muted := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	UI.style_label(label, font_size, muted)
	return label


func make_line(at: Vector2, dimensions: Vector2) -> ColorRect:
	var line := ColorRect.new()
	line.position = at
	line.size = dimensions
	line.color = Color("52644e")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func make_timeline_button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.custom_minimum_size = dimensions
	UI.style_button(button, 16)
	button.pressed.connect(func(): Sfx.play("ui_click"))
	button.mouse_entered.connect(func(): Sfx.play("ui_hover"))
	return button


func make_footer_button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := make_timeline_button(text, at, dimensions)
	button.add_theme_stylebox_override("normal", UI.make_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	return button


func add_trash_icon(button: Button) -> void:
	var icon := Control.new()
	icon.name = "TrashIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var color := UI.COLOR_TEXT
	var lid := ColorRect.new()
	lid.color = color
	lid.position = Vector2(18, 15)
	lid.size = Vector2(26, 3)
	icon.add_child(lid)
	var handle := ColorRect.new()
	handle.color = color
	handle.position = Vector2(26, 10)
	handle.size = Vector2(10, 4)
	icon.add_child(handle)
	var body := ColorRect.new()
	body.color = color
	body.position = Vector2(21, 21)
	body.size = Vector2(20, 24)
	icon.add_child(body)
	var inner := ColorRect.new()
	inner.color = Color("020403")
	inner.position = Vector2(25, 24)
	inner.size = Vector2(3, 17)
	icon.add_child(inner)
	var inner_right := ColorRect.new()
	inner_right.color = Color("020403")
	inner_right.position = Vector2(35, 24)
	inner_right.size = Vector2(3, 17)
	icon.add_child(inner_right)


func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	canvas.scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	canvas.position = Vector2.ZERO


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if confirmation_layer.visible:
			close_confirmation()
		else:
			return_to_menu()
