extends Control

const EVENING_MAP_SCENE := "res://scenes/evening_map.tscn"
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const SLIDE_TEXTURES: Array[String] = [
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_01_step.png",
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_02_step.png",
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_03_stop.png",
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_04_resume.png",
]
const SLIDE_DURATIONS: Array[float] = [1.35, 2.15, 1.65, 1.35]
const STOPPED_SLIDE_INDEX := 2

var slide_index := -1
var playback_generation := 0
var exiting := false
var footsteps_active := false
var monologue_lines: Array[String] = []

@onready var frame_texture: TextureRect = $FrameTexture
@onready var monologue_label: Label = $Monologue
@onready var progress_label: Label = $Progress
@onready var advance_hint: Label = $AdvanceHint
@onready var slide_fade: ColorRect = $SlideFade
@onready var fade: ColorRect = $Fade


# 初始化四拍下班播片；它只承接日报与夜间地图，不改变当日数据。
func _ready() -> void:
	monologue_lines = _build_monologue_lines()
	gui_input.connect(_on_gui_input)
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	fade.visible = true
	fade.modulate.a = 1.0
	_show_slide(0)
	var intro := create_tween()
	intro.tween_property(fade, "modulate:a", 0.0, 0.38)
	intro.finished.connect(func(): fade.visible = false)


# Enter、空格或鼠标点击可以提前进入下一拍；即使不操作也会自动播放。
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		advance_slide()
		get_viewport().set_input_as_handled()


# 让整张过场画面都可点击推进。
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance_slide()
		accept_event()


# 提前推进一拍；最后一拍之后自动进入夜间地图。
func advance_slide() -> void:
	if exiting:
		return
	playback_generation += 1
	var next_index := slide_index + 1
	if next_index >= SLIDE_TEXTURES.size():
		_finish_transition()
		return
	_show_slide(next_index)


# 切换当前关键帧、心理活动和脚步节奏，并启动这一拍的自动计时。
func _show_slide(index: int, schedule_next := true) -> void:
	slide_index = clampi(index, 0, SLIDE_TEXTURES.size() - 1)
	frame_texture.texture = load(SLIDE_TEXTURES[slide_index])
	monologue_label.text = monologue_lines[slide_index]
	progress_label.text = "%02d / %02d" % [slide_index + 1, SLIDE_TEXTURES.size()]
	if slide_index == STOPPED_SLIDE_INDEX:
		_stop_footsteps()
	else:
		_start_footsteps()
	if monologue_label.text != "……":
		Sfx.play("dialogue_tick")
	_flash_slide()
	if not schedule_next:
		return
	var generation := playback_generation
	_run_slide_timer(generation, SLIDE_DURATIONS[slide_index])


# 每张图使用短促黑场硬切，保留 PPT 播片的顿挫感。
func _flash_slide() -> void:
	slide_fade.visible = true
	slide_fade.modulate.a = 0.72
	var flash := create_tween()
	flash.tween_property(slide_fade, "modulate:a", 0.0, 0.14)
	flash.finished.connect(func(): slide_fade.visible = false)


# 计时器只推进仍属于当前播放代次的帧，避免点击后旧计时器重复跳页。
func _run_slide_timer(generation: int, duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if exiting or generation != playback_generation:
		return
	advance_slide()


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


# 第四拍结束后淡出并进入夜间地图。
func _finish_transition() -> void:
	if exiting:
		return
	exiting = true
	playback_generation += 1
	_stop_footsteps()
	Sfx.play("door")
	advance_hint.visible = false
	fade.visible = true
	fade.modulate.a = 0.0
	var outro := create_tween()
	outro.tween_property(fade, "modulate:a", 1.0, 0.48)
	await outro.finished
	var error := get_tree().change_scene_to_file(EVENING_MAP_SCENE)
	if error != OK:
		exiting = false
		fade.visible = false
		advance_hint.visible = true
		monologue_label.text = "门没有打开。"


# 自动化测试与视觉快照可直接定位某一拍，不启动新的计时器。
func show_slide_for_tests(index: int) -> void:
	playback_generation += 1
	_show_slide(index, false)


# 自动化测试跳过淡出，直接验证播片后的夜间地图入口。
func finish_for_tests() -> void:
	if exiting:
		return
	exiting = true
	playback_generation += 1
	_stop_footsteps()
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
