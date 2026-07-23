extends SceneTree

# 开场音乐管理测试。
# 验证播放器创建、循环、音量/静音控制与设置持久化。


func _init() -> void:
	call_deferred("run")


# 运行开场音乐完整测试流程。
func run() -> void:
	var music = root.get_node("OpeningMusic")
	var original_settings_path: String = music.settings_path
	music.settings_path = "user://formocracy-audio-settings-test.json"
	if FileAccess.file_exists(music.settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(music.settings_path))
	assert(music.player != null, "opening music player must be created")
	assert(music.player.stream != null, "opening track must be loaded")
	assert((music.player.stream as AudioStreamMP3).loop, "opening track must loop")
	music.play_opening()
	assert(music.player.playing, "opening music must play on the menu")
	music.set_volume_percent(45.0)
	music.set_muted(true)
	assert(music.player.volume_db <= -79.0, "mute must silence the opening track")
	music.volume_percent = 80.0
	music.muted = false
	assert(music.load_audio_settings(), "audio settings must load")
	assert(music.volume_percent == 45.0 and music.muted, "audio settings must persist volume and mute")
	music.set_muted(false)
	music.stop_opening(0.01)
	await music.fade_tween.finished
	await process_frame
	assert(not music.player.playing, "opening music must stop after its fade")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(music.settings_path))
	music.settings_path = original_settings_path
	print("FORMOCRACY_OPENING_MUSIC_TEST_OK")
	quit(0)
