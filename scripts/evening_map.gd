extends Control

const UI := preload("res://scripts/ui/bureau_ui.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const LOCATION_OFFICE := "LOCATION-OFFICE"
const LOCATION_FORMS := "LOCATION-FORMS"
const LOCATION_RATION := "LOCATION-RATION"
const LOCATION_HOME := "LOCATION-HOME"

const LOCATION_POSITIONS := {
	LOCATION_OFFICE: Vector2(766, 446),
	LOCATION_FORMS: Vector2(184, 256),
	LOCATION_RATION: Vector2(642, 288),
	LOCATION_HOME: Vector2(1040, 414),
}
const LOCATION_NAMES := {
	LOCATION_FORMS: "中央表单部",
	LOCATION_RATION: "公共配给站",
	LOCATION_HOME: "职员宿舍 12-C",
}

@onready var day_label: Label = $Header/Day
@onready var balance_label: Label = $Header/Balance
@onready var action_label: Label = $Header/Actions
@onready var notice_label: Label = $Notice
@onready var player_token: Panel = $PlayerToken
@onready var forms_button: Button = $FormsButton
@onready var ration_button: Button = $RationButton
@onready var home_button: Button = $HomeButton
@onready var arrival_card: Panel = $ArrivalCard
@onready var arrival_title: Label = $ArrivalCard/Title
@onready var arrival_body: Label = $ArrivalCard/Body

var moving := false
var active_route_points: Array[Vector2] = []
var highlighted_route_points: Array[Vector2] = []


func _ready() -> void:
	WorkdayState.begin_evening()
	day_label.text = "第 %02d 工作日 · 18:40" % WorkdayState.day_number
	balance_label.text = "账户余额  %03d 配给券" % WorkdayState.balance
	apply_pixel_theme(self)
	connect_location_button(forms_button, LOCATION_FORMS)
	connect_location_button(ration_button, LOCATION_RATION)
	connect_location_button(home_button, LOCATION_HOME)
	player_token.position = LOCATION_POSITIONS.get(WorkdayState.evening_location_id, LOCATION_POSITIONS[LOCATION_OFFICE]) - player_token.size * 0.5
	refresh_map_state()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()
	queue_redraw()


func connect_location_button(button: Button, location_id: String) -> void:
	button.pressed.connect(func(): select_location(location_id))
	button.mouse_entered.connect(func(): animate_button_hover(button, true))
	button.mouse_exited.connect(func(): animate_button_hover(button, false))
	button.pivot_offset = button.size * 0.5


func animate_button_hover(button: Button, hovered: bool) -> void:
	if moving or button.disabled:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.035, 1.035) if hovered else Vector2.ONE, 0.1)


func select_location(location_id: String) -> void:
	if moving or location_id == WorkdayState.evening_location_id:
		return
	if WorkdayState.evening_actions_remaining <= 0 and location_id != LOCATION_HOME:
		notice_label.text = "今日行动已经用尽。你只能返回职员宿舍。"
		return
	arrival_card.visible = false
	moving = true
	set_location_buttons_enabled(false)
	active_route_points = build_route(WorkdayState.evening_location_id, location_id)
	highlighted_route_points = [active_route_points[0]]
	notice_label.text = "正在前往：%s" % LOCATION_NAMES[location_id]
	queue_redraw()
	await animate_route(active_route_points)
	WorkdayState.arrive_at_evening_location(location_id)
	moving = false
	show_arrival_card(location_id)
	refresh_map_state()


func build_route(from_id: String, to_id: String) -> Array[Vector2]:
	var start: Vector2 = LOCATION_POSITIONS.get(from_id, LOCATION_POSITIONS[LOCATION_OFFICE])
	var finish: Vector2 = LOCATION_POSITIONS[to_id]
	var route: Array[Vector2] = [start]
	if from_id != LOCATION_OFFICE and to_id != LOCATION_OFFICE:
		route.append(LOCATION_POSITIONS[LOCATION_OFFICE])
	var midpoint := Vector2((route[-1].x + finish.x) * 0.5, minf(route[-1].y, finish.y) - 34.0)
	route.append(midpoint)
	route.append(finish)
	return route


func animate_route(route: Array[Vector2]) -> void:
	for i in range(1, route.size()):
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(player_token, "position", route[i] - player_token.size * 0.5, 0.34)
		await tween.finished
		highlighted_route_points.append(route[i])
		queue_redraw()


func show_arrival_card(location_id: String) -> void:
	arrival_title.text = "已抵达 · %s" % LOCATION_NAMES[location_id]
	match location_id:
		LOCATION_RATION:
			arrival_body.text = "营业状态：开放\n饮水与食品表单目录将在下一阶段接入。"
		LOCATION_HOME:
			arrival_body.text = "住宅门禁已确认身份。\n回家填写个人表单将在后续阶段接入。"
		_:
			arrival_body.text = "特殊窗口仅在收到行政通知时办理。\n当前没有可办理事项。"
	arrival_card.visible = true


func refresh_map_state() -> void:
	action_label.text = "剩余行动  %d / 2" % WorkdayState.evening_actions_remaining
	if not moving:
		set_location_buttons_enabled(true)
	notice_label.text = "当前位置：%s。请选择下一处地点。" % get_current_location_name()
	if WorkdayState.evening_actions_remaining <= 0:
		notice_label.text = "今日行动已经用尽。请返回职员宿舍。"
	queue_redraw()


func set_location_buttons_enabled(enabled: bool) -> void:
	forms_button.disabled = not enabled or WorkdayState.evening_actions_remaining <= 0
	ration_button.disabled = not enabled or WorkdayState.evening_actions_remaining <= 0
	home_button.disabled = not enabled or WorkdayState.evening_location_id == LOCATION_HOME


func get_current_location_name() -> String:
	if WorkdayState.evening_location_id == LOCATION_OFFICE:
		return "中央现实管理局"
	return String(LOCATION_NAMES.get(WorkdayState.evening_location_id, "未登记地点"))


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
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color("090d0b"))
	draw_rect(Rect2(34, 28, 1212, 650), Color("182019"), true)
	draw_rect(Rect2(34, 28, 1212, 650), Color("718054"), false, 4.0)
	draw_rect(Rect2(54, 106, 1172, 548), Color("b7a77c"), true)
	draw_rect(Rect2(54, 106, 1172, 548), Color("443e2e"), false, 3.0)
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
	var routes := [
		PackedVector2Array([Vector2(184, 256), Vector2(418, 210), Vector2(642, 288), Vector2(898, 210), Vector2(1088, 294)]),
		PackedVector2Array([Vector2(184, 256), Vector2(330, 410), Vector2(642, 288), Vector2(766, 446), Vector2(1040, 414)]),
	]
	for route in routes:
		draw_polyline(route, Color("6f2e25"), 8.0, true)
		draw_polyline(route, Color("b35a3f"), 2.0, true)
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
	if highlighted_route_points.size() > 1:
		draw_polyline(PackedVector2Array(highlighted_route_points), Color("f2cb52"), 4.0, true)
	for point in highlighted_route_points:
		draw_circle(point, 6, Color("ffe477"))
