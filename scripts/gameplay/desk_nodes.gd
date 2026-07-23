class_name DeskNodes
extends RefCounted

# 工作台静态节点引用容器。
# 由 DeskBuilder 创建并填充，供主脚本与各 gameplay 模块共享使用。

const FORM_HOME := Vector2(435, 252)
const FORM_BASE_SCALE := Vector2(0.86, 0.86)

var form_home := FORM_HOME
var form_base_scale := FORM_BASE_SCALE

var form: Panel
var slot: Panel
var slot_light: ColorRect
var status_label: Label
var applicant_card_label: Label
var queue_label: Label
var timer_label: Label
var validation_overlay: Control
var validation_image: TextureRect
var npc_panel: Panel
