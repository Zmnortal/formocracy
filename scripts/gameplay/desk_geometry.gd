class_name DeskGeometry
extends RefCounted

# ============================================================
# 桌子参数入口
# “桌面图片”和“DeskBounds 交互边界”是两套独立参数，互不跟随。
# 坐标基于 1280×720 设计画布。
# ============================================================

# 唯一设计画布尺寸。逻辑坐标始终使用该尺寸，最终由 Godot Canvas
# 统一缩放到实际窗口；因此 DESIGN_HEIGHT 永远对应游戏内容的下边缘。
const DESIGN_WIDTH := 1280.0
const DESIGN_HEIGHT := 720.0

# 桌面图片的原始矩形。TOP_INSET / BOTTOM_INSET 只改变图片形变。
const LEFT := 0.0
const RIGHT := DESIGN_WIDTH
const TOP := 465.0
const FLOOR := 840.0

# 梯形透视形变，单位为像素。
# 正数表示对应边的左右两端同时向内收缩。
# 负数表示对应边的左右两端同时向外扩张。
# 示例：TOP_INSET = 80，会让桌子上沿左右各缩进 80 像素。
# 示例：TOP_INSET = -80，会让桌子上沿左右各扩张 80 像素。
const TOP_INSET := -500.0
const BOTTOM_INSET := -20.0

# 独立的交互、回弹和物件落桌边界。
# 修改桌面图片的矩形或 inset，不会改变这些值。
const BOUNDS_LEFT := 0.0
const BOUNDS_RIGHT := DESIGN_WIDTH
const BOUNDS_TOP := 465.0
# DeskBounds 下沿严格等于游戏设计画布下沿；不要填写物理屏幕高度。
const BOUNDS_FLOOR := DESIGN_HEIGHT
const BOUNDS_TOP_INSET := 0.0
const BOUNDS_BOTTOM_INSET := 0.0

# 纹理内部的纵向弯曲。建议范围 -0.08 到 0.08，0 表示不弯曲。
const VERTICAL_BEND := 0.0


# 返回游戏设计画布尺寸。
static func design_size() -> Vector2:
	return Vector2(DESIGN_WIDTH, DESIGN_HEIGHT)


# 返回桌面图片原始矩形的尺寸。
static func size() -> Vector2:
	return Vector2(RIGHT - LEFT, FLOOR - TOP)


# 返回负 inset 造成的单侧向外扩张像素数。
static func outward_expansion() -> float:
	return maxf(0.0, -minf(TOP_INSET, BOTTOM_INSET))


# 返回扩张后桌面图片绘制矩形的左边界。
static func visual_left() -> float:
	return LEFT - outward_expansion()


# 返回扩张后桌面图片绘制矩形的尺寸。
static func visual_size() -> Vector2:
	var expansion := outward_expansion()
	return Vector2(size().x + expansion * 2.0, size().y)


# 返回 DeskBounds 交互边界的尺寸。
static func bounds_size() -> Vector2:
	return Vector2(BOUNDS_RIGHT - BOUNDS_LEFT, BOUNDS_FLOOR - BOUNDS_TOP)


# 按归一化纵向位置插值计算桌面图片的左边缘。
static func left_at(normalized_y: float) -> float:
	return LEFT + lerpf(TOP_INSET, BOTTOM_INSET, clampf(normalized_y, 0.0, 1.0))


# 按归一化纵向位置插值计算桌面图片的右边缘。
static func right_at(normalized_y: float) -> float:
	return RIGHT - lerpf(TOP_INSET, BOTTOM_INSET, clampf(normalized_y, 0.0, 1.0))


# 按归一化纵向位置插值计算交互边界的左边缘。
static func bounds_left_at(normalized_y: float) -> float:
	return BOUNDS_LEFT + lerpf(BOUNDS_TOP_INSET, BOUNDS_BOTTOM_INSET, clampf(normalized_y, 0.0, 1.0))


# 按归一化纵向位置插值计算交互边界的右边缘。
static func bounds_right_at(normalized_y: float) -> float:
	return BOUNDS_RIGHT - lerpf(BOUNDS_TOP_INSET, BOUNDS_BOTTOM_INSET, clampf(normalized_y, 0.0, 1.0))


# 将像素 inset 换算成 Shader 使用的归一化留白比例。
static func inset_ratio(inset_pixels: float) -> float:
	# Shader 只能在所属 Control 的矩形内绘制。先把矩形按最负的 inset
	# 向两侧扩大，再把真实边缘换算成这个扩大后矩形内的正向留白比例。
	var expansion := outward_expansion()
	return clampf((inset_pixels + expansion) / maxf(visual_size().x, 1.0), 0.0, 0.49)
