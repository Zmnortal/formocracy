extends SceneTree

const NPC_STATIC_BREATHING := preload("res://scripts/ui/npc_static_breathing.gd")


func _init() -> void:
	var sprite := Sprite2D.new()
	NPC_STATIC_BREATHING.apply(sprite, "TEST-NPC", 2.4, 1.55)

	assert(sprite.get_meta("static_breathing_enabled", false), "breathing effect must mark its target")
	assert(sprite.material is ShaderMaterial, "breathing effect must use an isolated shader material")
	var material := sprite.material as ShaderMaterial
	assert(is_equal_approx(material.get_shader_parameter("breathing_amplitude"), 2.4), "breathing amplitude must remain subtle")
	assert(is_equal_approx(material.get_shader_parameter("breathing_speed"), 1.55), "breathing speed must remain slow")

	var second_sprite := Sprite2D.new()
	NPC_STATIC_BREATHING.apply(second_sprite, "SECOND-NPC", 1.8, 1.45)
	var second_material := second_sprite.material as ShaderMaterial
	assert(
		not is_equal_approx(
			material.get_shader_parameter("breathing_phase"),
			second_material.get_shader_parameter("breathing_phase"),
		),
		"different NPCs should not breathe in mechanical unison",
	)

	print("NPC static breathing tests passed")
	quit()
