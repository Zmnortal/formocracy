class_name DeskGeometry
extends RefCounted

# ============================================================
# 桌子唯一参数入口
# 只需要修改这一段数值；图片、调试框和物件落桌碰撞会共同更新。
# 坐标基于 1280×720 设计画布。
# ============================================================

# 桌子外框与碰撞范围。
const LEFT := 0.0
const RIGHT := 1280.0
const TOP := 465.0
const FLOOR := 800.0

# 梯形透视形变，单位为像素。
# 正数表示对应边的左右两端同时向内收缩。
# 示例：TOP_INSET = 80，会让桌子上沿左右各缩进 80 像素。
const TOP_INSET := -240.0
const BOTTOM_INSET := -20.0

# 纹理内部的纵向弯曲。建议范围 -0.08 到 0.08，0 表示不弯曲。
const VERTICAL_BEND := 0.0


static func size() -> Vector2:
	return Vector2(RIGHT - LEFT, FLOOR - TOP)


static func left_at(normalized_y: float) -> float:
	return LEFT + lerpf(TOP_INSET, BOTTOM_INSET, clampf(normalized_y, 0.0, 1.0))


static func right_at(normalized_y: float) -> float:
	return RIGHT - lerpf(TOP_INSET, BOTTOM_INSET, clampf(normalized_y, 0.0, 1.0))


static func inset_ratio(inset_pixels: float) -> float:
	return clampf(inset_pixels / maxf(size().x, 1.0), 0.0, 0.49)
