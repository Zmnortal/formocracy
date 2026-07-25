class_name DeskBuilder
extends RefCounted

# 构建主工作台场景的静态视觉部分。
# 底景只负责空间结构；办公室设施与交互物保持为独立节点，避免把玩法状态绘死在背景里。

const WORKBENCH_TEXTURE := preload("res://assets/office/background/service_hall_light.png")
const VALIDATION_TEXTURE := preload("res://assets/day1_8bit/interactive/validation_machine.png")
const FILING_CABINET_CLOSED_TEXTURE := preload("res://assets/office/filing_cabinet/states/00_closed.png")
const CALENDAR_TEXTURE := preload("res://assets/office/items/calendar.png")
const WALL_CLOCK_TEXTURE := preload("res://assets/office/world_props/wall_clock.png")
const CLERK_TOOL_CABINET_TEXTURE := preload("res://assets/office/world_props/clerk_tool_cabinet.png")
const SERVICE_WINDOW_TEXTURE := preload("res://assets/office/service_window/service_counter_pass_through.png")
const WORKTABLE_TEXTURE := preload("res://assets/office/foreground/worktable.png")
const NPC_EXIT_OCCLUDER_TEXTURE := preload("res://assets/office/foreground/npc_exit_occluder.tres")
const ARCHIVE_TRAY_TEXTURE := preload("res://assets/office/interactive/archive_tray.png")
const ARCHIVE_TRAY_FOREGROUND_TEXTURE := preload("res://assets/office/interactive/archive_tray_foreground.png")
const DESK_DEFORMATION_SHADER := preload("res://shaders/desk_deformation.gdshader")
const FILING_CABINET_SCALE := 1.8


# 在指定 root 节点下构建工作台，并返回共享的 DeskNodes 引用容器。
func build(root: Node2D) -> DeskNodes:
	var desk := DeskNodes.new()

	var backdrop := TextureRect.new()
	backdrop.name = "ClerkDeskConcept"
	backdrop.texture = WORKBENCH_TEXTURE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -100
	root.add_child(backdrop)
	# TextureRect 在未进入场景树时会保留纹理原始最小尺寸。
	# 加入父节点后再固定到设计画布，避免 1672×941 原图越过 1280×720 边界。
	backdrop.position = Vector2.ZERO
	backdrop.size = DeskGeometry.design_size()

	var vignette := ColorRect.new()
	vignette.name = "InteractionContrast"
	vignette.color = Color(0.025, 0.03, 0.025, 0.08)
	vignette.position = Vector2.ZERO
	vignette.size = DeskGeometry.design_size()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_index = -90
	root.add_child(vignette)

	_build_office_props(root, desk)
	_build_foreground_architecture(root)

	desk.slot = Panel.new()
	desk.slot.name = "RealityValidationSlot"
	desk.slot.position = Vector2(1040, 548)
	desk.slot.size = Vector2(198, 102)
	desk.slot.pivot_offset = desk.slot.size / 2.0
	desk.slot.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color(0, 0, 0, 0), 0))
	desk.slot.z_index = 46
	root.add_child(desk.slot)
	var archive_image := TextureRect.new()
	archive_image.name = "ArchiveTrayAsset"
	archive_image.texture = ARCHIVE_TRAY_TEXTURE
	archive_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	archive_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	archive_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	archive_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.slot.add_child(archive_image)
	archive_image.position = Vector2.ZERO
	archive_image.size = desk.slot.size
	desk.archive_stack = Control.new()
	desk.archive_stack.name = "ArchivedEnvelopeStack"
	# 只在托盘内腔显示文件袋，避免袋子覆盖金属前挡板。
	desk.archive_stack.position = Vector2(20, 31)
	desk.archive_stack.size = Vector2(158, 31)
	desk.archive_stack.clip_contents = true
	desk.archive_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.slot.add_child(desk.archive_stack)
	var archive_foreground := TextureRect.new()
	archive_foreground.name = "ArchiveTrayForeground"
	archive_foreground.texture = ARCHIVE_TRAY_FOREGROUND_TEXTURE
	archive_foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	archive_foreground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	archive_foreground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	archive_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	archive_foreground.position = Vector2.ZERO
	archive_foreground.size = desk.slot.size
	desk.slot.add_child(archive_foreground)
	desk.archive_count_label = WorkbenchUI.add_text(desk.slot, "", 11, Color("ead8ad"), Vector2(145, 16), Vector2(42, 20))
	desk.archive_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desk.archive_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.archive_count_label.add_theme_constant_override("outline_size", 3)
	desk.archive_count_label.add_theme_color_override("font_outline_color", Color("31291f"))
	var archive_label := WorkbenchUI.add_text(desk.slot, "当日归档", 12, Color("d0c09b"), Vector2(61, -18), Vector2(90, 20))
	archive_label.name = "ArchiveTitleLabel"
	archive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	archive_label.z_index = 1
	archive_label.add_theme_constant_override("outline_size", 3)
	archive_label.add_theme_color_override("font_outline_color", Color("31291f"))
	# 只去掉旧版 HUD 标题；归档盒、文件堆与投放交互必须保持可见可用。
	archive_label.visible = false
	desk.slot_light = ColorRect.new()
	desk.slot_light.color = WorkbenchUI.COLORS.red
	desk.slot_light.position = Vector2(166, 76)
	desk.slot_light.size = Vector2(10, 7)
	desk.slot_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.slot.add_child(desk.slot_light)
	desk.archive_drop_zone = desk.slot
	desk.archive_drop_zone.add_to_group("debug_interaction_zone")
	desk.archive_drop_zone.set_meta("debug_zone_label", "归档投放区")
	desk.refresh_archive_stack()

	var desk_surface_zone := Control.new()
	desk_surface_zone.name = "DeskBounds"
	desk_surface_zone.position = Vector2(DeskGeometry.BOUNDS_LEFT, DeskGeometry.BOUNDS_TOP)
	desk_surface_zone.size = DeskGeometry.bounds_size()
	desk_surface_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk_surface_zone.add_to_group("debug_interaction_zone")
	desk_surface_zone.set_meta("debug_zone_label", "桌面回弹范围 / DeskBounds")
	root.add_child(desk_surface_zone)

	var status_back := Panel.new()
	status_back.name = "WorkbenchHintPanel"
	status_back.position = Vector2(300, 681)
	status_back.size = Vector2(390, 31)
	status_back.z_index = 60
	status_back.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color(0.04, 0.035, 0.025, 0.92), 4, WorkbenchUI.COLORS.brass, 1))
	# 主玩法用物件与演出表达当前操作，不再常驻显示底部文字提示框。
	status_back.visible = false
	root.add_child(status_back)
	desk.status_label = WorkbenchUI.add_text(status_back, "请完成申请的形式处理。", 13, Color("d8c9a9"), Vector2(12, 5), Vector2(366, 21))
	desk.status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var clerk_name := WorkdayState.player_name if not WorkdayState.player_name.is_empty() else "未登记职员"
	var identity_label := WorkbenchUI.add_text(root, "经办员：%s  /  第 %02d 工作日" % [clerk_name, WorkdayState.day_number], 14, Color("d8c9a9"), Vector2(24, 18), Vector2(520, 28))
	identity_label.name = "ClerkStatusLabel"
	identity_label.add_theme_constant_override("outline_size", 5)
	identity_label.add_theme_color_override("font_outline_color", Color("11130f"))
	identity_label.visible = false
	desk.need_status_label = WorkbenchUI.add_text(root, "生活状态：饮水正常", 13, Color("aabd78"), Vector2(24, 45), Vector2(420, 24))
	desk.need_status_label.name = "NeedStatusLabel"
	desk.need_status_label.add_theme_constant_override("outline_size", 4)
	desk.need_status_label.add_theme_color_override("font_outline_color", Color("11130f"))
	desk.need_status_label.visible = false

	_build_machine_ingestion_zone(root, desk)
	_build_queue_display(root, desk)
	_build_validation_overlay(root, desk)

	return desk


# 摆放文件柜、可交互挂历与墙钟等办公室陈设。
func _build_office_props(root: Node2D, desk: DeskNodes) -> void:
	_build_filing_cabinet(root, desk)
	desk.wall_calendar = _add_prop(root, "WallCalendar", CALENDAR_TEXTURE, Vector2(1062, 74), Vector2(220, 146), -3)
	desk.wall_calendar.mouse_filter = Control.MOUSE_FILTER_PASS
	# 左侧退场遮挡层位于 NPC 前方；墙钟是独立墙面陈设，必须再位于遮挡层前方。
	_add_prop(root, "InstitutionalWallClock", WALL_CLOCK_TEXTURE, Vector2(62, 74), Vector2(126, 126), 5)
	_add_prop(root, "ClerkToolCabinet", CLERK_TOOL_CABINET_TEXTURE, Vector2(1018, 254), Vector2(293, 366), 5)


# 使用独立柜体贴图与上下抽屉热区构建左侧文件柜。
# 512×640 素材四周保留透明安全区，因此绘制矩形会越过画布左边；
# 实际非透明柜体贴住画布左缘，并放在前景桌面上方。
# 1.8 倍显示时按素材的非透明边界贴住左墙。
func _build_filing_cabinet(root: Node2D, desk: DeskNodes) -> void:
	desk.filing_cabinet = _add_prop(
		root,
		"FilingCabinet",
		FILING_CABINET_CLOSED_TEXTURE,
		Vector2(-84, 179),
		Vector2(220, 256),
		8,
	)
	desk.filing_cabinet.scale = Vector2.ONE * FILING_CABINET_SCALE

	desk.filing_cabinet_upper_hit = Button.new()
	desk.filing_cabinet_upper_hit.name = "UpperDrawerHit"
	desk.filing_cabinet_upper_hit.position = Vector2(40, 79)
	desk.filing_cabinet_upper_hit.size = Vector2(140, 82)
	desk.filing_cabinet_upper_hit.flat = true
	desk.filing_cabinet_upper_hit.focus_mode = Control.FOCUS_NONE
	desk.filing_cabinet_upper_hit.tooltip_text = "打开上层：局务参考手册"
	desk.filing_cabinet_upper_hit.add_to_group("debug_interaction_zone")
	desk.filing_cabinet_upper_hit.set_meta("debug_zone_label", "文件柜上层 / 参考手册")
	desk.filing_cabinet.add_child(desk.filing_cabinet_upper_hit)

	desk.filing_cabinet_lower_hit = Button.new()
	desk.filing_cabinet_lower_hit.name = "LowerDrawerHit"
	desk.filing_cabinet_lower_hit.position = Vector2(40, 159)
	desk.filing_cabinet_lower_hit.size = Vector2(140, 92)
	desk.filing_cabinet_lower_hit.flat = true
	desk.filing_cabinet_lower_hit.focus_mode = Control.FOCUS_NONE
	desk.filing_cabinet_lower_hit.tooltip_text = "打开下层：私人证物"
	desk.filing_cabinet_lower_hit.add_to_group("debug_interaction_zone")
	desk.filing_cabinet_lower_hit.set_meta("debug_zone_label", "文件柜下层 / 私人证物")
	desk.filing_cabinet.add_child(desk.filing_cabinet_lower_hit)


# 构建封闭式服务窗口与带梯形形变 Shader 的前景桌面。
func _build_foreground_architecture(root: Node2D) -> void:
	# 背景图把左墙和立柱烘焙在同一层。复用背景左侧原始像素作为独立前景裁片，
	# 让向左退场的完整人物自然走到墙柱后方，同时避免重新绘制产生色差或接缝。
	_add_prop(root, "NpcExitForegroundOccluder", NPC_EXIT_OCCLUDER_TEXTURE, Vector2.ZERO, Vector2(370, 720), 3)
	var glass := ColorRect.new()
	glass.name = "ServiceWindowGlass"
	glass.position = Vector2(350, 150)
	glass.size = Vector2(580, 295)
	glass.color = Color(0.19, 0.24, 0.22, 0.055)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.z_index = 3
	root.add_child(glass)
	_add_prop(root, "ServiceWindowForeground", SERVICE_WINDOW_TEXTURE, Vector2(320, 465), Vector2(640, 120), 3)
	var worktable := _add_prop(root, "WorktableForeground", WORKTABLE_TEXTURE, Vector2(DeskGeometry.visual_left(), DeskGeometry.TOP), DeskGeometry.visual_size(), 4)
	# 负 inset 只扩大桌面图片的绘制矩形，再由 Shader 在矩形内部生成梯形。
	# DeskBounds 使用上方独立的一组 BOUNDS_* 参数，不跟随图片形变。
	worktable.stretch_mode = TextureRect.STRETCH_SCALE
	var deformation := ShaderMaterial.new()
	deformation.shader = DESK_DEFORMATION_SHADER
	deformation.set_shader_parameter("top_inset", DeskGeometry.inset_ratio(DeskGeometry.TOP_INSET))
	deformation.set_shader_parameter("bottom_inset", DeskGeometry.inset_ratio(DeskGeometry.BOTTOM_INSET))
	deformation.set_shader_parameter("vertical_bend", DeskGeometry.VERTICAL_BEND)
	worktable.material = deformation


# 创建一个不拦截鼠标的静态陈设贴图并加入场景。
func _add_prop(root: Node2D, node_name: String, texture: Texture2D, at: Vector2, display_size: Vector2, layer: int) -> TextureRect:
	var prop := TextureRect.new()
	prop.name = node_name
	prop.texture = texture
	prop.position = at
	prop.size = display_size
	prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prop.z_index = layer
	root.add_child(prop)
	# TextureRect 在尚未进入场景树时会保留纹理的原始最小尺寸。
	# 加入父节点后再设置设计尺寸，确保大图素材不会撑破指定布局。
	prop.position = at
	prop.size = display_size
	return prop


# 构建机器吞入判定区与传送口前景遮罩。
func _build_machine_ingestion_zone(root: Node2D, desk: DeskNodes) -> void:
	desk.machine_drop_zone = Control.new()
	desk.machine_drop_zone.name = "MachineDropZone"
	desk.machine_drop_zone.position = Vector2(485, 205)
	desk.machine_drop_zone.size = Vector2(310, 285)
	desk.machine_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.machine_drop_zone.add_to_group("debug_interaction_zone")
	desk.machine_drop_zone.set_meta("debug_zone_label", "机器吞入区")
	root.add_child(desk.machine_drop_zone)

	# 覆盖传送口前沿。文件袋在吞入阶段降到该层之后，
	# 会逐步被这块前景遮住，形成进入机器内部的效果。
	desk.machine_mouth_mask = ColorRect.new()
	desk.machine_mouth_mask.name = "MachineMouthForeground"
	desk.machine_mouth_mask.position = Vector2(565, 350)
	desk.machine_mouth_mask.size = Vector2(150, 44)
	desk.machine_mouth_mask.color = Color(0.018, 0.022, 0.019, 0.88)
	desk.machine_mouth_mask.z_index = 45
	desk.machine_mouth_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.machine_mouth_mask.visible = false
	root.add_child(desk.machine_mouth_mask)


# 保留工作时限节点供流程内部更新，但不再把倒计时作为常驻 HUD 显示。
func _build_queue_display(root: Node2D, desk: DeskNodes) -> void:
	desk.timer_label = WorkbenchUI.add_text(root, "剩余 03:00", 18, Color("ddd0ac"), Vector2(1040, 28), Vector2(190, 28))
	desk.timer_label.name = "RemainingTimeLabel"
	desk.timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desk.timer_label.visible = false


# 构建提交后的验收过渡遮罩与提示文字。
func _build_validation_overlay(root: Node2D, desk: DeskNodes) -> void:
	desk.validation_overlay = Control.new()
	desk.validation_overlay.name = "ValidationTransition"
	desk.validation_overlay.position = Vector2.ZERO
	desk.validation_overlay.size = DeskGeometry.design_size()
	desk.validation_overlay.z_index = 100
	desk.validation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	desk.validation_overlay.visible = false
	root.add_child(desk.validation_overlay)

	desk.validation_image = TextureRect.new()
	desk.validation_image.texture = VALIDATION_TEXTURE
	desk.validation_image.position = Vector2(425, 95)
	desk.validation_image.size = Vector2(430, 470)
	desk.validation_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	desk.validation_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	desk.validation_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.validation_overlay.add_child(desk.validation_image)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.2)
	shade.size = DeskGeometry.design_size()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.validation_overlay.add_child(shade)

	var receipt := WorkbenchUI.add_text(desk.validation_overlay, "现实效力请求已进入设施队列", 24, Color("e1d3b0"), Vector2(370, 646), Vector2(540, 42))
	receipt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	receipt.add_theme_constant_override("outline_size", 6)
	receipt.add_theme_color_override("font_outline_color", Color("16120e"))
