extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var music = root.get_node("OpeningMusic")
	assert(music.player != null, "opening music player must be created")
	assert(music.player.stream != null, "opening track must be loaded")
	assert((music.player.stream as AudioStreamMP3).loop, "opening track must loop")
	music.play_opening()
	assert(music.player.playing, "opening music must play on the menu")
	music.stop_opening(0.01)
	await music.fade_tween.finished
	await process_frame
	assert(not music.player.playing, "opening music must stop after its fade")
	print("FORMOCRACY_OPENING_MUSIC_TEST_OK")
	quit(0)
