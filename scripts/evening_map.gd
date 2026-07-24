extends Control

const UI := preload("res://scripts/ui/bureau_ui.gd")
const DESIGN_SIZE := Vector2(1280, 720)

@onready var day_label: Label = $Header/Day
@onready var balance_label: Label = $Header/Balance
@onready var action_label: Label = $Header/Actions
@onready var notice_label: Label = $Notice


func _ready() -> void:
	day_label.text = "第 %02d 工作日 · 18:40" % WorkdayState.day_number
	balance_label.text = "账户余额  %03d 配给券" % WorkdayState.balance
	action_label.text = "剩余行动  2 / 2"
	notice_label.text = "日报已封存。选择一个地点，安排今晚的事务。"
	apply_pixel_theme(self)
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()
	queue_redraw()


func apply_pixel_theme(node: Node) -> void:
	if node is Label:
		node.add_theme_font_override("font", UI.PIXEL_FONT)
	elif node is Button:
		node.add_theme_font_override("font", UI.PIXEL_FONT)
	for child in node.get_children():
		apply_pixel_theme(child)


func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	position = Vector2.ZERO


func _draw() -> void:
	# 旧档案室式城市地图底板。地点与路线本阶段只负责展示，交互在下一验收项实现。
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color("090d0b"))
	draw_rect(Rect2(34, 28, 1212, 650), Color("182019"), true)
	draw_rect(Rect2(34, 28, 1212, 650), Color("718054"), false, 4.0)
	draw_rect(Rect2(54, 106, 1172, 548), Color("b7a77c"), true)
	draw_rect(Rect2(54, 106, 1172, 548), Color("443e2e"), false, 3.0)

	# 档案纸折痕、坐标格和河道。
	for x in range(78, 1210, 48):
		draw_line(Vector2(x, 122), Vector2(x, 638), Color(0.23, 0.22, 0.16, 0.18), 1.0)
	for y in range(130, 638, 40):
		draw_line(Vector2(70, y), Vector2(1210, y), Color(0.23, 0.22, 0.16, 0.18), 1.0)
	var river := PackedVector2Array([
		Vector2(70, 500), Vector2(230, 474), Vector2(390, 510),
		Vector2(540, 478), Vector2(720, 528), Vector2(910, 492), Vector2(1210, 530)
	])
	draw_polyline(river, Color("405c5a"), 28.0, true)
	draw_polyline(river, Color("718b7f"), 4.0, true)

	# 红色公交通路，后续角色 Token 会沿这些线路移动。
	var routes := [
		PackedVector2Array([Vector2(184, 256), Vector2(418, 210), Vector2(642, 288), Vector2(898, 210), Vector2(1088, 294)]),
		PackedVector2Array([Vector2(184, 256), Vector2(330, 410), Vector2(642, 288), Vector2(766, 446), Vector2(1040, 414)]),
	]
	for route in routes:
		draw_polyline(route, Color("6f2e25"), 8.0, true)
		draw_polyline(route, Color("b35a3f"), 2.0, true)

	# 建筑块和站点标记，让首屏已经具备可读的地点布局。
	var blocks := [
		Rect2(116, 180, 136, 100), Rect2(350, 150, 150, 104),
		Rect2(572, 238, 144, 104), Rect2(826, 150, 156, 104),
		Rect2(1010, 242, 138, 104), Rect2(250, 364, 154, 108),
		Rect2(690, 392, 152, 106), Rect2(964, 366, 154, 108),
	]
	for block in blocks:
		draw_rect(block, Color("273126"), true)
		draw_rect(block, Color("4e563c"), false, 3.0)
		draw_line(block.position + Vector2(10, 18), Vector2(block.end.x - 10, block.position.y + 18), Color("84825f"), 2.0)
	for point in [Vector2(184, 256), Vector2(418, 210), Vector2(642, 288), Vector2(898, 210), Vector2(1088, 294), Vector2(330, 410), Vector2(766, 446), Vector2(1040, 414)]:
		draw_circle(point, 11, Color("171b15"))
		draw_circle(point, 7, Color("d2b95f"))
