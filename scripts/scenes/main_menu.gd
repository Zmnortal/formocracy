extends Control

const WORKDAY_SELECTOR_SCENE := "res://scenes/workday_selector.tscn"
const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const DOCUMENT_VISUAL_SCALE := 1.5
const TYPOGRAPHY_SCALE := 1.5
const EXIT_SCATTER_DURATION := 0.78
const EXIT_BLACK_HOLD_SECONDS := 0.5

const DOCUMENTS: Array[Dictionary] = [
	{
		"path": "res://assets/menu/document_collage/final/02_approval_register.png",
		"corner": "top_left",
		"offset": Vector2(130, 55),
		"size": Vector2(315, 205),
		"rotation": -11.0,
		"z": 1,
		"delay": 0.02,
		"phase": 0.3
	},
	{
		"path": "res://assets/menu/document_collage/final/10_staff_transfer.png",
		"corner": "top_left",
		"offset": Vector2(190, 115),
		"size": Vector2(330, 238),
		"rotation": 8.0,
		"z": 2,
		"delay": 0.07,
		"phase": 1.2
	},
	{
		"path": "res://assets/menu/document_collage/final/14_staff_id.png",
		"corner": "top_left",
		"offset": Vector2(84, 240),
		"size": Vector2(235, 160),
		"rotation": -16.0,
		"z": 3,
		"delay": 0.12,
		"phase": 2.1
	},
	{
		"path": "res://assets/menu/document_collage/final/01_workday_report.png",
		"corner": "top_left",
		"offset": Vector2(235, 190),
		"size": Vector2(270, 375),
		"rotation": -3.5,
		"z": 4,
		"delay": 0.18,
		"phase": 2.8
	},
	{
		"path": "res://assets/menu/document_collage/final/12_archive_access.png",
		"corner": "top_right",
		"offset": Vector2(-135, 65),
		"size": Vector2(320, 258),
		"rotation": 12.0,
		"z": 1,
		"delay": 0.04,
		"phase": 0.8
	},
	{
		"path": "res://assets/menu/document_collage/final/16_stamps_sheet.png",
		"corner": "top_right",
		"offset": Vector2(-275, 92),
		"size": Vector2(215, 141),
		"rotation": -9.0,
		"z": 3,
		"delay": 0.10,
		"phase": 1.7
	},
	{
		"path": "res://assets/menu/document_collage/final/13_application_receipt.png",
		"corner": "top_right",
		"offset": Vector2(-75, 245),
		"size": Vector2(220, 180),
		"rotation": 14.0,
		"z": 2,
		"delay": 0.14,
		"phase": 2.4
	},
	{
		"path": "res://assets/menu/document_collage/final/09_government_report.png",
		"corner": "top_right",
		"offset": Vector2(-185, 205),
		"size": Vector2(238, 352),
		"rotation": 3.0,
		"z": 4,
		"delay": 0.20,
		"phase": 3.2
	},
	{
		"path": "res://assets/menu/document_collage/final/07_passage_permit.png",
		"corner": "bottom_left",
		"offset": Vector2(95, -72),
		"size": Vector2(330, 264),
		"rotation": 10.0,
		"z": 1,
		"delay": 0.05,
		"phase": 0.5
	},
	{
		"path": "res://assets/menu/document_collage/final/06_water_quota.png",
		"corner": "bottom_left",
		"offset": Vector2(70, -220),
		"size": Vector2(238, 348),
		"rotation": -13.0,
		"z": 2,
		"delay": 0.11,
		"phase": 1.4
	},
	{
		"path": "res://assets/menu/document_collage/final/08_lost_property.png",
		"corner": "bottom_left",
		"offset": Vector2(265, -125),
		"size": Vector2(220, 338),
		"rotation": 15.0,
		"z": 3,
		"delay": 0.16,
		"phase": 2.0
	},
	{
		"path": "res://assets/menu/document_collage/final/05_housing_change.png",
		"corner": "bottom_left",
		"offset": Vector2(190, -175),
		"size": Vector2(255, 365),
		"rotation": -2.5,
		"z": 4,
		"delay": 0.22,
		"phase": 2.9
	},
	{
		"path": "res://assets/menu/document_collage/final/11_confidential_circulation.png",
		"corner": "bottom_right",
		"offset": Vector2(-90, -188),
		"size": Vector2(245, 348),
		"rotation": -13.0,
		"z": 1,
		"delay": 0.06,
		"phase": 0.1
	},
	{
		"path": "res://assets/menu/document_collage/final/04_penalty_notice.png",
		"corner": "bottom_right",
		"offset": Vector2(-270, -100),
		"size": Vector2(224, 360),
		"rotation": 12.0,
		"z": 2,
		"delay": 0.12,
		"phase": 1.1
	},
	{
		"path": "res://assets/menu/document_collage/final/15_reality_seal.png",
		"corner": "bottom_right",
		"offset": Vector2(-310, -280),
		"size": Vector2(170, 178),
		"rotation": -18.0,
		"z": 4,
		"delay": 0.17,
		"phase": 2.2
	},
	{
		"path": "res://assets/menu/document_collage/final/03_reality_validation.png",
		"corner": "bottom_right",
		"offset": Vector2(-170, -185),
		"size": Vector2(255, 344),
		"rotation": 3.5,
		"z": 3,
		"delay": 0.23,
		"phase": 3.0
	},
]

var start_button: Button
var exit_button: Button
var collage_layer: Control
var center_glow: Panel
var center_column: VBoxContainer
var document_nodes: Array[TextureRect] = []
var title_transition_nodes: Array[Control] = []
var action_transition_nodes: Array[Control] = []
var animation_time := 0.0
var collage_scale := 1.0
var entrance_complete := false
var transitioning := false
var transition_phase := "idle"


# 主菜单就绪时播放开场音乐、构建界面、布局文件拼贴并播放入场动画。
func _ready() -> void:
	# 场景切换的无内容帧也必须使用黑色清屏，杜绝记录页出现单帧白闪。
	RenderingServer.set_default_clear_color(Color.BLACK)
	OpeningMusic.play_opening()
	build_scene()
	get_viewport().size_changed.connect(layout_documents)
	await get_tree().process_frame
	layout_documents()
	animate_documents_in()
	start_button.grab_focus()


# 入场完成后每帧驱动文件的漂浮、鼠标靠近角落时的展开偏移与旋转晃动。
func _process(delta: float) -> void:
	if not entrance_complete or transitioning:
		return
	animation_time += delta
	var viewport_size := get_viewport_rect().size
	var mouse_position := get_viewport().get_mouse_position()
	for i in document_nodes.size():
		var paper: TextureRect = document_nodes[i]
		var config: Dictionary = DOCUMENTS[i]
		var base_position := _meta_vector(paper, "base_position", paper.position)
		var corner_point := get_corner_point(WorkdayContext.read_string(config, "corner"), viewport_size)
		var hover_distance := mouse_position.distance_to(corner_point)
		var hover_amount := clampf(1.0 - hover_distance / (330.0 * collage_scale), 0.0, 1.0)
		var unfold_direction := (paper.position + paper.size * 0.5 - corner_point).normalized()
		var phase := WorkdayContext.read_float(config, "phase")
		var drift := Vector2(sin(animation_time * 0.42 + phase) * 1.2, cos(animation_time * 0.36 + phase) * 1.6) * collage_scale
		var target_position := base_position + drift + unfold_direction * hover_amount * 7.0 * collage_scale
		paper.position = paper.position.lerp(target_position, minf(delta * 5.0, 1.0))
		var rotation_wobble := sin(animation_time * 0.28 + phase) * 0.22
		paper.rotation = lerp_angle(paper.rotation, deg_to_rad(WorkdayContext.read_float(config, "rotation") + rotation_wobble), minf(delta * 3.0, 1.0))


# 以代码构建主菜单：背景、兼容占位图、文件拼贴层、中央面板、标题与按钮。
func build_scene() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color("#070c0d")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# 保留透明的兼容节点，旧测试和调试脚本仍可定位 TitleArtwork，
	# 但主菜单不再依赖一张静态整图。
	var artwork := TextureRect.new()
	artwork.name = "TitleArtwork"
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(artwork)

	collage_layer = Control.new()
	collage_layer.name = "DocumentCollage"
	collage_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	collage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(collage_layer)
	build_documents()

	center_glow = Panel.new()
	center_glow.name = "CentralField"
	center_glow.set_anchors_preset(Control.PRESET_CENTER)
	center_glow.position = Vector2(-410, -360)
	center_glow.size = Vector2(820, 720)
	center_glow.z_index = 10
	center_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center_style := StyleBoxFlat.new()
	center_style.bg_color = Color(0.015, 0.025, 0.027, 0.72)
	center_style.border_color = Color(0.23, 0.28, 0.25, 0.22)
	center_style.set_border_width_all(1)
	center_style.corner_radius_top_left = 8
	center_style.corner_radius_top_right = 8
	center_style.corner_radius_bottom_left = 8
	center_style.corner_radius_bottom_right = 8
	center_style.shadow_color = Color(0, 0, 0, 0.5)
	center_style.shadow_size = 24
	center_glow.add_theme_stylebox_override("panel", center_style)
	add_child(center_glow)

	center_column = VBoxContainer.new()
	center_column.name = "CentralMenu"
	center_column.set_anchors_preset(Control.PRESET_CENTER)
	center_column.position = Vector2(-560, -360)
	center_column.size = Vector2(1120, 620)
	center_column.z_index = 11
	center_column.alignment = BoxContainer.ALIGNMENT_CENTER
	center_column.add_theme_constant_override("separation", 8)
	add_child(center_column)

	var title := make_label("FORMOCRACY", 72, Color("#f0efe5"))
	title.name = "EnglishTitle"
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color("#070b0c"))
	center_column.add_child(title)
	title_transition_nodes.append(title)
	var chinese_title := make_label("表面政治", 42, Color("#e4dec9"))
	chinese_title.name = "ChineseTitle"
	center_column.add_child(chinese_title)
	title_transition_nodes.append(chinese_title)
	var rule := HSeparator.new()
	rule.name = "TitleRule"
	rule.custom_minimum_size = Vector2(0, 18)
	rule.modulate = Color("#777765")
	center_column.add_child(rule)
	title_transition_nodes.append(rule)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	center_column.add_child(spacer)

	start_button = make_button("游戏开始")
	start_button.name = "StartButton"
	start_button.pressed.connect(on_start_pressed)
	center_column.add_child(start_button)
	action_transition_nodes.append(start_button)

	exit_button = make_button("退出游戏")
	exit_button.name = "ExitButton"
	exit_button.pressed.connect(on_exit_pressed)
	center_column.add_child(exit_button)
	action_transition_nodes.append(exit_button)


# 按 DOCUMENTS 配置创建全部文件贴图节点并加入拼贴层，初始透明。
func build_documents() -> void:
	for config: Dictionary in DOCUMENTS:
		var paper := TextureRect.new()
		var texture_path := WorkdayContext.read_string(config, "path")
		paper.name = texture_path.get_file().get_basename().to_pascal_case()
		paper.texture = load(texture_path) as Texture2D
		paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		paper.z_index = WorkdayContext.read_int(config, "z")
		paper.rotation = deg_to_rad(WorkdayContext.read_float(config, "rotation"))
		paper.modulate.a = 0.0
		collage_layer.add_child(paper)
		document_nodes.append(paper)


# 按视口尺寸计算拼贴缩放，同步中央面板缩放并重算每张文件的基准位置。
func layout_documents() -> void:
	if transitioning:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	collage_scale = clampf(minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y), 0.72, 1.8)
	# 全屏/Retina 下四角文件会随视口放大，中央 Opening UI 也必须使用同一比例，
	# 否则标题与按钮会像一张没有响应式布局的小卡片缩在屏幕中心。
	var center_scale := collage_scale
	if is_instance_valid(center_glow):
		center_glow.pivot_offset = center_glow.size * 0.5
		center_glow.scale = Vector2.ONE * center_scale
	if is_instance_valid(center_column):
		center_column.pivot_offset = center_column.size * 0.5
		center_column.scale = Vector2.ONE * center_scale
	if document_nodes.is_empty():
		return
	for i in document_nodes.size():
		var paper: TextureRect = document_nodes[i]
		var config: Dictionary = DOCUMENTS[i]
		paper.size = _config_vector(config, "size") * collage_scale * DOCUMENT_VISUAL_SCALE
		paper.pivot_offset = paper.size * 0.5
		var center := get_corner_point(WorkdayContext.read_string(config, "corner"), viewport_size) + _config_vector(config, "offset") * collage_scale
		var base_position := center - paper.size * 0.5
		paper.set_meta("base_position", base_position)
		if entrance_complete:
			paper.position = base_position


# 播放文件入场动画：从屏幕中心向外的偏移位滑回基准位并淡入。
func animate_documents_in() -> void:
	entrance_complete = true
	var viewport_center := get_viewport_rect().size * 0.5
	for i in document_nodes.size():
		var paper: TextureRect = document_nodes[i]
		var config: Dictionary = DOCUMENTS[i]
		var base_position := _meta_vector(paper, "base_position", paper.position)
		var paper_center := base_position + paper.size * 0.5
		var outward := (paper_center - viewport_center).normalized()
		paper.position = base_position + outward * 85.0 * collage_scale
		var tween := create_tween()
		tween.set_parallel(true)
		var delay := WorkdayContext.read_float(config, "delay")
		tween.tween_property(paper, "position", base_position, 0.62).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(paper, "modulate:a", 1.0, 0.34).set_delay(delay)


# 快照辅助：跳过动画，将全部文件直接摆到基准位置、基准角度并完全不透明。
func settle_collage_for_snapshot() -> void:
	entrance_complete = true
	layout_documents()
	for i in document_nodes.size():
		var paper: TextureRect = document_nodes[i]
		var config: Dictionary = DOCUMENTS[i]
		paper.position = _meta_vector(paper, "base_position", paper.position)
		paper.rotation = deg_to_rad(WorkdayContext.read_float(config, "rotation"))
		paper.modulate.a = 1.0


# 返回指定角落名称对应的视口坐标点，默认为左上角。
func get_corner_point(corner: String, viewport_size: Vector2) -> Vector2:
	match corner:
		"top_right":
			return Vector2(viewport_size.x, 0.0)
		"bottom_left":
			return Vector2(0.0, viewport_size.y)
		"bottom_right":
			return viewport_size
		_:
			return Vector2.ZERO


# 创建居中对齐、按排版比例放大字号的像素字体 Label。
func make_label(label_text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", roundi(font_size * TYPOGRAPHY_SCALE))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# 创建带悬停/按下样式与音效的主菜单像素风按钮。
func make_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(570, 114)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", roundi(30 * TYPOGRAPHY_SCALE))
	button.add_theme_color_override("font_color", Color("#ddd8c4"))
	button.add_theme_color_override("font_hover_color", Color("#fff6cf"))
	# 按下时保持深色。亮色 pressed 样式会在点击“游戏开始”的瞬间形成一帧白闪。
	button.add_theme_color_override("font_pressed_color", Color("#fff6cf"))
	button.add_theme_stylebox_override("normal", make_button_style(Color(0.035, 0.055, 0.052, 0.94), Color("#77795d"), 2))
	button.add_theme_stylebox_override("hover", make_button_style(Color(0.09, 0.12, 0.095, 0.98), Color("#c2b36f"), 3))
	button.add_theme_stylebox_override("pressed", make_button_style(Color(0.045, 0.06, 0.05, 0.98), Color("#c2b36f"), 3))
	button.add_theme_stylebox_override("focus", make_button_style(Color(0.06, 0.09, 0.075, 0.98), Color("#d7c578"), 3))
	button.pressed.connect(func() -> void: Sfx.play("ui_click"))
	button.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	return button


# 创建指定背景色、边框色与边框宽度的圆角按钮样式盒。
func make_button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


# 点击开始后播放完整散场、保留短暂黑场，再切换到工作日记录页面。
func on_start_pressed() -> void:
	if transitioning:
		return
	transitioning = true
	transition_phase = "scattering"
	start_button.disabled = true
	exit_button.disabled = true
	await _play_exit_scatter()
	transition_phase = "black_hold"
	collage_layer.visible = false
	center_glow.visible = false
	center_column.visible = false
	await get_tree().create_timer(EXIT_BLACK_HOLD_SECONDS).timeout
	transition_phase = "scene_change"
	change_scene(WORKDAY_SELECTOR_SCENE)


# 让四角表单加速飞出屏幕，同时将标题组向上、按钮组向下送离画面。
func _play_exit_scatter() -> void:
	var viewport_center := get_viewport_rect().size * 0.5
	var viewport_size := get_viewport_rect().size
	var scatter := create_tween()
	scatter.set_parallel(true)

	for i in document_nodes.size():
		var paper: TextureRect = document_nodes[i]
		var config: Dictionary = DOCUMENTS[i]
		var paper_center := paper.position + paper.size * 0.5
		var outward := (paper_center - viewport_center).normalized()
		if outward.is_zero_approx():
			outward = Vector2.UP.rotated(float(i) * TAU / float(document_nodes.size()))
		var tangent := Vector2(-outward.y, outward.x)
		var phase := WorkdayContext.read_float(config, "phase")
		var scatter_direction := (outward + tangent * sin(phase * 1.7) * 0.28).normalized()
		var travel := maxf(viewport_size.x, viewport_size.y) * 0.72 + paper.size.length() * 0.45
		var delay := WorkdayContext.read_float(config, "delay") * 0.55
		var duration := EXIT_SCATTER_DURATION + delay
		var spin_direction := -1.0 if i % 2 == 0 else 1.0
		var spin_degrees := lerpf(28.0, 78.0, absf(sin(phase * 1.3))) * spin_direction
		scatter.tween_property(paper, "position", paper.position + scatter_direction * travel, duration).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		scatter.tween_property(paper, "rotation", paper.rotation + deg_to_rad(spin_degrees), duration).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		scatter.tween_property(paper, "modulate:a", 0.0, 0.28).set_delay(delay + duration * 0.62)

	_detach_center_transition_nodes()
	for node: Control in title_transition_nodes:
		scatter.tween_property(node, "position:y", node.position.y - viewport_size.y * 0.62, EXIT_SCATTER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		scatter.tween_property(node, "modulate:a", 0.0, 0.24).set_delay(EXIT_SCATTER_DURATION * 0.68)
	for node: Control in action_transition_nodes:
		scatter.tween_property(node, "position:y", node.position.y + viewport_size.y * 0.68, EXIT_SCATTER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		scatter.tween_property(node, "modulate:a", 0.0, 0.24).set_delay(EXIT_SCATTER_DURATION * 0.68)
	scatter.tween_property(center_glow, "modulate:a", 0.0, EXIT_SCATTER_DURATION * 0.72)
	await scatter.finished


# 将标题与按钮从 VBoxContainer 中取出并保持屏幕位置，允许两组独立反向飞行。
func _detach_center_transition_nodes() -> void:
	var transition_nodes: Array[Control] = []
	transition_nodes.append_array(title_transition_nodes)
	transition_nodes.append_array(action_transition_nodes)
	var global_positions: Array[Vector2] = []
	var global_scales: Array[Vector2] = []
	for node: Control in transition_nodes:
		global_positions.append(node.global_position)
		global_scales.append(node.get_global_transform().get_scale())
	for i in transition_nodes.size():
		var node: Control = transition_nodes[i]
		node.reparent(self, false)
		node.set_anchors_preset(Control.PRESET_TOP_LEFT)
		node.global_position = global_positions[i]
		node.scale = global_scales[i]
		node.z_index = 12


# 点击退出：Web 平台提示关闭浏览器页面，其余平台直接退出游戏。
func on_exit_pressed() -> void:
	if OS.has_feature("web"):
		exit_button.text = "请关闭浏览器页面"
		exit_button.disabled = true
	else:
		get_tree().quit()


# 切换到指定场景，失败时输出错误日志。
func change_scene(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("场景切换失败：%s / %s" % [path, error_string(error)])


# 按下 ESC 键时等同点击退出按钮。
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			on_exit_pressed()


# 从文件拼贴配置安全读取 Vector2，阻止动态 Dictionary 值扩散到布局逻辑。
func _config_vector(config: Dictionary, key: String, fallback := Vector2.ZERO) -> Vector2:
	var value: Variant = config.get(key, fallback)
	if value is Vector2:
		@warning_ignore("unsafe_cast")
		return value
	return fallback


# 从节点元数据安全读取 Vector2，避免拖动/动画边界依赖无类型 Variant。
func _meta_vector(control: Control, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = control.get_meta(key, fallback)
	if value is Vector2:
		@warning_ignore("unsafe_cast")
		return value
	return fallback
