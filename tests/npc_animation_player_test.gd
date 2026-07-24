extends SceneTree

const PlayerClass := preload("res://scripts/gameplay/npc_animation_player.gd")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	_test_owned_and_external_sprites()
	_test_action_specific_fps_and_loop()
	_test_once_and_hold_completion()
	_test_interrupt_token_and_shutdown()
	print("FORMOCRACY_NPC_ANIMATION_PLAYER_TEST_OK")
	quit(0)


func _test_owned_and_external_sprites() -> void:
	var owned = PlayerClass.new()
	assert(owned.owns_sprite(), "a player without a target must own its sprite")
	assert(owned.get_sprite().get_parent() == owned, "the owned sprite must be a child of the player")

	var external_sprite := AnimatedSprite2D.new()
	var external = PlayerClass.new(external_sprite)
	assert(not external.owns_sprite(), "an injected sprite must remain externally owned")
	assert(external.get_sprite() == external_sprite, "the injected sprite must be used directly")
	external.shutdown()
	assert(is_instance_valid(external_sprite), "shutting down must not free an injected sprite")

	owned.free()
	external.free()
	external_sprite.free()


func _test_action_specific_fps_and_loop() -> void:
	var player = PlayerClass.new()
	player.set_sprite_frames(_make_frames())

	player.play_action(&"fast", PlayerClass.PlaybackMode.LOOP)
	player._process(0.24)
	assert(player.get_current_frame() == 0, "fast action must hold frame zero for 1 / 4 second")
	player._process(0.02)
	assert(player.get_current_frame() == 1, "fast action must advance at its configured 4 FPS")
	player._process(0.25)
	assert(player.get_current_frame() == 0, "LOOP must wrap to the first frame")

	player.play_action(&"slow", PlayerClass.PlaybackMode.LOOP)
	player._process(0.49)
	assert(player.get_current_frame() == 0, "slow action must use its own 2 FPS timing")
	player._process(0.02)
	assert(player.get_current_frame() == 1, "slow action must advance after half a second")
	player.free()


func _test_once_and_hold_completion() -> void:
	var player = PlayerClass.new()
	player.set_sprite_frames(_make_frames())
	var completed: Array[StringName] = []
	player.action_finished.connect(func(action: StringName) -> void: completed.append(action))

	player.play_action(&"reaction", PlayerClass.PlaybackMode.ONCE)
	player._process(0.31)
	assert(not player.is_playing_action(), "ONCE must stop after its last frame")
	assert(player.get_current_frame() == 2, "ONCE must finish on its final frame")
	assert(completed == [&"reaction"], "ONCE must emit one completion signal")

	player.play_action(&"reaction", PlayerClass.PlaybackMode.HOLD)
	player._process(0.31)
	assert(not player.is_playing_action(), "HOLD must stop advancing after completion")
	assert(player.get_current_frame() == 2, "HOLD must preserve the final pose")
	assert(completed == [&"reaction", &"reaction"], "HOLD must also report completion once")
	player._process(1.0)
	assert(completed.size() == 2, "a completed action must not emit repeatedly")
	player.free()


func _test_interrupt_token_and_shutdown() -> void:
	var player = PlayerClass.new()
	player.set_sprite_frames(_make_frames())
	var completion_count := 0
	player.action_finished.connect(func(_action: StringName) -> void: completion_count += 1)

	var first_token: int = player.play_action(&"reaction", PlayerClass.PlaybackMode.ONCE)
	player._process(0.05)
	var second_token: int = player.play_action(&"slow", PlayerClass.PlaybackMode.LOOP)
	assert(second_token > first_token, "starting another action must invalidate the previous token")
	assert(player.get_current_action() == &"slow", "interrupt must switch actions immediately")
	assert(completion_count == 0, "interrupting an action must not report it as completed")

	var cancelled_token := player.cancel_current()
	assert(cancelled_token > second_token, "explicit cancellation must invalidate the active token")
	assert(not player.is_playing_action(), "cancelled playback must stop immediately")

	player.shutdown()
	player.shutdown()
	assert(player.is_shutdown(), "shutdown must be idempotent")
	assert(player.play_action(&"fast", PlayerClass.PlaybackMode.LOOP) == PlayerClass.INVALID_TOKEN, "a shut down player must reject new playback")
	player.free()


func _make_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var texture := GradientTexture1D.new()

	frames.add_animation(&"fast")
	frames.set_animation_speed(&"fast", 4.0)
	frames.add_frame(&"fast", texture)
	frames.add_frame(&"fast", texture)

	frames.add_animation(&"slow")
	frames.set_animation_speed(&"slow", 2.0)
	frames.add_frame(&"slow", texture)
	frames.add_frame(&"slow", texture)

	frames.add_animation(&"reaction")
	frames.set_animation_speed(&"reaction", 10.0)
	frames.add_frame(&"reaction", texture)
	frames.add_frame(&"reaction", texture)
	frames.add_frame(&"reaction", texture)
	return frames
