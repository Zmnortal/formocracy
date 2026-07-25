# RealityBridge.gd —— FORMOCRACY(Godot 4.x) 现实事件发射器
#
# 注册为名为 RealityBridge 的 AutoLoad 后，可在任意游戏逻辑中调用便捷事件接口。
# 换热点时可通过 GLASS_WS_HOST / GLASS_WS_PORT 环境变量覆盖默认连接地址。
extends Node

signal glass_connected
signal glass_disconnected
signal reality_event_emitted(type: String, data: Dictionary)

const DEFAULT_HOST := "10.68.7.188"
const DEFAULT_PORT := 8777
const RECONNECT_INTERVAL := 2.0
const SECRETARY_DAYBRIEF_LEAD_SECONDS := 2.5

var last_emitted_event: Dictionary = {}

var _host: String
var _port: int
var _ws := WebSocketPeer.new()
var _connected := false
var _pending: Array[String] = []
var _reconnect_left := 0.0
var _secretary_chat_recording := false
var _secretary_daybrief_sent_at_msec := -1
var _secretary_briefing_chat_pending := false
var _pending_secretary_briefing_day := 0


# 初始化主机、端口并建立 WebSocket 连接。
func _ready() -> void:
	_host = _resolve_host()
	_port = _resolve_port()
	_connect()


# 从环境变量读取 GLASS_WS_HOST，否则返回默认主机。
func _resolve_host() -> String:
	var env := OS.get_environment("GLASS_WS_HOST")
	return env if env != "" else DEFAULT_HOST


# 从环境变量读取 GLASS_WS_PORT，否则返回默认端口。
func _resolve_port() -> int:
	var env := OS.get_environment("GLASS_WS_PORT")
	return int(env) if env.is_valid_int() else DEFAULT_PORT


# 尝试连接 GLASS WebSocket 服务；失败时启动重连计时。
func _connect() -> void:
	var url := "ws://%s:%d" % [_host, _port]
	print("[RealityBridge] 连接 %s ..." % url)
	var err := _ws.connect_to_url(url)
	if err != OK:
		push_warning("[RealityBridge] 连接失败: %s（%.0fs 后重试）" % [err, RECONNECT_INTERVAL])
		_reconnect_left = RECONNECT_INTERVAL


# 每帧轮询 WebSocket 状态，处理重连与事件发送。
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
				for event: String in _pending:
					_ws.send_text(event)
				_pending.clear()
		WebSocketPeer.STATE_CLOSED:
			if _connected:
				print("[RealityBridge] 连接断开，%.0fs 后重连" % RECONNECT_INTERVAL)
				glass_disconnected.emit()
			_connected = false
			_reconnect_left = RECONNECT_INTERVAL


# 全局按住 T 与眼镜秘书搭话；只处理未被表单输入框消费的按键事件。
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if key_event.physical_keycode != KEY_T:
		return
	if key_event.pressed:
		if key_event.echo or _secretary_chat_recording:
			return
		secretary_chat_start()
	elif _secretary_chat_recording:
		secretary_chat_stop()


# 返回当前是否已连接到 GLASS 服务。
func is_connected_to_glass() -> bool:
	return _connected


# 组装并发送现实事件到本地信号与 GLASS WebSocket；离线时缓存。
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


# 发送晨间简报事件到 GLASS。
func morning_briefing(day: int, lines: Array, title: String = "") -> void:
	emit_reality_event(
		"morning_briefing",
		{
			"day": day,
			"title": title if title != "" else "晨间指令 · Day %d" % day,
			"lines": lines,
		}
	)


# 发送每日结算报告事件到 GLASS。
func day_report(lines: Array, day: int = 0, title: String = "每日结算") -> void:
	var data := {"title": title, "lines": lines}
	if day > 0:
		data["day"] = day
	emit_reality_event("day_report", data)


# 发送秘书对包裹申请的反应事件到 GLASS。
func secretary_react(phase: String, parcel_no: int, weight: int, dest: String, due: float, applied: float = -1.0) -> void:
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


# 发送秘书台词事件到 GLASS。
func secretary_line(text: String) -> void:
	emit_reality_event("secretary_line", {"text": text})


# 将当天晨报和玩家过往决策发送给眼镜端，供秘书后台整理谈资，不触发朗读。
func secretary_daybrief(day: int, newspaper: Array, decisions: Array = []) -> void:
	_secretary_daybrief_sent_at_msec = Time.get_ticks_msec()
	emit_reality_event(
		"secretary_daybrief",
		{
			"day": day,
			"newspaper": newspaper,
			"decisions": decisions,
		}
	)


# 玩家到岗后让秘书基于已准备的晨报谈资发起闲聊。
# 即使场景提前调用，也会在桥内保证 daybrief 至少留出约 2.5 秒网络往返时间。
func secretary_briefing_chat(day: int = 0) -> void:
	_pending_secretary_briefing_day = day
	if _secretary_briefing_chat_pending:
		return
	_secretary_briefing_chat_pending = true
	_dispatch_secretary_briefing_chat_when_ready()


# 定时回调每次都会重新核对最近一次 daybrief；若谈资刚被刷新，则继续等待。
func _dispatch_secretary_briefing_chat_when_ready() -> void:
	var wait_seconds := 0.0
	if _secretary_daybrief_sent_at_msec >= 0:
		var elapsed_seconds := (Time.get_ticks_msec() - _secretary_daybrief_sent_at_msec) / 1000.0
		wait_seconds = SECRETARY_DAYBRIEF_LEAD_SECONDS - elapsed_seconds
	if wait_seconds > 0.0:
		get_tree().create_timer(wait_seconds).timeout.connect(_dispatch_secretary_briefing_chat_when_ready, CONNECT_ONE_SHOT)
		return
	_secretary_briefing_chat_pending = false
	var data := {}
	if _pending_secretary_briefing_day > 0:
		data["day"] = _pending_secretary_briefing_day
	emit_reality_event("secretary_briefing_chat", data)


# 玩家加入或撤出日终候选档案时，让秘书结合客观提示进行评论。
func secretary_pick_comment(form_id: String, title: String, action: String, remaining_slots: int = -1, fact_hint: String = "") -> void:
	var data := {
		"formId": form_id,
		"title": title,
		"action": action,
	}
	if remaining_slots >= 0:
		data["remainingSlots"] = remaining_slots
	if not fact_hint.is_empty():
		data["factHint"] = fact_hint
	emit_reality_event("secretary_pick_comment", data)


# 按住说话键时打断秘书朗读，并通知眼镜端开始录音。
func secretary_chat_start() -> void:
	if _secretary_chat_recording:
		return
	_secretary_chat_recording = true
	emit_reality_event("secretary_chat_start")


# 松开说话键时通知眼镜端停止录音并生成多轮对话回复。
func secretary_chat_stop() -> void:
	if not _secretary_chat_recording:
		return
	_secretary_chat_recording = false
	emit_reality_event("secretary_chat_stop")


# 发送 NPC 台词事件到 GLASS，可附带性别、年龄与头像信息。
func npc_line(name: String, text: String, gender: String = "", age: String = "", portrait: String = "") -> void:
	var data := {"title": name, "text": text}
	if gender != "":
		data["gender"] = gender
	if age != "":
		data["age"] = age
	if portrait != "":
		data["portrait"] = portrait
	emit_reality_event("npc_line", data)


# 发送现实收据/通知事件到 GLASS。
func reality_receipt(title: String, body: String, severity: String = "normal", day: int = 0, form_id: String = "", outcome: String = "") -> void:
	var data := {"title": title, "body": body, "severity": severity}
	if day > 0:
		data["day"] = day
	if form_id != "":
		data["formId"] = form_id
	if outcome != "":
		data["outcome"] = outcome
	emit_reality_event("reality_receipt", data)


# 发送后果/警告事件到 GLASS。
func consequence(title: String, body: String, severity: String = "warning") -> void:
	emit_reality_event("consequence", {"title": title, "body": body, "severity": severity})


# 发送一条连接测试收据到 GLASS。
func send_test() -> void:
	reality_receipt("连接测试", "Godot ↔ 眼镜 链路已打通", "normal")
