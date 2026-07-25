extends CanvasLayer

const MAIN_SCENE := "res://main.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const WORKDAY_SELECTOR_SCENE := "res://scenes/workday_selector.tscn"
const OPENING_SCENE := "res://scenes/opening.tscn"
const REPORT_SCENE := "res://scenes/daily_report.tscn"
const EVENING_MAP_SCENE := "res://scenes/evening_map.tscn"
const VALIDATION_SCENE := "res://scenes/validation_preview.tscn"

# 共享 UI 样式工具库
const UI := preload("res://scripts/ui/bureau_ui.gd")
const InteractionDebugOverlayScene := preload("res://scripts/ui/interaction_debug_overlay.gd")

var enabled := true
var is_open := false
var root_control: Control
var dev_button: Button
var blocker: ColorRect
var console_panel: Panel
var scene_selector: OptionButton
var day_selector: SpinBox
var credit_selector: SpinBox
var level_selector: OptionButton
var seed_selector: SpinBox
var preset_selector: OptionButton
var collision_button: Button
var glass_test_button: Button
var glass_event_selector: OptionButton
var interaction_overlay: Control
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
	enabled = WorkdayContext.to_bool(ProjectSettings.get_setting("debug/developer_console_enabled", true), true)
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
	return UI.make_box(color, border_color, border, radius)


# 构建控制台完整 UI。
# 依次创建根 Control、DEV 入口按钮、黑色半透明遮罩、中央面板、标题、关闭按钮、场景选择下拉框、工作日设置 SpinBox、状态标签、
# 测试数据预设选择、快捷操作按钮、RichTextLabel 命令输出区以及 LineEdit 命令输入框，并为各交互控件绑定回调。
func build_ui() -> void:
	root_control = Control.new()
	root_control.position = Vector2.ZERO
	root_control.size = Vector2(1280, 720)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	interaction_overlay = InteractionDebugOverlayScene.new()
	interaction_overlay.name = "InteractionDebugOverlay"
	interaction_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interaction_overlay.z_index = -50
	interaction_overlay.visible = false
	root_control.add_child(interaction_overlay)

	dev_button = Button.new()
	dev_button.text = "DEV"
	dev_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dev_button.position = Vector2(-76, 14)
	dev_button.size = Vector2(60, 34)
	UI.style_button(dev_button, 16)
	dev_button.pressed.connect(toggle_console)
	root_control.add_child(dev_button)

	blocker = ColorRect.new()
	blocker.color = UI.COLOR_BACKDROP
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	root_control.add_child(blocker)

	console_panel = Panel.new()
	console_panel.set_anchors_preset(Control.PRESET_CENTER)
	console_panel.position = Vector2(-500, -330)
	console_panel.size = Vector2(1000, 660)
	UI.style_panel(console_panel)
	blocker.add_child(console_panel)

	var title := Label.new()
	title.text = "FORMOCRACY // 开发控制台"
	title.position = Vector2(26, 18)
	title.size = Vector2(600, 32)
	UI.style_label(title, 22)
	console_panel.add_child(title)

	var close_button := Button.new()
	close_button.text = "关闭 [`]"
	close_button.position = Vector2(850, 16)
	close_button.size = Vector2(122, 34)
	UI.style_button(close_button, 15)
	close_button.pressed.connect(toggle_console)
	console_panel.add_child(close_button)

	create_section_label("场景与状态", Vector2(28, 68))
	scene_selector = OptionButton.new()
	scene_selector.position = Vector2(28, 100)
	scene_selector.size = Vector2(250, 40)
	scene_selector.add_item("标题主菜单")
	scene_selector.set_item_metadata(0, MENU_SCENE)
	scene_selector.add_item("工作日选择")
	scene_selector.set_item_metadata(1, WORKDAY_SELECTOR_SCENE)
	scene_selector.add_item("首次叙事")
	scene_selector.set_item_metadata(2, OPENING_SCENE)
	scene_selector.add_item("主工作台")
	scene_selector.set_item_metadata(3, MAIN_SCENE)
	scene_selector.add_item("工作日处理回执")
	scene_selector.set_item_metadata(4, REPORT_SCENE)
	scene_selector.add_item("下班后的城市地图")
	scene_selector.set_item_metadata(5, EVENING_MAP_SCENE)
	scene_selector.add_item("现实验收设施预览")
	scene_selector.set_item_metadata(6, VALIDATION_SCENE)
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

	level_selector = OptionButton.new()
	level_selector.position = Vector2(330, 156)
	level_selector.size = Vector2(170, 40)
	for level_id in ConfigDatabase.get_level_ids():
		level_selector.add_item(level_id)
		level_selector.set_item_metadata(level_selector.item_count - 1, level_id)
	console_panel.add_child(level_selector)
	seed_selector = SpinBox.new()
	seed_selector.position = Vector2(512, 156)
	seed_selector.size = Vector2(150, 40)
	seed_selector.min_value = -1
	seed_selector.max_value = 999999
	seed_selector.value = -1
	seed_selector.prefix = "种子 "
	console_panel.add_child(seed_selector)
	var start_level_button := create_button("启动关卡", Vector2(674, 156), Vector2(130, 40))
	start_level_button.pressed.connect(_on_start_level)
	var reload_config_button := create_button("重载配置", Vector2(816, 156), Vector2(130, 40))
	reload_config_button.pressed.connect(_on_reload_config)

	status_label = Label.new()
	status_label.position = Vector2(450, 68)
	status_label.size = Vector2(520, 82)
	UI.style_label(status_label, 17)
	console_panel.add_child(status_label)

	create_section_label("测试数据与快捷操作", Vector2(28, 222))
	preset_selector = OptionButton.new()
	preset_selector.position = Vector2(28, 254)
	preset_selector.size = Vector2(250, 40)
	for item: String in ["空日报", "全部批准", "全部驳回", "批准与驳回混合"]:
		preset_selector.add_item(item)
	console_panel.add_child(preset_selector)
	var apply_preset := create_button("应用并打开日报", Vector2(292, 254), Vector2(188, 40))
	apply_preset.pressed.connect(_on_apply_preset)
	glass_event_selector = OptionButton.new()
	glass_event_selector.name = "GlassEventSelector"
	glass_event_selector.position = Vector2(492, 254)
	glass_event_selector.size = Vector2(220, 40)
	var glass_events: Array[Dictionary] = [
		{"label": "连接测试", "id": "test"},
		{"label": "晨间指令", "id": "briefing"},
		{"label": "NPC 台词", "id": "npc"},
		{"label": "现实验收回执", "id": "receipt"},
		{"label": "每日结算", "id": "report"},
		{"label": "后果回流", "id": "consequence"},
		{"label": "内部广播", "id": "broadcast"},
	]
	for event_data: Dictionary in glass_events:
		glass_event_selector.add_item(WorkdayContext.read_string(event_data, "label"))
		glass_event_selector.set_item_metadata(glass_event_selector.item_count - 1, WorkdayContext.read_string(event_data, "id"))
	console_panel.add_child(glass_event_selector)
	glass_test_button = create_button("发送眼镜事件", Vector2(724, 254), Vector2(248, 40))
	glass_test_button.name = "GlassTestButton"
	glass_test_button.pressed.connect(send_selected_glass_event)

	var fill_button := create_button("填充三件测试申请", Vector2(28, 310), Vector2(210, 40))
	fill_button.pressed.connect(_fill_mixed_test_records)
	var clear_button := create_button("清空当日记录", Vector2(250, 310), Vector2(172, 40))
	clear_button.pressed.connect(clear_records)
	var next_button := create_button("进入下一工作日", Vector2(434, 310), Vector2(184, 40))
	next_button.pressed.connect(next_day)
	var reload_button := create_button("重载当前场景", Vector2(630, 310), Vector2(170, 40))
	reload_button.pressed.connect(reload_scene)
	collision_button = create_button("", Vector2(812, 310), Vector2(160, 40))
	collision_button.name = "CollisionDebugButton"
	collision_button.pressed.connect(toggle_collision_debug)
	refresh_collision_button()

	create_section_label("Credit 调试", Vector2(28, 370))
	credit_selector = SpinBox.new()
	credit_selector.name = "CreditSelector"
	credit_selector.position = Vector2(28, 400)
	credit_selector.size = Vector2(190, 40)
	credit_selector.min_value = -9999
	credit_selector.max_value = 9999
	credit_selector.value = WorkdayState.political_credit
	credit_selector.prefix = "政治信用 "
	console_panel.add_child(credit_selector)
	var credit_minus_ten := create_button("−10", Vector2(232, 400), Vector2(76, 40))
	credit_minus_ten.pressed.connect(func(): adjust_credit(-10))
	var credit_minus_one := create_button("−1", Vector2(320, 400), Vector2(76, 40))
	credit_minus_one.pressed.connect(func(): adjust_credit(-1))
	var credit_set := create_button("设为输入值", Vector2(408, 400), Vector2(132, 40))
	credit_set.pressed.connect(set_credit_from_selector)
	var credit_plus_one := create_button("+1", Vector2(552, 400), Vector2(76, 40))
	credit_plus_one.pressed.connect(func(): adjust_credit(1))
	var credit_plus_ten := create_button("+10", Vector2(640, 400), Vector2(76, 40))
	credit_plus_ten.pressed.connect(func(): adjust_credit(10))

	create_section_label("命令终端", Vector2(28, 458))
	output = RichTextLabel.new()
	output.position = Vector2(28, 488)
	output.size = Vector2(944, 92)
	output.bbcode_enabled = true
	output.scroll_active = true
	output.add_theme_color_override("default_color", Color("9fbd72"))
	output.add_theme_font_override("normal_font", UI.PIXEL_FONT)
	output.add_theme_font_size_override("normal_font_size", 15)
	output.add_theme_stylebox_override("normal", make_box(Color("030604"), Color("36472d"), 1, 1))
	console_panel.add_child(output)
	command_input = LineEdit.new()
	command_input.placeholder_text = "输入命令，例如：scene report"
	command_input.position = Vector2(28, 592)
	command_input.size = Vector2(944, 44)
	command_input.add_theme_font_override("font", UI.PIXEL_FONT)
	command_input.add_theme_font_size_override("font_size", 16)
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
	UI.style_label(label, 16, true)
	console_panel.add_child(label)


# 在控制台面板指定位置创建按钮并返回引用。
# text 为按钮文字；at 为按钮左上角坐标；dimensions 为按钮宽高。返回的引用可继续连接 pressed 等信号。
func create_button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	UI.style_button(button, 15)
	console_panel.add_child(button)
	return button


# 切换 Godot 运行时碰撞形状绘制。仅影响当前开发会话，不写入游戏存档。
func toggle_collision_debug() -> void:
	var enabled_now := not interaction_overlay.visible
	interaction_overlay.visible = enabled_now
	get_tree().debug_collisions_hint = enabled_now
	refresh_collision_button()
	append_output("游戏交互框：%s" % ("显示" if enabled_now else "关闭"))


# 刷新碰撞调试按钮文字，显示当前交互框可见状态。
func refresh_collision_button() -> void:
	if collision_button == null:
		return
	collision_button.text = "交互框：%s" % ("显示" if interaction_overlay.visible else "关闭")


# 发送选择器中当前选中的眼镜联调事件。
func send_selected_glass_event() -> void:
	var event_id := WorkdayContext.stringify_value(glass_event_selector.get_item_metadata(glass_event_selector.selected))
	send_glass_event(event_id)


# 根据事件 ID 向 RealityBridge 发送对应的眼镜联调事件。
func send_glass_event(event_id: String) -> void:
	if not is_instance_valid(RealityBridge):
		append_output("眼镜桥接器未加载。")
		return
	if not RealityBridge.is_connected_to_glass():
		append_output("眼镜尚未连接；请确认手机 App 的游戏连接服务已启动。")
		return
	match event_id:
		"test":
			RealityBridge.send_test()
		"briefing":
			RealityBridge.morning_briefing(WorkdayState.day_number, ["今日配额：3 件", "重点核验：身份与现居地址", "程序错误将进入日终问责"], "第十二区 · 晨间指令")
		"npc":
			RealityBridge.npc_line("林默", "您好。我来办理共同居住配额。", "male", "young")
		"receipt":
			RealityBridge.reality_receipt("林默 · 现实验收回执", "处理决定：批准\n程序记录：完整\n档案已取得现实效力", "normal", WorkdayState.day_number, "CASE-001", "approved")
		"report":
			RealityBridge.day_report(["形式审查：3　批准：2　驳回：1", "程序错误：0　现实生效：2", "日薪：+120　罚款：-0", "本日结余：+90"], WorkdayState.day_number, "工作日处理回执")
		"consequence":
			RealityBridge.consequence("昨日工作后果", "行政罚款：-80\n政治信用：-2\n系统评价：受到关注", "warning")
		"broadcast":
			RealityBridge.secretary_line("下一位。")
		_:
			append_output("未知眼镜事件：%s" % event_id)
			return
	append_output("已发送眼镜事件：%s" % event_id)


# 全局输入监听。
# 控制台启用时，按下反引号（`）切换显示/隐藏；控制台打开时，按下 ESC 关闭。
# 处理完成后调用 set_input_as_handled()，避免事件继续传播到游戏场景。
func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event
	if key_event.pressed and not key_event.echo and key_event.unicode == 96:
		toggle_console()
		get_viewport().set_input_as_handled()
	elif is_open and key_event.pressed and key_event.keycode == KEY_ESCAPE:
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
		credit_selector.value = WorkdayState.political_credit
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
	status_label.text = (
		"场景：%s  关卡：%s\n工作日：%d  Credit：%d  记录：%d / %d\n日报：%s"
		% [
			current,
			WorkdayState.current_level_id,
			WorkdayState.day_number,
			WorkdayState.political_credit,
			WorkdayState.records.size(),
			WorkdayState.target_case_count,
			"可生成" if WorkdayState.manager.should_show_report() else "未满足触发条件"
		]
	)


# 场景选择器回调。
# 读取当前选中项的 metadata（场景文件路径），并调用 switch_scene() 执行切换。
func _on_switch_scene() -> void:
	var path := WorkdayContext.stringify_value(scene_selector.get_item_metadata(scene_selector.selected))
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


# 将政治信用直接设为输入框中的值。
func set_credit_from_selector() -> void:
	set_credit(int(credit_selector.value))


# 将政治信用设为指定值，并同步控制台状态。
func set_credit(value: int) -> void:
	WorkdayState.political_credit = clampi(value, -9999, 9999)
	credit_selector.value = WorkdayState.political_credit
	append_output("Credit 已设置为 %d" % WorkdayState.political_credit)
	refresh_status()


# 在现有政治信用基础上增减指定数值。
func adjust_credit(delta: int) -> void:
	set_credit(WorkdayState.political_credit + delta)


# 启动选中的关卡，成功后切换到主工作台场景。
func _on_start_level() -> void:
	if level_selector.item_count == 0:
		append_output("没有可用关卡。")
		return
	var level_id := WorkdayContext.stringify_value(level_selector.get_item_metadata(level_selector.selected))
	var seed := int(seed_selector.value)
	if LevelDirector.start_level(level_id, seed):
		append_output("已启动关卡：%s / 种子 %d" % [level_id, seed])
		switch_scene(MAIN_SCENE)
	else:
		append_output("关卡启动失败：" + "；".join(LevelDirector.runtime_errors))


# 重载 CSV 配置并刷新关卡选择器与状态显示。
func _on_reload_config() -> void:
	if LevelDirector.reload_configs():
		append_output("CSV 配置已重载。")
		refresh_status()
	else:
		append_output("配置重载失败：" + "；".join(ConfigDatabase.errors))


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
	var samples: Array[Dictionary] = [
		{"department": "第十二区居住配置处", "code": "R-12/住房用途变更申请", "applicant": "林默，公民序号 74-119-02", "request": "共同居住配额"},
		{"department": "公共供给连续性办公室", "code": "W-08/饮水额度临时调整", "applicant": "周循，公民序号 20-441-88", "request": "净水领取额度"},
		{"department": "中央医疗秩序协调科", "code": "M-31/非计划医疗通行申请", "applicant": "许桥，公民序号 51-004-63", "request": "限制时段医疗通行"}
	]
	for i in samples.size():
		var decision := "批准"
		if mode == "rejected" or (mode == "mixed" and i == 1):
			decision = "驳回"
			WorkdayState.manager.record_case_result(samples[i], decision)
	append_output("已填充测试数据：%s" % mode)
	refresh_status()


# 清空 WorkdayState.records 中所有当日申请记录。
# 操作完成后向输出区打印提示并刷新状态标签。
func clear_records() -> void:
	WorkdayState.records.clear()
	append_output("已清空当日记录。")
	refresh_status()


# 手动进入下一工作日。
# 调用 WorkdayManager 推进工作日，同步更新工作日选择器的显示值，向输出区打印新工作日并刷新状态。
func next_day() -> void:
	WorkdayState.manager.begin_next_day()
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
			append_output("scene menu | scene days | scene opening | scene main | scene report | scene map | scene validation | scene reload")
			append_output("level <id> [seed] | credit set <值> | credit add <增量> | config reload | queue | npc state | npc skip | report fill | day next | state | clear")
			append_output("glass test")
		"scene":
			if parts.size() < 2:
				append_output("用法：scene menu|days|opening|main|report|map|validation|reload")
			else:
				match parts[1].to_lower():
					"menu":
						switch_scene(MENU_SCENE)
					"days":
						switch_scene(WORKDAY_SELECTOR_SCENE)
					"opening":
						switch_scene(OPENING_SCENE)
					"main":
						switch_scene(MAIN_SCENE)
					"report":
						switch_scene(REPORT_SCENE)
					"map":
						switch_scene(EVENING_MAP_SCENE)
					"validation":
						switch_scene(VALIDATION_SCENE)
					"reload":
						reload_scene()
					_:
						append_output("未知场景：" + parts[1])
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
		"credit":
			if parts.size() < 3 or not parts[2].is_valid_int():
				append_output("用法：credit set <值> | credit add <增量>")
			elif parts[1].to_lower() == "set":
				set_credit(int(parts[2]))
			elif parts[1].to_lower() == "add":
				adjust_credit(int(parts[2]))
			else:
				append_output("用法：credit set <值> | credit add <增量>")
		"level":
			if parts.size() < 2:
				append_output("用法：level <level_id> [seed]")
			else:
				var seed := int(parts[2]) if parts.size() > 2 else -1
				if LevelDirector.start_level(parts[1], seed):
					append_output("已启动关卡：%s / 种子 %d" % [parts[1], seed])
				else:
					append_output("关卡启动失败：" + "；".join(LevelDirector.runtime_errors))
		"config":
			if parts.size() > 1 and parts[1].to_lower() == "reload":
				_on_reload_config()
			else:
				append_output("用法：config reload")
		"queue":
			append_output(JSON.stringify(LevelDirector.get_state_summary()))
		"npc":
			var scene := get_tree().current_scene
			var manager_value: Variant = scene.get("manager") if scene != null else null
			var performance: WorkbenchNpcPerformanceModule
			if manager_value is WorkbenchManager:
				var manager: WorkbenchManager = manager_value
				performance = manager.npc_performance
			if performance == null:
				append_output("当前场景没有 NPC 演出控制器。")
			elif parts.size() > 1 and parts[1].to_lower() == "skip":
				performance.skip_current_performance()
				append_output("已跳过当前 NPC 演出阶段。")
			elif parts.size() > 1 and parts[1].to_lower() == "state":
				append_output("NPC 状态：" + performance.state)
			else:
				append_output("用法：npc state | npc skip")
		"glass":
			if parts.size() > 1:
				send_glass_event(parts[1].to_lower())
			else:
				append_output("用法：glass test|briefing|npc|receipt|report|consequence|broadcast")
		"state":
			refresh_status()
			append_output(status_label.text.replace("\n", " | "))
		"clear":
			output.clear()
		_:
			append_output("未知命令：%s；输入 help 查看帮助。" % parts[0])


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
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event
	if not key_event.pressed:
		return
	if key_event.keycode == KEY_UP and not command_history.is_empty():
		history_index = maxi(0, history_index - 1)
		command_input.text = command_history[history_index]
		command_input.caret_column = command_input.text.length()
	elif key_event.keycode == KEY_DOWN and not command_history.is_empty():
		history_index = mini(command_history.size(), history_index + 1)
		command_input.text = "" if history_index == command_history.size() else command_history[history_index]
		command_input.caret_column = command_input.text.length()


# 填充混合裁决的开发测试记录。
func _fill_mixed_test_records() -> void:
	fill_test_records("mixed")
