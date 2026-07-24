class_name DeskNodes
extends RefCounted

# 工作台静态节点引用容器。
# 由 DeskBuilder 创建并填充，供主脚本与各 gameplay 模块共享使用。

const ARCHIVE_ENVELOPE_TEXTURE := preload("res://assets/documents/envelopes/bureau_envelope_desk_side.png")
const FORM_HOME := Vector2(470, 390)
const FORM_BASE_SCALE := Vector2(0.66, 0.66)

var form_home := FORM_HOME
var form_base_scale := FORM_BASE_SCALE

var form: Panel
var slot: Panel
var slot_light: ColorRect
var status_label: Label
var applicant_card_label: Label
var queue_label: Label
var timer_label: Label
var need_status_label: Label
var validation_overlay: Control
var validation_image: TextureRect
var npc_panel: Panel
var machine_drop_zone: Control
var archive_drop_zone: Control
var machine_mouth_mask: ColorRect
var archive_stack: Control
var archive_count_label: Label
var number_machine: TextureRect
var filing_cabinet: TextureRect
var filing_cabinet_upper_hit: Button
var filing_cabinet_lower_hit: Button


# 根据持久化的待送验档案数量刷新托盘内的文件袋堆叠。
# 视觉最多展开七层，实际归档数量仍由 WorkdayState 无限保存。
func refresh_archive_stack(animate_latest := false) -> void:
	if not is_instance_valid(archive_stack):
		return
	for child in archive_stack.get_children():
		child.queue_free()

	var archive_count := WorkdayState.manager.get_pending_archives().size()
	var visible_count := mini(archive_count, 7)
	for index in visible_count:
		var envelope := TextureRect.new()
		envelope.name = "ArchivedEnvelope%02d" % (index + 1)
		envelope.texture = ARCHIVE_ENVELOPE_TEXTURE
		envelope.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		envelope.stretch_mode = TextureRect.STRETCH_SCALE
		envelope.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		envelope.position = Vector2(8 + (index % 2) * 3, -10 - index * 3)
		envelope.size = Vector2(142, 72)
		envelope.rotation = -0.012 if index % 2 == 0 else 0.014
		envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
		envelope.modulate = Color("fff4dc") if index % 2 == 0 else Color("e9d6b0")
		archive_stack.add_child(envelope)

		if animate_latest and index == visible_count - 1:
			envelope.pivot_offset = envelope.size / 2.0
			envelope.modulate.a = 0.0
			envelope.scale = Vector2(0.82, 0.65)
			var tween := archive_stack.create_tween().set_parallel(true)
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(envelope, "scale", Vector2.ONE, 0.24)
			tween.tween_property(envelope, "modulate:a", 1.0, 0.14)

	if is_instance_valid(archive_count_label):
		archive_count_label.text = "×%d" % archive_count
		archive_count_label.visible = archive_count > 0
