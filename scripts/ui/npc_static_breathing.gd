class_name NpcStaticBreathing
extends RefCounted

const BREATHING_SHADER := preload("res://shaders/npc_static_breathing.gdshader")
const TAU_APPROX := 6.28318


static func apply(target: CanvasItem, identity: String, amplitude := 2.4, speed := 1.55) -> void:
	var material := ShaderMaterial.new()
	material.shader = BREATHING_SHADER
	material.set_shader_parameter("breathing_amplitude", amplitude)
	material.set_shader_parameter("breathing_speed", speed)
	material.set_shader_parameter("breathing_phase", _phase_for(identity))
	target.material = material
	target.set_meta("static_breathing_enabled", true)


static func _phase_for(identity: String) -> float:
	var positive_hash := posmod(hash(identity), 10000)
	return float(positive_hash) / 10000.0 * TAU_APPROX
