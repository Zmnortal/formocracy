class_name NpcAnimationPlayer
extends Node

## Plays deliberately low-frame-rate NPC cutout animations.
##
## Playback is driven manually so LOOP, ONCE, and HOLD can be selected per
## performance without mutating a shared SpriteFrames resource.

signal action_finished(action: StringName)

enum PlaybackMode {
	LOOP,
	ONCE,
	HOLD,
}

const INVALID_TOKEN := -1
const FALLBACK_FPS := 1.0

var sprite: AnimatedSprite2D

var _owns_sprite := false
var _current_action: StringName = &""
var _current_mode := PlaybackMode.LOOP
var _current_frame := 0
var _elapsed_in_frame := 0.0
var _playback_token := 0
var _playing := false
var _shutdown := false


func _init(target_sprite: AnimatedSprite2D = null) -> void:
	if target_sprite != null:
		sprite = target_sprite
	else:
		sprite = AnimatedSprite2D.new()
		sprite.name = "NpcAnimatedSprite"
		add_child(sprite)
		_owns_sprite = true
	set_process(false)


func set_sprite_frames(frames: SpriteFrames) -> void:
	cancel_current()
	if is_instance_valid(sprite):
		sprite.sprite_frames = frames


func get_sprite() -> AnimatedSprite2D:
	return sprite


func owns_sprite() -> bool:
	return _owns_sprite


func play_action(action: StringName, mode: PlaybackMode = PlaybackMode.LOOP) -> int:
	if _shutdown or not _has_action(action):
		return INVALID_TOKEN

	_interrupt()
	_current_action = action
	_current_mode = mode
	_current_frame = 0
	_elapsed_in_frame = 0.0
	_playing = true
	sprite.stop()
	sprite.animation = action
	sprite.frame = 0
	set_process(true)
	return _playback_token


func cancel_current() -> int:
	_interrupt()
	return _playback_token


func shutdown() -> void:
	if _shutdown:
		return
	_shutdown = true
	_interrupt()


func get_current_action() -> StringName:
	return _current_action


func get_current_frame() -> int:
	return _current_frame


func get_playback_mode() -> PlaybackMode:
	return _current_mode


func get_playback_token() -> int:
	return _playback_token


func is_playing_action() -> bool:
	return _playing


func is_shutdown() -> bool:
	return _shutdown


func _process(delta: float) -> void:
	if not _playing:
		return
	if not is_instance_valid(sprite):
		_interrupt()
		return

	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(_current_action):
		_interrupt()
		return

	var frame_count := frames.get_frame_count(_current_action)
	if frame_count <= 0:
		_interrupt()
		return

	_elapsed_in_frame += maxf(delta, 0.0)
	var advances := 0
	while _playing and advances <= frame_count:
		var frame_duration := _get_frame_duration(frames)
		if _elapsed_in_frame < frame_duration:
			break
		_elapsed_in_frame -= frame_duration
		_advance_frame(frame_count)
		advances += 1


func _advance_frame(frame_count: int) -> void:
	if _current_frame + 1 < frame_count:
		_current_frame += 1
		sprite.frame = _current_frame
		return

	if _current_mode == PlaybackMode.LOOP:
		_current_frame = 0
		sprite.frame = 0
		return

	var finished_action := _current_action
	_playing = false
	_elapsed_in_frame = 0.0
	set_process(false)
	sprite.stop()
	sprite.animation = finished_action
	sprite.frame = frame_count - 1
	action_finished.emit(finished_action)


func _get_frame_duration(frames: SpriteFrames) -> float:
	var fps := frames.get_animation_speed(_current_action)
	if fps <= 0.0:
		fps = FALLBACK_FPS
	var duration_multiplier := frames.get_frame_duration(_current_action, _current_frame)
	return maxf(duration_multiplier / fps, 0.000001)


func _has_action(action: StringName) -> bool:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return false
	if action.is_empty() or not sprite.sprite_frames.has_animation(action):
		return false
	return sprite.sprite_frames.get_frame_count(action) > 0


func _interrupt() -> void:
	_playback_token += 1
	_playing = false
	_elapsed_in_frame = 0.0
	set_process(false)
	if is_instance_valid(sprite):
		sprite.stop()
