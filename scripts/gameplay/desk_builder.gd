class_name DeskBuilder
extends RefCounted

# 构建主工作台场景的静态视觉部分。
# 不负责印章、表单、文件袋等动态案件节点；只创建背景、申请人卡、验收槽、状态栏、队列与转场层。

const WORKBENCH_TEXTURE := preload("res://assets/opening/opening-03-day-one-reveal-8bit-v1.png")
const VALIDATION_TEXTURE := preload("res://assets/day1_8bit/interactive/validation_machine.png")


# 在指定 root 节点下构建工作台，并返回共享的 DeskNodes 引用容器。
func build(root: Node2D) -> DeskNodes:
	var desk := DeskNodes.new()

	var backdrop := TextureRect.new()
	backdrop.name = "ClerkDeskConcept"
	backdrop.texture = WORKBENCH_TEXTURE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	# TextureRect 在未进入场景树时会保留纹理原始最小尺寸。
	# 加入父节点后再固定到设计画布，避免 1672×941 原图越过 1280×720 边界。
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(1280, 720)

	var vignette := ColorRect.new()
	vignette.name = "InteractionContrast"
	vignette.color = Color(0.04, 0.045, 0.04, 0.18)
	vignette.position = Vector2.ZERO
	vignette.size = Vector2(1280, 720)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)

	var case_card := Panel.new()
	case_card.name = "ApplicantCard"
	case_card.position = Vector2(1010, 350)
	case_card.size = Vector2(235, 112)
	case_card.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color(0.08, 0.075, 0.06, 0.94), 4, WorkbenchUI.COLORS.brass, 2)
	)
	root.add_child(case_card)
	WorkbenchUI.add_text(case_card, "当前申请人档案", 12, Color("b9aa88"), Vector2(14, 10), Vector2(200, 20))
	desk.applicant_card_label = WorkbenchUI.add_text(
		case_card, "", 14, Color("ddd0ac"), Vector2(14, 35), Vector2(207, 67)
	)

	desk.slot = Panel.new()
	desk.slot.name = "RealityValidationSlot"
	desk.slot.position = Vector2(1010, 475)
	desk.slot.size = Vector2(235, 92)
	desk.slot.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color(0.035, 0.035, 0.03, 0.96), 5, WorkbenchUI.COLORS.brass, 3)
	)
	root.add_child(desk.slot)
	WorkbenchUI.add_text(desk.slot, "送交中央现实验收", 15, Color("d0c09b"), Vector2(16, 11), Vector2(190, 22))
	var opening := ColorRect.new()
	opening.color = Color("030303")
	opening.position = Vector2(16, 47)
	opening.size = Vector2(202, 20)
	opening.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.slot.add_child(opening)
	desk.slot_light = ColorRect.new()
	desk.slot_light.color = WorkbenchUI.COLORS.red
	desk.slot_light.position = Vector2(207, 13)
	desk.slot_light.size = Vector2(10, 10)
	desk.slot_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.slot.add_child(desk.slot_light)

	var status_back := Panel.new()
	status_back.position = Vector2(370, 680)
	status_back.size = Vector2(540, 34)
	status_back.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color(0.04, 0.035, 0.025, 0.92), 4, WorkbenchUI.COLORS.brass, 1)
	)
	root.add_child(status_back)
	desk.status_label = WorkbenchUI.add_text(
		status_back, "请完成申请的形式处理。", 14, Color("d8c9a9"), Vector2(14, 6), Vector2(510, 22)
	)
	desk.status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var clerk_name := WorkdayState.player_name if not WorkdayState.player_name.is_empty() else "未登记职员"
	var identity_label := WorkbenchUI.add_text(
		root,
		"经办员：%s  /  第 %02d 工作日" % [clerk_name, WorkdayState.day_number],
		14,
		Color("d8c9a9"),
		Vector2(36, 28),
		Vector2(520, 28)
	)
	identity_label.add_theme_constant_override("outline_size", 5)
	identity_label.add_theme_color_override("font_outline_color", Color("11130f"))
	desk.need_status_label = WorkbenchUI.add_text(
		root,
		"生活状态：饮水正常",
		13,
		Color("aabd78"),
		Vector2(36, 56),
		Vector2(420, 24)
	)
	desk.need_status_label.add_theme_constant_override("outline_size", 4)
	desk.need_status_label.add_theme_color_override("font_outline_color", Color("11130f"))

	_build_machine_ingestion_zone(root, desk)
	_build_queue_display(root, desk)
	_build_validation_overlay(root, desk)

	return desk


func _build_machine_ingestion_zone(root: Node2D, desk: DeskNodes) -> void:
	desk.machine_drop_zone = Control.new()
	desk.machine_drop_zone.name = "MachineDropZone"
	desk.machine_drop_zone.position = Vector2(485, 205)
	desk.machine_drop_zone.size = Vector2(310, 285)
	desk.machine_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _build_queue_display(root: Node2D, desk: DeskNodes) -> void:
	desk.npc_panel = Panel.new()
	desk.npc_panel.name = "NpcWindow"
	desk.npc_panel.position = Vector2(36, 80)
	desk.npc_panel.size = Vector2(260, 170)
	desk.npc_panel.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color(0.055, 0.07, 0.06, 0.94), 4, WorkbenchUI.COLORS.brass, 2)
	)
	root.add_child(desk.npc_panel)
	WorkbenchUI.add_text(
		desk.npc_panel, "办事窗口 / 当前来访者", 14, Color("b9aa88"), Vector2(14, 10), Vector2(230, 24)
	)
	desk.queue_label = WorkbenchUI.add_text(
		desk.npc_panel, "队列准备中", 16, Color("ddd0ac"), Vector2(14, 45), Vector2(230, 100)
	)
	desk.timer_label = WorkbenchUI.add_text(
		root, "剩余 03:00", 18, Color("ddd0ac"), Vector2(1040, 28), Vector2(190, 28)
	)
	desk.timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_validation_overlay(root: Node2D, desk: DeskNodes) -> void:
	desk.validation_overlay = Control.new()
	desk.validation_overlay.name = "ValidationTransition"
	desk.validation_overlay.position = Vector2.ZERO
	desk.validation_overlay.size = Vector2(1280, 720)
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
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.validation_overlay.add_child(shade)

	var receipt := WorkbenchUI.add_text(
		desk.validation_overlay,
		"现实效力请求已进入设施队列",
		24,
		Color("e1d3b0"),
		Vector2(370, 646),
		Vector2(540, 42)
	)
	receipt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	receipt.add_theme_constant_override("outline_size", 6)
	receipt.add_theme_color_override("font_outline_color", Color("16120e"))
