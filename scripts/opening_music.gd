extends Node

const OPENING_TRACK := preload("res://assets/audio/paperwork-loop.mp3")
const PLAYBACK_VOLUME_DB := -8.0

var player: AudioStreamPlayer
var fade_tween: Tween


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "PaperworkLoop"
	var looping_stream := OPENING_TRACK.duplicate() as AudioStreamMP3
	looping_stream.loop = true
	player.stream = looping_stream
	player.volume_db = PLAYBACK_VOLUME_DB
	add_child(player)


func play_opening() -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	player.volume_db = PLAYBACK_VOLUME_DB
	if not player.playing:
		player.play()


func stop_opening(fade_seconds := 1.0) -> void:
	if not player.playing:
		return
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", -40.0, fade_seconds)
	fade_tween.finished.connect(func():
		player.stop()
		player.volume_db = PLAYBACK_VOLUME_DB
	)
