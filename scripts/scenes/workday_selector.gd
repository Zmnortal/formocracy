extends Control

const MENU_SCENE := "res://scenes/main_menu.tscn"
const OPENING_SCENE := "res://scenes/opening.tscn"
const GAME_SCENE := "res://main.tscn"
const PRE_WORK_SCENE := "res://scenes/pre_work_sequence.tscn"
const DAILY_REPORT_SCENE := "res://scenes/daily_report.tscn"
const EVENING_MAP_SCENE := "res://scenes/evening_map.tscn"
const DEATH_NOTICE_SCENE := "res://scenes/du_chunmei_death_notice.tscn"
const TRIAL_COMPLETE_SCENE := "res://scenes/trial_complete.tscn"
const UI := preload("res://scripts/ui/bureau_ui.gd")
const ENTRANCE_FADE_SECONDS := 0.7

var canvas: Control
var entrance_cover: ColorRect
var title_label: Label
var timeline_scroll: ScrollContainer
var timeline: Control
var new_game_button: Button
var resume_button: Button
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
var resume_position := Vector2.ZERO
var next_leaf_row := 0
var entrance_complete := false


# 播放开场音乐、搭建场景并刷新存档时间线。
func _ready() -> void:
	# 开发者控制台直接进入本场景时，同样保证首帧清屏为黑色。
	RenderingServer.set_default_clear_color(Color.BLACK)
	OpeningMusic.play_opening()
	_build_scene()
	_build_entrance_cover()
	_refresh_save_slot()
	_fit_to_window()
	get_viewport().size_changed.connect(_fit_to_window)
	await get_tree().process_frame
	await _play_entrance_fade()
	_focus_primary_action()


# 在已完整渲染的记录页面上淡出黑幕，首帧始终为黑色，不暴露视口底色。
func _play_entrance_fade() -> void:
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_property(entrance_cover, "modulate:a", 0.0, ENTRANCE_FADE_SECONDS)
	await reveal.finished
	entrance_cover.visible = false
	entrance_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entrance_complete = true


# 创建覆盖真实视口的纯黑幕；记录页面在黑幕后方提前完成布局。
func _build_entrance_cover() -> void:
	entrance_cover = ColorRect.new()
	entrance_cover.name = "EntranceCover"
	entrance_cover.color = Color.BLACK
	entrance_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	entrance_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	entrance_cover.z_index = 100
	add_child(entrance_cover)


# 构建选日界面：标题、时间线滚动区、底部按钮与确认层。
func _build_scene() -> void:
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.size = Vector2(1280, 720)
	add_child(canvas)

	var background := ColorRect.new()
	background.color = Color("020403")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)

	title_label = _make_label("选择一天来继续或者从头开始游戏", 32, Vector2(240, 58), Vector2(800, 62))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(title_label)
	canvas.add_child(_make_line(Vector2(0, 132), Vector2(1280, 2)))
	canvas.add_child(_make_line(Vector2(0, 630), Vector2(1280, 2)))

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

	new_game_button = _make_timeline_button("新游戏", Vector2(0, 342), Vector2(150, 70))
	new_game_button.name = "NewGameButton"
	new_game_button.pressed.connect(request_new_game)
	timeline.add_child(new_game_button)

	back_button = _make_footer_button("返回", Vector2(470, 650), Vector2(340, 52))
	back_button.name = "BackButton"
	back_button.pressed.connect(_return_to_menu)
	canvas.add_child(back_button)

	delete_button = _make_footer_button("", Vector2(1180, 648), Vector2(62, 56))
	delete_button.name = "DeleteButton"
	delete_button.pressed.connect(request_delete_save)
	canvas.add_child(delete_button)
	_add_trash_icon(delete_button)

	_build_confirmation_layer()


# 构建带遮罩的确认弹窗及其确认、取消按钮。
func _build_confirmation_layer() -> void:
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

	confirmation_title = _make_label("", 32, Vector2(40, 38), Vector2(500, 52))
	confirmation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(confirmation_title)
	confirmation_copy = _make_label("", 16, Vector2(55, 112), Vector2(470, 80), true)
	confirmation_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirmation_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(confirmation_copy)

	confirm_button = _make_timeline_button("确认", Vector2(62, 230), Vector2(210, 62))
	confirm_button.name = "ConfirmActionButton"
	confirm_button.pressed.connect(confirm_pending_action)
	panel.add_child(confirm_button)
	cancel_button = _make_timeline_button("返回", Vector2(308, 230), Vector2(210, 62))
	cancel_button.name = "CancelActionButton"
	cancel_button.pressed.connect(close_confirmation)
	panel.add_child(cancel_button)


# 根据存档节点重建时间线：布局存档树、连线与继续按钮。
func _refresh_save_slot() -> void:
	for child in timeline.get_children():
		if child != new_game_button:
			child.queue_free()
	checkpoint_buttons.clear()
	checkpoint_nodes_by_id.clear()
	checkpoint_positions.clear()
	next_leaf_row = 0
	resume_button = null
	save_button = null
	var nodes: Array[Dictionary] = WorkdayState.save_system.get_checkpoint_nodes()
	for node: Dictionary in nodes:
		checkpoint_nodes_by_id[WorkdayContext.read_string(node, "node_id")] = node
	if nodes.is_empty():
		new_game_button.visible = true
		new_game_button.position = Vector2(0, 72)
		delete_button.visible = false
		if WorkdayState.save_system.has_save():
			_add_resume_button(Vector2(190, 72))
		return
	# 存档存在时，“一开始”就是整棵树唯一的根入口。
	# 不再额外显示脱离树结构的“新游戏”卡片。
	new_game_button.visible = false
	var roots: Array[String] = []
	for node: Dictionary in nodes:
		if WorkdayContext.read_string(node, "parent_id").is_empty():
			roots.append(WorkdayContext.read_string(node, "node_id"))
	if roots.is_empty():
		new_game_button.visible = true
		new_game_button.position = Vector2(0, 72)
		delete_button.visible = false
		_add_resume_button(Vector2(190, 72))
		return
	for root_id: String in roots:
		_assign_tree_position(root_id, 0)
	var active_position := _checkpoint_position(WorkdayState.active_checkpoint_id, _checkpoint_position(roots[0], Vector2(0, 72)))
	resume_position = Vector2(active_position.x + 190, 72 + next_leaf_row * 112)
	checkpoint_positions["__working_progress__"] = resume_position
	_update_timeline_bounds()
	_draw_tree_connections(nodes)
	_draw_resume_connection(active_position)
	for node: Dictionary in nodes:
		_add_checkpoint_button(node)
	_add_resume_button(resume_position)
	selected_checkpoint_id = WorkdayState.active_checkpoint_id
	if selected_checkpoint_id.is_empty() or not checkpoint_buttons.has(selected_checkpoint_id):
		selected_checkpoint_id = WorkdayContext.read_string(nodes[-1], "node_id")
	_refresh_checkpoint_selection()


# 弹出新游戏确认弹窗，有存档时提示会覆盖进度。
func request_new_game() -> void:
	if WorkdayState.save_system.has_save():
		_open_confirmation("覆盖工作档案", "开始新游戏会清除当前工作进度。\n此操作无法撤销。", "new_game")
	else:
		_open_confirmation("开始新的工作记录", "将从职位恢复审查开始新的工作。\n是否继续？", "new_game")


# 请求从选中节点继续：根节点转新游戏，否则确认创建分支。
func request_continue_game() -> void:
	if selected_checkpoint_id.is_empty():
		_refresh_save_slot()
		return
	var selected: Dictionary = checkpoint_nodes_by_id.get(selected_checkpoint_id, {})
	if WorkdayContext.read_int(selected, "completed_day") == 0:
		request_new_game()
		return
	_open_confirmation("从历史工作日继续", "将恢复此节点并创建一条新分支。\n原有后续记录不会被覆盖。", "branch")


# 弹出恢复最近自动存档的确认弹窗。
func request_resume_game() -> void:
	_open_confirmation("继续当前进度", "将恢复最近一次自动保存的工作状态。", "resume")


# 弹出销毁选中存档节点的确认弹窗，根节点不可删除。
func request_delete_save() -> void:
	if selected_checkpoint_id.is_empty():
		return
	var selected: Dictionary = checkpoint_nodes_by_id.get(selected_checkpoint_id, {})
	if WorkdayContext.read_int(selected, "completed_day") == 0:
		return
	_open_confirmation("销毁工作档案", "所选工作日及全部后续记录将被永久销毁。\n是否继续？", "delete")


# 打开确认弹窗，设置标题、文案与待确认动作类型。
func _open_confirmation(heading: String, copy: String, action: String) -> void:
	pending_action = action
	confirmation_title.text = heading
	confirmation_copy.text = copy
	match action:
		"new_game":
			confirm_button.text = "确认开始"
		"resume":
			confirm_button.text = "确认继续"
		"branch":
			confirm_button.text = "确认创建分支"
		"delete":
			confirm_button.text = "确认销毁"
	confirmation_layer.visible = true
	confirm_button.grab_focus()


# 关闭确认弹窗并清除待确认动作，焦点回到主操作。
func close_confirmation() -> void:
	confirmation_layer.visible = false
	pending_action = ""
	_focus_primary_action()


# 根据待确认动作类型执行新游戏、继续、分支或删除。
func confirm_pending_action() -> void:
	match pending_action:
		"new_game":
			_start_new_game()
		"resume":
			resume_game()
		"branch":
			_continue_game()
		"delete":
			WorkdayState.save_system.delete_checkpoint(selected_checkpoint_id)
			selected_checkpoint_id = WorkdayState.active_checkpoint_id
			close_confirmation()
			_refresh_save_slot()


# 重置存档并切换到开场场景开始新游戏。
func _start_new_game() -> void:
	Sfx.play("start")
	WorkdayState.start_new_game()
	_change_scene(OPENING_SCENE)


# 加载历史日节点后从下一天的晨间读报开始创建分支。
func _continue_game() -> void:
	var selected: Dictionary = checkpoint_nodes_by_id.get(selected_checkpoint_id, {})
	if WorkdayContext.read_int(selected, "completed_day") == 0:
		_start_new_game()
		return
	if WorkdayState.save_system.load_checkpoint(selected_checkpoint_id):
		Sfx.play("start")
		_change_scene(PRE_WORK_SCENE)
	else:
		_refresh_save_slot()
		new_game_button.grab_focus()


# 恢复最近进度并按存档阶段切换到对应场景。
func resume_game() -> void:
	if not WorkdayState.save_system.load_progress():
		_refresh_save_slot()
		_focus_primary_action()
		return
	Sfx.play("start")
	match WorkdayState.get_resume_phase():
		"trial_complete":
			_change_scene(TRIAL_COMPLETE_SCENE)
		"du_chunmei_death_notice":
			_change_scene(DEATH_NOTICE_SCENE)
		"pre_work":
			_change_scene(PRE_WORK_SCENE)
		"daily_report":
			_change_scene(DAILY_REPORT_SCENE)
		"evening":
			_change_scene(EVENING_MAP_SCENE)
		_:
			_change_scene(GAME_SCENE)


# 返回主菜单场景。
func _return_to_menu() -> void:
	_change_scene(MENU_SCENE)


# 切换到指定场景，失败时报错。
func _change_scene(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("场景切换失败：%s / %s" % [path, error_string(error)])


# 创建统一样式的文本标签。
func _make_label(text: String, font_size: int, at: Vector2, dimensions: Vector2, muted: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	UI.style_label(label, font_size, muted)
	return label


# 创建用于分隔与连线的纯色矩形。
func _make_line(at: Vector2, dimensions: Vector2) -> ColorRect:
	var line := ColorRect.new()
	line.position = at
	line.size = dimensions
	line.color = Color("52644e")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


# 递归为存档树节点分配时间线坐标，返回其所在行号。
func _assign_tree_position(node_id: String, depth: int) -> float:
	var children := _get_child_ids(node_id)
	var row: float
	if children.is_empty():
		row = float(next_leaf_row)
		next_leaf_row += 1
	else:
		var first_row := _assign_tree_position(children[0], depth + 1)
		var last_row := first_row
		for index in range(1, children.size()):
			last_row = _assign_tree_position(children[index], depth + 1)
		row = (first_row + last_row) * 0.5
	checkpoint_positions[node_id] = Vector2(depth * 190, 72 + row * 112)
	return row


# 返回指定节点按分支顺序排列的子节点 ID 列表。
func _get_child_ids(parent_id: String) -> Array[String]:
	var children: Array[Dictionary] = []
	for node_value: Variant in checkpoint_nodes_by_id.values():
		if not node_value is Dictionary:
			continue
		@warning_ignore("unsafe_cast")
		var node: Dictionary = node_value
		if WorkdayContext.read_string(node, "parent_id") == parent_id:
			children.append(node)
	children.sort_custom(_sort_by_branch_order)
	var ids: Array[String] = []
	for child: Dictionary in children:
		ids.append(WorkdayContext.read_string(child, "node_id"))
	return ids


# 根据节点坐标扩展时间线的最小尺寸以容纳全部卡片。
func _update_timeline_bounds() -> void:
	var required_width := 1232.0
	var required_height := 450.0
	for position_value: Variant in checkpoint_positions.values():
		if not position_value is Vector2:
			continue
		var position: Vector2 = position_value
		required_width = maxf(required_width, position.x + 190.0)
		required_height = maxf(required_height, position.y + 122.0)
	timeline.custom_minimum_size = Vector2(required_width, required_height)
	timeline.size = timeline.custom_minimum_size

	# 用横竖线段绘制存档树中父子节点之间的连线。


func _draw_tree_connections(nodes: Array[Dictionary]) -> void:
	for node: Dictionary in nodes:
		var parent_id := WorkdayContext.read_string(node, "parent_id")
		var node_id := WorkdayContext.read_string(node, "node_id")
		if parent_id.is_empty() or not checkpoint_positions.has(parent_id):
			continue
		var parent_pos: Vector2 = checkpoint_positions[parent_id]
		var child_pos: Vector2 = checkpoint_positions[node_id]
		var start := parent_pos + Vector2(150, 46)
		var finish := child_pos + Vector2(0, 46)
		var midpoint_x := (start.x + finish.x) * 0.5
		timeline.add_child(_make_line(start, Vector2(midpoint_x - start.x, 2)))
		timeline.add_child(_make_line(Vector2(midpoint_x, minf(start.y, finish.y)), Vector2(2, absf(finish.y - start.y) + 2)))
		timeline.add_child(_make_line(Vector2(midpoint_x, finish.y), Vector2(finish.x - midpoint_x, 2)))


# 绘制活跃节点到“继续当前进度”卡片的连线。
func _draw_resume_connection(active_position: Vector2) -> void:
	var start := active_position + Vector2(150, 46)
	var finish := resume_position + Vector2(0, 46)
	var midpoint_x := (start.x + finish.x) * 0.5
	timeline.add_child(_make_line(start, Vector2(midpoint_x - start.x, 2)))
	timeline.add_child(_make_line(Vector2(midpoint_x, minf(start.y, finish.y)), Vector2(2, absf(finish.y - start.y) + 2)))
	timeline.add_child(_make_line(Vector2(midpoint_x, finish.y), Vector2(finish.x - midpoint_x, 2)))


# 为存档节点创建带天数与时间标签的时间线按钮。
func _add_checkpoint_button(node: Dictionary) -> void:
	var node_id := WorkdayContext.read_string(node, "node_id")
	var completed_day := WorkdayContext.read_int(node, "completed_day")
	var created := Time.get_datetime_dict_from_unix_time(WorkdayContext.read_int(node, "created_at"))
	var label_text := (
		"一开始\n从开场开始"
		if completed_day == 0
		else (
			"第 %d 天\n%02d/%02d  %02d:%02d"
			% [
				completed_day,
				WorkdayContext.read_int(created, "month"),
				WorkdayContext.read_int(created, "day"),
				WorkdayContext.read_int(created, "hour"),
				WorkdayContext.read_int(created, "minute"),
			]
		)
	)
	var button := _make_timeline_button(label_text, _checkpoint_position(node_id), Vector2(150, 92))
	button.name = "Checkpoint_%s" % node_id
	button.pressed.connect(select_checkpoint.bind(node_id))
	timeline.add_child(button)
	checkpoint_buttons[node_id] = button
	if completed_day > 0:
		save_button = button


# 在指定位置创建“继续当前进度”按钮。
func _add_resume_button(at: Vector2) -> void:
	var summary := WorkdayState.save_system.get_save_summary()
	var day := maxi(1, WorkdayContext.read_int(summary, "day_number", WorkdayState.day_number))
	resume_button = _make_timeline_button("继续当前进度\n第 %d 工作日" % day, at, Vector2(170, 92))
	resume_button.name = "ResumeProgressButton"
	resume_button.pressed.connect(request_resume_game)
	timeline.add_child(resume_button)


# 选中指定存档节点并发起继续流程。
func select_checkpoint(node_id: String) -> void:
	selected_checkpoint_id = node_id
	_refresh_checkpoint_selection()
	request_continue_game()


# 根据选中状态更新节点按钮高亮与删除按钮可见性。
func _refresh_checkpoint_selection() -> void:
	for node_id: String in checkpoint_buttons:
		var button: Button = checkpoint_buttons[node_id]
		button.modulate = Color.WHITE if node_id == selected_checkpoint_id else Color("a3aa91")
	var selected: Dictionary = checkpoint_nodes_by_id.get(selected_checkpoint_id, {})
	delete_button.visible = (not selected.is_empty() and WorkdayContext.read_int(selected, "completed_day") > 0)


# 优先聚焦继续按钮，否则聚焦新游戏按钮。
func _focus_primary_action() -> void:
	if is_instance_valid(resume_button) and resume_button.visible:
		resume_button.grab_focus()
	elif is_instance_valid(new_game_button):
		new_game_button.grab_focus()


# 创建带点击与悬停音效的时间线按钮。
func _make_timeline_button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.custom_minimum_size = dimensions
	UI.style_button(button, 16)
	button.pressed.connect(_play_button_click)
	button.mouse_entered.connect(_play_button_hover)
	return button


# 创建背景透明的底部按钮。
func _make_footer_button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := _make_timeline_button(text, at, dimensions)
	button.add_theme_stylebox_override("normal", UI.make_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	return button


# 用矩形色块在按钮上绘制垃圾桶图标。
func _add_trash_icon(button: Button) -> void:
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


# 按窗口尺寸缩放 1280x720 的画布以铺满视口。
func _fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	canvas.scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	canvas.position = Vector2.ZERO


# 按下 ESC 键时优先关闭确认弹窗，否则返回主菜单。
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		if confirmation_layer.visible:
			close_confirmation()
		else:
			_return_to_menu()


# 返回已缓存的时间线位置。
func _checkpoint_position(node_id: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var value: Variant = checkpoint_positions.get(node_id, fallback)
	return value if value is Vector2 else fallback


# 按存档分支顺序升序排列节点。
func _sort_by_branch_order(a: Dictionary, b: Dictionary) -> bool:
	return WorkdayContext.read_int(a, "branch_order") < WorkdayContext.read_int(b, "branch_order")


# 播放时间线按钮点击音效。
func _play_button_click() -> void:
	Sfx.play("ui_click")


# 播放时间线按钮悬停音效。
func _play_button_hover() -> void:
	Sfx.play("ui_hover")
