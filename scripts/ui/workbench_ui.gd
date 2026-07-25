class_name WorkbenchUI
extends RefCounted

# 工作台共享的视觉资源与调色板。
const PIXEL_FONT := preload("res://assets/fonts/unifont/unifont_ui.tres")

const COLORS := {
	"wall": Color("171b1a"),
	"wall_mid": Color("232a27"),
	"desk": Color("493a2d"),
	"desk_edge": Color("281f19"),
	"paper": Color("ded2ad"),
	"ink": Color("252923"),
	"green": Color("667a55"),
	"green_glow": Color("9cbb74"),
	"red": Color("8f332d"),
	"brass": Color("9a7844"),
}


# 创建 StyleBoxFlat 的辅助工厂方法。
# 可设置背景色、圆角、边框颜色与边框宽度；仅当 border 大于 0 时才配置四边边框，避免无意义的开销。
static func style_box(color: Color, radius := 0, border_color := Color.TRANSPARENT, border := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	if border > 0:
		box.border_width_left = border
		box.border_width_top = border
		box.border_width_right = border
		box.border_width_bottom = border
		box.border_color = border_color
	return box


# 通用文本标签工厂方法。
# 在指定 parent 下创建 Label，配置字体大小、像素字体、颜色、位置、尺寸与智能自动换行，并返回 Label 引用供后续修改。
static func add_text(parent: Node, text: String, size: int, color: Color, position: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = dimensions
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 这里创建的文本均为父控件的展示内容；鼠标事件应继续交给文件、按钮或桌面物件本体。
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
