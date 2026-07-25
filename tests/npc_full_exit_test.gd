extends SceneTree

# NPC 完整退场测试：人物必须始终不透明，且最右侧越过画布左边界后才能释放。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	var module_script: Variant = load(
		"res://scripts/managers/workbench_manager/workbench_npc_performance_module.gd"
	)
	var module: Variant = module_script.new(scene)
	var actor := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var image := Image.create(512, 768, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	frames.add_frame(&"default", ImageTexture.create_from_image(image))
	actor.sprite_frames = frames
	actor.position = module.FRONT_POSITION
	actor.scale = Vector2.ONE * 0.44
	module.actor_layer.add_child(actor)
	module.current_actor = actor
	module.performance_token = 1
	module.promote_after_departure = false

	var target: Vector2 = module._fully_offscreen_exit_position(actor)
	var half_visual_width := 512.0 * actor.scale.x * 0.5
	assert(target.x + half_visual_width < 0.0, "the NPC's right edge must finish beyond the viewport")

	var departing_actor := actor
	module._walk_current_actor_out("walk_out_angry", 1)
	await create_timer(0.2).timeout
	assert(module.state == "WALKING_OUT")
	assert(is_equal_approx(departing_actor.modulate.a, 1.0), "departure must not fade the NPC")
	var first_sample_x := departing_actor.position.x

	module.skip_current_performance()
	await create_timer(0.2).timeout
	assert(module.state == "WALKING_OUT", "clicking during departure must not delete or jump-cut the NPC")
	assert(is_instance_valid(departing_actor))
	assert(is_equal_approx(departing_actor.modulate.a, 1.0), "the NPC must remain opaque after a skip request")
	assert(departing_actor.position.x < first_sample_x, "the NPC must continue walking left")

	await create_timer(2.0).timeout
	assert(module.state == "IDLE", "the NPC departure must finish after reaching the offscreen target")
	assert(not is_instance_valid(departing_actor), "the NPC may be released only after the exit walk completes")

	module.shutdown()
	scene.queue_free()
	await process_frame
	print("FORMOCRACY_NPC_FULL_EXIT_TEST_OK")
	quit()
