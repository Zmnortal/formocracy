extends Control

const MENU_SCENE := "res://scenes/main_menu.tscn"
const OPENING_SCENE := "res://scenes/opening.tscn"
const GAME_SCENE := "res://main.tscn"
const UI := preload("res://scripts/ui/bureau_ui.gd")

var canvas: Control
var title_label: Label
var timeline_scroll: ScrollContainer
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
var selected_checkpoint_id := ""
var checkpoint_buttons: Dictionary = {}
var checkpoint_nodes_by_id: Dictionary = {}
var checkpoint_positions: Dictionary = {}
var next_leaf_row := 0


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

	timeline_scroll = ScrollContainer.new()
	timeline_scroll.name = "TimelineScroll"
	timeline_scroll.position = Vector2(24, 150)
	timeline_scroll.size = Vector2(1232, 450)
	timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	timeline_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	timeline_scroll.follow_focus = true
	canvas.add_child(timeline_scroll)
	UI.style_range(timeline_scroll.get_h_scroll_bar())
	UI.style_range(timeline_scroll.get_v_scroll_bar())

	timeline = Control.new()
	timeline.name = "Timeline"
	timeline.size = Vector2(1232, 450)
	timeline.custom_minimum_size = Vector2(1232, 450)
	timeline_scroll.add_child(timeline)

	new_game_button = make_timeline_button("新游戏", Vector2(0, 342), Vector2(150, 70))
	new_game_button.name = "NewGameButton"
	new_game_button.pressed.connect(request_new_game)
	timeline.add_child(new_game_button)

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
	for child in timeline.get_children():
		if child != new_game_button:
			child.queue_free()
	checkpoint_buttons.clear()
	checkpoint_nodes_by_id.clear()
	checkpoint_positions.clear()
	next_leaf_row = 0
	save_button = null
	var nodes: Array[Dictionary] = WorkdayState.get_checkpoint_nodes()
	for node in nodes:
		checkpoint_nodes_by_id[String(node.get("node_id", ""))] = node
	if nodes.is_empty():
		new_game_button.visible = true
		new_game_button.position = Vector2(0, 72)
		delete_button.visible = false
		return
	# 存档存在时，“一开始”就是整棵树唯一的根入口。
	# 不再额外显示脱离树结构的“新游戏”卡片。
	new_game_button.visible = false
	var roots: Array[String] = []
	for node in nodes:
		if String(node.get("parent_id", "")).is_empty():
			roots.append(String(node.get("node_id", "")))
	for root_id in roots:
		assign_tree_position(root_id, 0)
	update_timeline_bounds()
	draw_tree_connections(nodes)
	for node in nodes:
		add_checkpoint_button(node)
	selected_checkpoint_id = WorkdayState.active_checkpoint_id
	if selected_checkpoint_id.is_empty() or not checkpoint_buttons.has(selected_checkpoint_id):
		selected_checkpoint_id = String(nodes[-1].get("node_id", ""))
	refresh_checkpoint_selection()


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
	if selected_checkpoint_id.is_empty():
		refresh_save_slot()
		return
	open_confirmation(
		"继续工作日",
		"将从此节点之后继续工作。\n原有后续分支不会被覆盖。",
		"continue"
	)


func request_delete_save() -> void:
	if selected_checkpoint_id.is_empty():
		return
	var selected: Dictionary = checkpoint_nodes_by_id.get(selected_checkpoint_id, {})
	if int(selected.get("completed_day", 0)) == 0:
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
			WorkdayState.delete_checkpoint(selected_checkpoint_id)
			selected_checkpoint_id = WorkdayState.active_checkpoint_id
			close_confirmation()
			refresh_save_slot()


func start_new_game() -> void:
	Sfx.play("start")
	WorkdayState.start_new_game()
	change_scene(OPENING_SCENE)


func continue_game() -> void:
	if WorkdayState.load_checkpoint(selected_checkpoint_id):
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


func assign_tree_position(node_id: String, depth: int) -> float:
	var children := get_child_ids(node_id)
	var row: float
	if children.is_empty():
		row = float(next_leaf_row)
		next_leaf_row += 1
	else:
		var first_row := assign_tree_position(children[0], depth + 1)
		var last_row := first_row
		for index in range(1, children.size()):
			last_row = assign_tree_position(children[index], depth + 1)
		row = (first_row + last_row) * 0.5
	checkpoint_positions[node_id] = Vector2(depth * 190, 72 + row * 112)
	return row


func get_child_ids(parent_id: String) -> Array[String]:
	var children: Array[Dictionary] = []
	for node in checkpoint_nodes_by_id.values():
		if String(node.get("parent_id", "")) == parent_id:
			children.append(node)
	children.sort_custom(func(a: Dictionary, b: Dictionary):
		return int(a.get("branch_order", 0)) < int(b.get("branch_order", 0))
	)
	var ids: Array[String] = []
	for child in children:
		ids.append(String(child.get("node_id", "")))
	return ids


func update_timeline_bounds() -> void:
	var required_width := 1232.0
	var required_height := 450.0
	for position_value in checkpoint_positions.values():
		var position: Vector2 = position_value
		required_width = maxf(required_width, position.x + 190.0)
		required_height = maxf(required_height, position.y + 122.0)
	timeline.custom_minimum_size = Vector2(required_width, required_height)
	timeline.size = timeline.custom_minimum_size


func draw_tree_connections(nodes: Array[Dictionary]) -> void:
	for node in nodes:
		var parent_id := String(node.get("parent_id", ""))
		var node_id := String(node.get("node_id", ""))
		if parent_id.is_empty() or not checkpoint_positions.has(parent_id):
			continue
		var parent_pos: Vector2 = checkpoint_positions[parent_id]
		var child_pos: Vector2 = checkpoint_positions[node_id]
		var start := parent_pos + Vector2(150, 46)
		var finish := child_pos + Vector2(0, 46)
		var midpoint_x := (start.x + finish.x) * 0.5
		timeline.add_child(make_line(start, Vector2(midpoint_x - start.x, 2)))
		timeline.add_child(make_line(Vector2(midpoint_x, minf(start.y, finish.y)), Vector2(2, absf(finish.y - start.y) + 2)))
		timeline.add_child(make_line(Vector2(midpoint_x, finish.y), Vector2(finish.x - midpoint_x, 2)))


func add_checkpoint_button(node: Dictionary) -> void:
	var node_id := String(node.get("node_id", ""))
	var completed_day := int(node.get("completed_day", 0))
	var created := Time.get_datetime_dict_from_unix_time(int(node.get("created_at", 0)))
	var label_text := "一开始" if completed_day == 0 else "第 %d 天\n%02d/%02d  %02d:%02d" % [
		completed_day, created.month, created.day, created.hour, created.minute
	]
	var button := make_timeline_button(label_text, checkpoint_positions[node_id], Vector2(150, 92))
	button.name = "Checkpoint_%s" % node_id
	button.pressed.connect(select_checkpoint.bind(node_id))
	timeline.add_child(button)
	checkpoint_buttons[node_id] = button
	if completed_day > 0:
		save_button = button


func select_checkpoint(node_id: String) -> void:
	selected_checkpoint_id = node_id
	refresh_checkpoint_selection()
	request_continue_game()


func refresh_checkpoint_selection() -> void:
	for node_id in checkpoint_buttons:
		var button: Button = checkpoint_buttons[node_id]
		button.modulate = Color.WHITE if node_id == selected_checkpoint_id else Color("a3aa91")
	var selected: Dictionary = checkpoint_nodes_by_id.get(selected_checkpoint_id, {})
	delete_button.visible = not selected.is_empty() and int(selected.get("completed_day", 0)) > 0


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
