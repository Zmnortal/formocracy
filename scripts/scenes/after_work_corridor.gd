extends Control

const EVENING_MAP_SCENE := "res://scenes/evening_map.tscn"
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const SLIDE_TEXTURES: Array[String] = [
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_01_step.png",
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_02_step.png",
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_03_stop.png",
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_04_resume.png",
]
const STOPPED_SLIDE_INDEX := 2

var slide_index := -1
var exiting := false
var footsteps_active := false
var monologue_lines: Array[String] = []
var dialogue_box: DialogueBox

@onready var frame_texture: TextureRect = $FrameTexture
@onready var slide_fade: ColorRect = $SlideFade
@onready var fade: ColorRect = $Fade


# 初始化四拍下班播片；每一句都复用统一底部对话框并等待玩家手动推进。
func _ready() -> void:
	monologue_lines = _build_monologue_lines()
	_build_dialogue_box()
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	fade.visible = true
	fade.modulate.a = 1.0
	_show_slide(0)
	var intro := create_tween()
	intro.tween_property(fade, "modulate:a", 0.0, 0.38)
	intro.finished.connect(func(): fade.visible = false)


# 使用全游戏统一的 DialogueBox；它负责逐字、首击补全和次击推进，绝不自动播放。
func _build_dialogue_box() -> void:
	dialogue_box = DialogueBox.new()
	add_child(dialogue_box)
	dialogue_box.advance_requested.connect(advance_slide)


# 只有统一对话框发出手动推进信号时才换到下一拍。
func advance_slide() -> void:
	if exiting:
		return
	var next_index := slide_index + 1
	if next_index >= SLIDE_TEXTURES.size():
		_finish_transition()
		return
	_show_slide(next_index)


# 切换当前关键帧、心理活动和脚步节奏；不创建任何自动推进计时器。
func _show_slide(index: int) -> void:
	slide_index = clampi(index, 0, SLIDE_TEXTURES.size() - 1)
	frame_texture.texture = load(SLIDE_TEXTURES[slide_index])
	if slide_index == STOPPED_SLIDE_INDEX:
		_stop_footsteps()
	else:
		_start_footsteps()
	dialogue_box.show_line(_player_speaker(), monologue_lines[slide_index], "player")
	_flash_slide()


# 每次手动换图使用短促黑场硬切，保留 PPT 播片的顿挫感。
func _flash_slide() -> void:
	slide_fade.visible = true
	slide_fade.modulate.a = 0.72
	var flash := create_tween()
	flash.tween_property(slide_fade, "modulate:a", 0.0, 0.14)
	flash.finished.connect(func(): slide_fade.visible = false)


# 心理活动根据当日后果选择一句残留念头，其余三拍保持麻木的固定节奏。
func _build_monologue_lines() -> Array[String]:
	var summary: Dictionary = WorkdayState.manager.get_summary()
	var memory_line := "最后一份的居住证明，日期是几号。"
	if summary.procedure_errors > 0:
		memory_line = "最后一份档案……我是不是漏看了日期。"
	elif summary.pending > 0:
		memory_line = "最后一份档案……现在只是等待处理。"
	elif summary.reviewed == 0:
		memory_line = "今天没有档案。为什么还是记不清。"
	return ["……", memory_line, "再确认一下。", "……"]


# 心理活动沿用玩家开局输入的名字，不为主角补充任何性别信息。
func _player_speaker() -> String:
	return WorkdayState.player_name if not WorkdayState.player_name.is_empty() else "经办员"


# 玩家确认第四拍后才淡出并进入夜间地图。
func _finish_transition() -> void:
	if exiting:
		return
	exiting = true
	_stop_footsteps()
	dialogue_box.close()
	Sfx.play("door")
	fade.visible = true
	fade.modulate.a = 0.0
	var outro := create_tween()
	outro.tween_property(fade, "modulate:a", 1.0, 0.48)
	await outro.finished
	var error := get_tree().change_scene_to_file(EVENING_MAP_SCENE)
	if error != OK:
		exiting = false
		fade.visible = false
		dialogue_box.show_line("内部提示", "门没有打开。", "warning")


# 自动化测试与视觉快照可直接定位某一拍，但仍通过统一对话框显示文本。
func show_slide_for_tests(index: int) -> void:
	_show_slide(index)


# 自动化测试跳过淡出，直接验证播片后的夜间地图入口。
func finish_for_tests() -> void:
	if exiting:
		return
	exiting = true
	_stop_footsteps()
	dialogue_box.close()
	get_tree().change_scene_to_file(EVENING_MAP_SCENE)


# 过场被外部切换时确保循环脚步声不会泄漏到下一场景。
func _exit_tree() -> void:
	_stop_footsteps()


# 行走帧持续播放循环脚步声。
func _start_footsteps() -> void:
	if footsteps_active:
		return
	footsteps_active = true
	Sfx.start_walking()


# 停步帧和场景离开时停止脚步声。
func _stop_footsteps() -> void:
	if not footsteps_active:
		return
	footsteps_active = false
	Sfx.stop_walking()


# 以 1280×720 为设计基准适配实际窗口。
func _fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	position = Vector2.ZERO
