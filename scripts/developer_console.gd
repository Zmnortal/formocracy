extends CanvasLayer

const MAIN_SCENE := "res://main.tscn"
const OPENING_SCENE := "res://scenes/opening.tscn"
const REPORT_SCENE := "res://scenes/daily_report.tscn"
const VALIDATION_SCENE := "res://scenes/validation_preview.tscn"

var enabled := true
var is_open := false
var root_control: Control
var dev_button: Button
var blocker: ColorRect
var console_panel: Panel
var scene_selector: OptionButton
var day_selector: SpinBox
var preset_selector: OptionButton
var status_label: Label
var output: RichTextLabel
var command_input: LineEdit
var command_history: Array[String] = []
var history_index := 0
var status_elapsed := 0.0


# 开发控制台入口初始化。
# 设置 CanvasLayer 层级为 1000 并启用 PROCESS_MODE_ALWAYS，确保在暂停等状态下仍能响应；
# 读取 ProjectSettings 中的 debug/developer_console_enabled 决定是否启用控制台。启用时构建 UI、绑定窗口缩放事件、输出欢迎信息、刷新状态，
# 若命令行参数包含 --dev-console-open 则在启动时自动打开控制台。
func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = bool(ProjectSettings.get_setting("debug/developer_console_enabled", true))
	if not enabled:
		return
	build_ui()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()
	append_output("FORMOCRACY DEV CONSOLE READY")
	append_output("按 ` 或点击 DEV 打开；输入 help 查看命令。")
	refresh_status()
	if OS.get_cmdline_user_args().has("--dev-console-open"):
		toggle_console()


# 工厂方法：创建并返回一个 StyleBoxFlat。
# 用于统一控制台各控件（面板、按钮、终端背景等）的背景色、边框色、边框宽度与圆角半径，减少重复代码。
# color 为背景色；border_color 为边框色；border 为四边边框宽度；radius 为四角圆角半径。
func make_box(color: Color, border_color: Color, border := 2, radius := 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_width_left = border
	box.border_width_top = border
	box.border_width_right = border
	box.border_width_bottom = border
	box.border_color = border_color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box


# 构建控制台完整 UI。
# 依次创建根 Control、DEV 入口按钮、黑色半透明遮罩、中央面板、标题、关闭按钮、场景选择下拉框、工作日设置 SpinBox、状态标签、
# 测试数据预设选择、快捷操作按钮、RichTextLabel 命令输出区以及 LineEdit 命令输入框，并为各交互控件绑定回调。
func build_ui() -> void:
	root_control = Control.new()
	root_control.position = Vector2.ZERO
	root_control.size = Vector2(1280, 720)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	dev_button = Button.new()
	dev_button.text = "DEV"
	dev_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dev_button.position = Vector2(-76, 14)
	dev_button.size = Vector2(60, 34)
	dev_button.add_theme_color_override("font_color", Color("b9d778"))
	dev_button.add_theme_stylebox_override("normal", make_box(Color(0.03, 0.07, 0.04, 0.92), Color("6e8d45")))
	dev_button.add_theme_stylebox_override("hover", make_box(Color(0.08, 0.15, 0.08, 0.98), Color("9bbb60")))
	dev_button.pressed.connect(toggle_console)
	root_control.add_child(dev_button)

	blocker = ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.72)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	root_control.add_child(blocker)

	console_panel = Panel.new()
	console_panel.set_anchors_preset(Control.PRESET_CENTER)
	console_panel.position = Vector2(-500, -300)
	console_panel.size = Vector2(1000, 600)
	console_panel.add_theme_stylebox_override("panel", make_box(Color("08100c"), Color("78934f"), 3, 5))
	blocker.add_child(console_panel)

	var title := Label.new()
	title.text = "FORMOCRACY // 开发控制台"
	title.position = Vector2(26, 18)
	title.size = Vector2(600, 32)
	title.add_theme_color_override("font_color", Color("a9ca6b"))
	title.add_theme_font_size_override("font_size", 22)
	console_panel.add_child(title)

	var close_button := Button.new()
	close_button.text = "关闭 [`]"
	close_button.position = Vector2(850, 16)
	close_button.size = Vector2(122, 34)
	close_button.pressed.connect(toggle_console)
	console_panel.add_child(close_button)

	create_section_label("场景与状态", Vector2(28, 68))
	scene_selector = OptionButton.new()
	scene_selector.position = Vector2(28, 100)
	scene_selector.size = Vector2(250, 40)
	scene_selector.add_item("游戏开场")
	scene_selector.set_item_metadata(0, OPENING_SCENE)
	scene_selector.add_item("主工作台")
	scene_selector.set_item_metadata(1, MAIN_SCENE)
	scene_selector.add_item("工作日处理回执")
	scene_selector.set_item_metadata(2, REPORT_SCENE)
	scene_selector.add_item("现实验收设施预览")
	scene_selector.set_item_metadata(3, VALIDATION_SCENE)
	console_panel.add_child(scene_selector)
	var switch_button := create_button("立即切换", Vector2(292, 100), Vector2(126, 40))
	switch_button.pressed.connect(_on_switch_scene)

	day_selector = SpinBox.new()
	day_selector.position = Vector2(28, 156)
	day_selector.size = Vector2(180, 40)
	day_selector.min_value = 1
	day_selector.max_value = 999
	day_selector.value = WorkdayState.day_number
	day_selector.prefix = "工作日 "
	console_panel.add_child(day_selector)
	var set_day_button := create_button("设置", Vector2(220, 156), Vector2(92, 40))
	set_day_button.pressed.connect(_on_set_day)

	status_label = Label.new()
	status_label.position = Vector2(450, 84)
	status_label.size = Vector2(520, 116)
	status_label.add_theme_color_override("font_color", Color("d8c98b"))
	status_label.add_theme_font_size_override("font_size", 17)
	console_panel.add_child(status_label)

	create_section_label("测试数据与快捷操作", Vector2(28, 222))
	preset_selector = OptionButton.new()
	preset_selector.position = Vector2(28, 254)
	preset_selector.size = Vector2(250, 40)
	for item in ["空日报", "全部批准", "全部驳回", "批准与驳回混合"]:
		preset_selector.add_item(item)
	console_panel.add_child(preset_selector)
	var apply_preset := create_button("应用并打开日报", Vector2(292, 254), Vector2(188, 40))
	apply_preset.pressed.connect(_on_apply_preset)

	var fill_button := create_button("填充三件测试申请", Vector2(28, 310), Vector2(210, 40))
	fill_button.pressed.connect(func(): fill_test_records("mixed"))
	var clear_button := create_button("清空当日记录", Vector2(250, 310), Vector2(172, 40))
	clear_button.pressed.connect(clear_records)
	var next_button := create_button("进入下一工作日", Vector2(434, 310), Vector2(184, 40))
	next_button.pressed.connect(next_day)
	var reload_button := create_button("重载当前场景", Vector2(630, 310), Vector2(170, 40))
	reload_button.pressed.connect(reload_scene)

	create_section_label("命令终端", Vector2(28, 374))
	output = RichTextLabel.new()
	output.position = Vector2(28, 406)
	output.size = Vector2(944, 112)
	output.bbcode_enabled = true
	output.scroll_active = true
	output.add_theme_color_override("default_color", Color("9fbd72"))
	output.add_theme_stylebox_override("normal", make_box(Color("030604"), Color("36472d"), 1, 1))
	console_panel.add_child(output)
	command_input = LineEdit.new()
	command_input.placeholder_text = "输入命令，例如：scene report"
	command_input.position = Vector2(28, 530)
	command_input.size = Vector2(944, 44)
	command_input.text_submitted.connect(execute_command)
	command_input.gui_input.connect(_on_command_input_gui)
	console_panel.add_child(command_input)


# 在控制台面板指定位置创建一个 400x26 的分区说明标签。
# 使用统一的暗绿色字体，用于对控制台不同功能区进行文字分组。
func create_section_label(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(400, 26)
	label.add_theme_color_override("font_color", Color("7f9c5c"))
	console_panel.add_child(label)


# 在控制台面板指定位置创建按钮并返回引用。
# text 为按钮文字；at 为按钮左上角坐标；dimensions 为按钮宽高。返回的引用可继续连接 pressed 等信号。
func create_button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	console_panel.add_child(button)
	return button


# 全局输入监听。
# 控制台启用时，按下反引号（`）切换显示/隐藏；控制台打开时，按下 ESC 关闭。
# 处理完成后调用 set_input_as_handled()，避免事件继续传播到游戏场景。
func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.unicode == 96:
		toggle_console()
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_console()
		get_viewport().set_input_as_handled()


# 切换控制台的显示/隐藏状态。
# 同步 blocker（主面板）与 dev_button（入口）的可见性；打开时同步工作日选择器数值、刷新状态并让命令输入框获得焦点；关闭时释放焦点。
func toggle_console() -> void:
	is_open = not is_open
	blocker.visible = is_open
	dev_button.visible = not is_open
	if is_open:
		day_selector.value = WorkdayState.day_number
		refresh_status()
		command_input.grab_focus()
	else:
		command_input.release_focus()


# 每帧更新控制台的实时状态。
# 累加 status_elapsed，每 0.25 秒调用一次 refresh_status()，使状态标签中的场景名、工作日、记录数等保持实时同步。
func _process(delta: float) -> void:
	if not enabled or not is_open:
		return
	status_elapsed += delta
	if status_elapsed >= 0.25:
		status_elapsed = 0.0
		refresh_status()


# 根据当前可视视口大小缩放控制台根节点。
# 以 1280x720 为基准分辨率进行等比例缩放，使控制台在不同窗口尺寸下都能铺满屏幕。
func fit_to_window() -> void:
	if root_control == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	root_control.scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	root_control.position = Vector2.ZERO


# 刷新控制台状态标签。
# 显示当前场景名、WorkdayState.day_number、当日记录数与 CASES_PER_DAY 之比，
# 以及根据 should_show_report() 判断的日报触发状态（可生成 / 未满足触发条件）。
func refresh_status() -> void:
	if status_label == null:
		return
	var current := "无场景"
	if get_tree().current_scene != null:
		current = get_tree().current_scene.name
	status_label.text = "当前场景：%s\n工作日：%d\n当日记录：%d / %d\n日报状态：%s" % [
		current, WorkdayState.day_number, WorkdayState.records.size(),
		WorkdayState.CASES_PER_DAY,
		"可生成" if WorkdayState.should_show_report() else "未满足触发条件"
	]


# 场景选择器回调。
# 读取当前选中项的 metadata（场景文件路径），并调用 switch_scene() 执行切换。
func _on_switch_scene() -> void:
	var path := String(scene_selector.get_item_metadata(scene_selector.selected))
	switch_scene(path)


# 切换到指定场景文件。
# path 为目标场景的资源路径。切换成功时向输出区打印日志，若控制台当前打开则自动关闭；切换失败时输出错误码以便排查。
func switch_scene(path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(path)
	if error == OK:
		append_output("已切换场景：" + path)
		if is_open:
			toggle_console()
	else:
		append_output("场景切换失败：%s / 错误码 %d" % [path, error])


# 工作日设置按钮回调。
# 将 WorkdayState.day_number 设置为工作日选择器的整数值，向输出区打印变更信息并刷新状态标签。
func _on_set_day() -> void:
	WorkdayState.day_number = int(day_selector.value)
	append_output("工作日已设置为 %d" % WorkdayState.day_number)
	refresh_status()


# 测试数据预设按钮回调。
# 根据 preset_selector 的选中项决定：清空记录、填充全部批准/驳回/混合的测试申请，然后切换到日报场景。
func _on_apply_preset() -> void:
	match preset_selector.selected:
		0:
			WorkdayState.records.clear()
		1:
			fill_test_records("approved")
		2:
			fill_test_records("rejected")
		3:
			fill_test_records("mixed")
	switch_scene(REPORT_SCENE)


# 使用内置示例数据填充当日申请记录。
# mode 可选 "approved"（全部批准）、"rejected"（全部驳回）或 "mixed"（第二件驳回，其余批准）。
# 填充前会先清空现有记录，完成后向输出区打印填充模式并刷新状态。
func fill_test_records(mode: String = "mixed") -> void:
	WorkdayState.records.clear()
	var samples := [
		{"department": "第十二区居住配置处", "code": "R-12/住房用途变更申请", "applicant": "林默，公民序号 74-119-02", "request": "共同居住配额"},
		{"department": "公共供给连续性办公室", "code": "W-08/饮水额度临时调整", "applicant": "周循，公民序号 20-441-88", "request": "净水领取额度"},
		{"department": "中央医疗秩序协调科", "code": "M-31/非计划医疗通行申请", "applicant": "许桥，公民序号 51-004-63", "request": "限制时段医疗通行"}
	]
	for i in samples.size():
		var decision := "批准"
		if mode == "rejected" or (mode == "mixed" and i == 1):
			decision = "驳回"
		WorkdayState.record_case(samples[i], decision)
	append_output("已填充测试数据：%s" % mode)
	refresh_status()


# 清空 WorkdayState.records 中所有当日申请记录。
# 操作完成后向输出区打印提示并刷新状态标签。
func clear_records() -> void:
	WorkdayState.records.clear()
	append_output("已清空当日记录。")
	refresh_status()


# 手动进入下一工作日。
# 调用 WorkdayState.begin_next_day() 推进工作日，同步更新工作日选择器的显示值，向输出区打印新工作日并刷新状态。
func next_day() -> void:
	WorkdayState.begin_next_day()
	day_selector.value = WorkdayState.day_number
	append_output("已进入工作日 %d" % WorkdayState.day_number)
	refresh_status()


# 重载当前场景。
# 调用 get_tree().reload_current_scene()，根据返回的错误码在输出区显示成功或失败信息。
func reload_scene() -> void:
	var error: Error = get_tree().reload_current_scene()
	append_output("当前场景已重载。" if error == OK else "场景重载失败：%d" % error)


# 解析并执行玩家在命令终端输入的文本命令。
# 支持的命令：help（帮助）、scene（切换场景）、report fill（填充测试数据）、day next（进入下一工作日）、state（刷新状态）、clear（清空输出区）。
# 维护 command_history 与 history_index 以支持上下键历史浏览；未知命令会给出提示。
func execute_command(command: String) -> void:
	var clean := command.strip_edges()
	command_input.clear()
	if clean.is_empty():
		return
	command_history.append(clean)
	history_index = command_history.size()
	append_output("> " + clean)
	var parts := clean.split(" ", false)
	match parts[0].to_lower():
		"help":
			append_output("scene opening | scene main | scene report | scene validation | scene reload")
			append_output("report fill | day next | state | clear")
		"scene":
			if parts.size() < 2:
				append_output("用法：scene opening|main|report|validation|reload")
			else:
				match parts[1].to_lower():
					"opening": switch_scene(OPENING_SCENE)
					"main": switch_scene(MAIN_SCENE)
					"report": switch_scene(REPORT_SCENE)
					"validation": switch_scene(VALIDATION_SCENE)
					"reload": reload_scene()
					_: append_output("未知场景：" + parts[1])
		"report":
			if parts.size() > 1 and parts[1].to_lower() == "fill":
				fill_test_records("mixed")
			else:
				append_output("用法：report fill")
		"day":
			if parts.size() > 1 and parts[1].to_lower() == "next":
				next_day()
			else:
				append_output("用法：day next")
		"state": refresh_status(); append_output(status_label.text.replace("\n", " | "))
		"clear": output.clear()
		_: append_output("未知命令：%s；输入 help 查看帮助。" % parts[0])


# 向命令输出区追加一行文本。
# text 为要显示的字符串；追加后自动滚动到输出区最底部，确保最新反馈始终可见。
func append_output(text: String) -> void:
	if output == null:
		return
	output.append_text(text + "\n")
	output.scroll_to_line(maxi(0, output.get_line_count() - 1))


# 处理命令输入框的键盘事件。
# 按上键（KEY_UP）浏览更早的历史命令；按下键（KEY_DOWN）浏览更新的历史命令，到达末尾时清空输入框；
# 每次切换历史后都将 caret_column 移到文本末尾，方便连续编辑或执行。
func _on_command_input_gui(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_UP and not command_history.is_empty():
		history_index = maxi(0, history_index - 1)
		command_input.text = command_history[history_index]
		command_input.caret_column = command_input.text.length()
	elif event.keycode == KEY_DOWN and not command_history.is_empty():
		history_index = mini(command_history.size(), history_index + 1)
		command_input.text = "" if history_index == command_history.size() else command_history[history_index]
		command_input.caret_column = command_input.text.length()
