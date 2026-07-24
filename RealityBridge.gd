# RealityBridge.gd —— FORMOCRACY(Godot 4.x) 现实事件发射器
#
# 注册为名为 RealityBridge 的 AutoLoad 后，可在任意游戏逻辑中调用便捷事件接口。
# 换热点时可通过 GLASS_WS_HOST / GLASS_WS_PORT 环境变量覆盖默认连接地址。
extends Node

const DEFAULT_HOST := "172.20.10.3"
const DEFAULT_PORT := 8777
const RECONNECT_INTERVAL := 2.0

signal glass_connected
signal glass_disconnected
signal reality_event_emitted(type: String, data: Dictionary)

var _host: String
var _port: int
var _ws := WebSocketPeer.new()
var _connected := false
var _pending: Array = []
var _reconnect_left := 0.0
var last_emitted_event: Dictionary = {}


func _ready() -> void:
	_host = _resolve_host()
	_port = _resolve_port()
	_connect()


func _resolve_host() -> String:
	var env := OS.get_environment("GLASS_WS_HOST")
	return env if env != "" else DEFAULT_HOST


func _resolve_port() -> int:
	var env := OS.get_environment("GLASS_WS_PORT")
	return int(env) if env.is_valid_int() else DEFAULT_PORT


func _connect() -> void:
	var url := "ws://%s:%d" % [_host, _port]
	print("[RealityBridge] 连接 %s ..." % url)
	var err := _ws.connect_to_url(url)
	if err != OK:
		push_warning("[RealityBridge] 连接失败: %s（%.0fs 后重试）" % [err, RECONNECT_INTERVAL])
		_reconnect_left = RECONNECT_INTERVAL


func _process(delta: float) -> void:
	if _reconnect_left > 0.0:
		_reconnect_left -= delta
		if _reconnect_left <= 0.0:
			_ws = WebSocketPeer.new()
			_connect()
		return

	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				print("[RealityBridge] 已连接 %s:%d" % [_host, _port])
				glass_connected.emit()
				for event in _pending:
					_ws.send_text(event)
				_pending.clear()
		WebSocketPeer.STATE_CLOSED:
			if _connected:
				print("[RealityBridge] 连接断开，%.0fs 后重连" % RECONNECT_INTERVAL)
				glass_disconnected.emit()
			_connected = false
			_reconnect_left = RECONNECT_INTERVAL


func is_connected_to_glass() -> bool:
	return _connected


func emit_reality_event(type: String, data: Dictionary = {}) -> void:
	var payload := data.duplicate()
	payload["type"] = type
	last_emitted_event = payload.duplicate(true)
	reality_event_emitted.emit(type, payload.duplicate(true))
	var text := JSON.stringify(payload)
	if _connected:
		_ws.send_text(text)
	else:
		_pending.append(text)


func morning_briefing(day: int, lines: Array, title := "") -> void:
	emit_reality_event("morning_briefing", {
		"day": day,
		"title": title if title != "" else "晨间指令 · Day %d" % day,
		"lines": lines,
	})


func day_report(lines: Array, day := 0, title := "每日结算") -> void:
	var data := {"title": title, "lines": lines}
	if day > 0:
		data["day"] = day
	emit_reality_event("day_report", data)


func secretary_react(phase: String, parcel_no: int, weight: int, dest: String, due: float, applied := -1.0) -> void:
	var data := {
		"phase": phase,
		"parcelNo": parcel_no,
		"weight": weight,
		"dest": dest,
		"due": due,
	}
	if applied >= 0.0:
		data["applied"] = applied
	emit_reality_event("secretary_react", data)


func secretary_line(text: String) -> void:
	emit_reality_event("secretary_line", {"text": text})


func npc_line(name: String, text: String, gender := "", age := "", portrait := "") -> void:
	var data := {"title": name, "text": text}
	if gender != "":
		data["gender"] = gender
	if age != "":
		data["age"] = age
	if portrait != "":
		data["portrait"] = portrait
	emit_reality_event("npc_line", data)


func reality_receipt(title: String, body: String, severity := "normal", day := 0, form_id := "", outcome := "") -> void:
	var data := {"title": title, "body": body, "severity": severity}
	if day > 0:
		data["day"] = day
	if form_id != "":
		data["formId"] = form_id
	if outcome != "":
		data["outcome"] = outcome
	emit_reality_event("reality_receipt", data)


func consequence(title: String, body: String, severity := "warning") -> void:
	emit_reality_event("consequence", {"title": title, "body": body, "severity": severity})


func send_test() -> void:
	reality_receipt("连接测试", "Godot ↔ 眼镜 链路已打通", "normal")
