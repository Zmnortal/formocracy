class_name BureauUI
extends RefCounted

# 局务 UI 工具库。
# 提供统一的像素字体、配色与样式工厂，用于构建控制台、弹窗等共享 UI 控件。

const PIXEL_FONT := preload("res://assets/fonts/unifont/unifont_ui.tres")

# 共享配色常量
const COLOR_BACKDROP := Color(0.015, 0.02, 0.015, 0.82)
const COLOR_PANEL := Color("0a110d")
const COLOR_PANEL_RAISED := Color("101912")
const COLOR_BORDER := Color("84945c")
const COLOR_BORDER_BRIGHT := Color("a7b878")
const COLOR_TEXT := Color("d8d1a8")
const COLOR_MUTED := Color("7f9160")
const COLOR_DANGER := Color("b85d50")


# 创建统一风格的 StyleBoxFlat（背景、边框、圆角、边距）。
static func make_box(color: Color = COLOR_PANEL, border_color: Color = COLOR_BORDER, border: int = 3, radius: int = 5) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


# 为标签应用统一的像素字体、字号与颜色。
static func style_label(label: Label, font_size: int = 18, muted := false) -> void:
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_MUTED if muted else COLOR_TEXT)


# 为按钮应用统一风格（普通、悬停、按下、焦点、禁用）。
static func style_button(button: Button, font_size: int = 18, danger := false) -> void:
	var accent := COLOR_DANGER if danger else COLOR_BORDER
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", make_box(Color("111713"), accent, 2, 3))
	button.add_theme_stylebox_override("hover", make_box(Color("1b251b"), COLOR_BORDER_BRIGHT, 3, 3))
	button.add_theme_stylebox_override("pressed", make_box(Color("202b20"), COLOR_BORDER_BRIGHT, 3, 3))
	button.add_theme_stylebox_override("focus", make_box(Color("151f16"), COLOR_BORDER_BRIGHT, 3, 3))
	button.add_theme_stylebox_override("disabled", make_box(Color("0b0e0c"), Color("3d4637"), 2, 3))


# 为面板应用默认风格。
static func style_panel(panel: Panel) -> void:
	panel.add_theme_stylebox_override("panel", make_box())


# 为滑块（HSlider/VSlider）应用统一抓取器与滑槽样式。
static func style_range(control: Range) -> void:
	control.add_theme_icon_override("grabber", _make_grabber(COLOR_BORDER_BRIGHT))
	control.add_theme_icon_override("grabber_highlight", _make_grabber(Color.WHITE))
	control.add_theme_stylebox_override("slider", make_box(Color("111713"), Color("39452f"), 1, 2))
	control.add_theme_stylebox_override("grabber_area", make_box(Color("53673c"), COLOR_BORDER, 1, 2))
	control.add_theme_stylebox_override("grabber_area_highlight", make_box(Color("718950"), COLOR_BORDER_BRIGHT, 1, 2))


# 创建单色渐变抓取器图标。
static func _make_grabber(color: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([color, color])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 12
	return texture
