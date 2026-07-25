shader_type canvas_item;
render_mode unshaded;

uniform bool outline_enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 0.95);
uniform float outline_width : hint_range(0.0, 4.0, 0.5) = 2.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	if (outline_enabled && source.a <= 0.02) {
		vec2 offset = TEXTURE_PIXEL_SIZE * outline_width;
		float nearby_alpha = 0.0;
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(offset.x, 0.0)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-offset.x, 0.0)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, -offset.y)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + offset).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - offset).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a);
		COLOR = vec4(outline_color.rgb, outline_color.a * nearby_alpha * COLOR.a);
	} else {
		COLOR = source;
	}
}
