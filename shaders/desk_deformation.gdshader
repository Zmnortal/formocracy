shader_type canvas_item;

// 这里接收的是扩大后绘制矩形内的边缘留白比例。DeskGeometry 中允许使用
// 负像素 inset，并负责把它换算成该矩形内的非负比例。
uniform float top_inset : hint_range(0.0, 0.49) = 0.0;
uniform float bottom_inset : hint_range(0.0, 0.49) = 0.0;
uniform float vertical_bend : hint_range(-0.15, 0.15) = 0.0;


void fragment() {
	float y = UV.y;
	float inset = mix(top_inset, bottom_inset, y);
	float visible_width = max(1.0 - inset * 2.0, 0.001);
	float source_x = (UV.x - inset) / visible_width;
	float source_y = clamp(y + sin(y * 3.14159265) * vertical_bend, 0.0, 1.0);

	if (source_x < 0.0 || source_x > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, vec2(source_x, source_y)) * COLOR;
	}
}
