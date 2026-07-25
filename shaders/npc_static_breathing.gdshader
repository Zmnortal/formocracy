shader_type canvas_item;

uniform float breathing_amplitude : hint_range(0.0, 8.0, 0.1) = 2.4;
uniform float breathing_speed : hint_range(0.1, 4.0, 0.05) = 1.55;
uniform float breathing_phase : hint_range(0.0, 6.28318, 0.01) = 0.0;

void vertex() {
	float breath = sin(TIME * breathing_speed + breathing_phase);
	float anchored_vertical = 1.0 - smoothstep(0.18, 0.96, UV.y);
	float torso = smoothstep(0.18, 0.42, UV.y) * (1.0 - smoothstep(0.68, 0.9, UV.y));

	VERTEX.y -= breath * breathing_amplitude * anchored_vertical;
	VERTEX.x += (UV.x - 0.5) * breath * breathing_amplitude * 0.32 * torso;
}
