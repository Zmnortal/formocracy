extends Node

# 开场音乐管理器。
# 负责标题菜单背景音乐循环、淡入淡出、音量与静音持久化。

const OPENING_TRACK := preload("res://assets/audio/paperwork-loop.mp3")
const SETTINGS_PATH := "user://audio-settings.json"
const BASE_VOLUME_DB := -6.0

var player: AudioStreamPlayer
var fade_tween: Tween
var settings_path := SETTINGS_PATH
var volume_percent := 80.0
var muted := false


# 创建 AudioStreamPlayer 并设置为循环，加载已保存的音频设置。
func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "PaperworkLoop"
	var looping_stream := OPENING_TRACK.duplicate() as AudioStreamMP3
	looping_stream.loop = true
	player.stream = looping_stream
	add_child(player)
	load_audio_settings()
	apply_volume()


# 播放开场音乐；若已有淡入淡出动画则先停止并重新应用音量。
func play_opening() -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	apply_volume()
	if not player.playing:
		player.play()


# 以淡出方式停止开场音乐，fade_seconds 控制淡出时长。
func stop_opening(fade_seconds := 1.0) -> void:
	if not player.playing:
		return
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", -40.0, fade_seconds)
	fade_tween.finished.connect(func():
		player.stop()
		apply_volume()
	)


# 设置音量百分比（0-100）并保存设置。
func set_volume_percent(value: float) -> void:
	volume_percent = clampf(value, 0.0, 100.0)
	apply_volume()
	save_audio_settings()


# 设置静音状态并保存设置。
func set_muted(value: bool) -> void:
	muted = value
	apply_volume()
	save_audio_settings()


# 根据当前 volume_percent 与 muted 状态应用实际分贝音量。
func apply_volume() -> void:
	if player == null:
		return
	if muted or volume_percent <= 0.0:
		player.volume_db = -80.0
	else:
		player.volume_db = BASE_VOLUME_DB + linear_to_db(volume_percent / 100.0)


# 保存音量与静音设置到 JSON 文件。
func save_audio_settings() -> bool:
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"volume_percent": volume_percent,
		"muted": muted,
	}))
	return true


# 从 JSON 文件读取音量与静音设置；若文件不存在则使用默认值。
func load_audio_settings() -> bool:
	if not FileAccess.file_exists(settings_path):
		return false
	var file := FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	volume_percent = clampf(float(parsed.get("volume_percent", 80.0)), 0.0, 100.0)
	muted = bool(parsed.get("muted", false))
	apply_volume()
	return true
