class_name DocumentChrome
extends Control

# 表单的统一视觉骨架：用功能色与像素图标建立类别识别，不表达审批结论。

const ICON_PATTERNS := {
	"form":
	[
		"1111110",
		"1000010",
		"1011110",
		"1000010",
		"1011110",
		"1000010",
		"1111110",
	],
	"person":
	[
		"0011100",
		"0111110",
		"0111110",
		"0011100",
		"0111110",
		"1111111",
		"1100011",
	],
	"home":
	[
		"0001000",
		"0011100",
		"0111110",
		"1111111",
		"1100011",
		"1101011",
		"1111111",
	],
	"hand":
	[
		"0010100",
		"0010100",
		"1010100",
		"1111110",
		"0111110",
		"0111100",
		"0011000",
	],
	"cross":
	[
		"0011100",
		"0011100",
		"1111111",
		"1111111",
		"0011100",
		"0011100",
		"0011100",
	],
	"arrow":
	[
		"0001000",
		"0001100",
		"1111110",
		"1111111",
		"1111110",
		"0001100",
		"0001000",
	],
	"key":
	[
		"0111000",
		"1101100",
		"1101100",
		"0111111",
		"0001010",
		"0001110",
		"0001000",
	],
	"language":
	[
		"1111111",
		"0011100",
		"0001000",
		"0011100",
		"0101010",
		"1000001",
		"1111111",
	],
	"file":
	[
		"1111000",
		"1001100",
		"1011110",
		"1000010",
		"1011110",
		"1000010",
		"1111110",
	],
	"gear":
	[
		"0101010",
		"1111111",
		"1101011",
		"0111110",
		"1101011",
		"1111111",
		"0101010",
	],
	"drop":
	[
		"0001000",
		"0011100",
		"0111110",
		"1111111",
		"1111111",
		"0111110",
		"0011100",
	],
	"box":
	[
		"0111110",
		"1100011",
		"1111111",
		"1101011",
		"1101011",
		"1100011",
		"0111110",
	],
}

var accent := Color("7a633e")
var icon_name := "form"
var header_height := 128.0
var footer_height := 92.0


# 接收类别视觉数据并触发重绘。
func configure(category_accent: Color, category_icon: String, header: float, footer: float) -> void:
	accent = category_accent
	icon_name = category_icon if ICON_PATTERNS.has(category_icon) else "form"
	header_height = header
	footer_height = footer
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


# 绘制克制的色带、图标底座与核验区；正文卡片由 DocumentView 排版。
func _draw() -> void:
	var margin := 28.0
	var header_rect := Rect2(margin, margin, maxf(size.x - margin * 2.0, 1.0), header_height)
	draw_rect(header_rect, accent)
	draw_rect(Rect2(size.x - margin - 10.0, header_rect.position.y, 10.0, header_rect.size.y), accent.lightened(0.18))

	var icon_box_size := clampf(header_height - 32.0, 52.0, 78.0)
	var icon_box := Rect2(header_rect.position + Vector2(16.0, (header_height - icon_box_size) * 0.5), Vector2.ONE * icon_box_size)
	draw_rect(icon_box, Color(1.0, 1.0, 1.0, 0.14))
	_draw_pixel_icon(icon_box.grow(-10.0), Color("f7edcf"))

	var footer_y := size.y - margin - footer_height
	draw_rect(Rect2(margin, footer_y, size.x - margin * 2.0, 4.0), Color(accent, 0.72))
	var stamp_width := minf(176.0, size.x * 0.3)
	draw_rect(Rect2(size.x - margin - stamp_width, footer_y + 16.0, stamp_width, footer_height - 20.0), Color(accent, 0.08))


# 将 7×7 位图图标按最近邻方块绘制，保证缩放后仍保持像素边缘。
func _draw_pixel_icon(bounds: Rect2, color: Color) -> void:
	var pattern_value: Variant = ICON_PATTERNS.get(icon_name, ICON_PATTERNS["form"])
	if not pattern_value is Array:
		return
	@warning_ignore("unsafe_cast")
	var pattern: Array = pattern_value
	var cell := floorf(minf(bounds.size.x, bounds.size.y) / 7.0)
	var render_size := Vector2.ONE * cell * 7.0
	var origin := bounds.position + (bounds.size - render_size) * 0.5
	for row in range(pattern.size()):
		var row_value := str(pattern[row])
		for column in range(mini(row_value.length(), 7)):
			if row_value[column] == "1":
				draw_rect(Rect2(origin + Vector2(column, row) * cell, Vector2.ONE * cell), color)
