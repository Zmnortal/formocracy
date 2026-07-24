extends SceneTree

const CONNECTION_TIMEOUT_SECONDS := 8.0
const DELIVERY_GRACE_SECONDS := 1.0

var _bridge: Node
var _elapsed := 0.0
var _sent := false
var _delivery_elapsed := 0.0


func _initialize() -> void:
	_bridge = root.get_node_or_null("RealityBridge")
	if _bridge == null:
		push_error("[RealityBridgeNpcLiveTest] RealityBridge AutoLoad 未加载")
		quit(1)
		return
	if _bridge.is_connected_to_glass():
		_send_npc_line()
	else:
		_bridge.glass_connected.connect(_send_npc_line, CONNECT_ONE_SHOT)


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _sent and _elapsed >= CONNECTION_TIMEOUT_SECONDS:
		push_error("[RealityBridgeNpcLiveTest] 连接眼镜超时")
		quit(1)
		return true
	if _sent:
		_delivery_elapsed += delta
		if _delivery_elapsed >= DELIVERY_GRACE_SECONDS:
			print("[RealityBridgeNpcLiveTest] NPC 台词已发送")
			quit(0)
			return true
	return false


func _send_npc_line() -> void:
	_bridge.npc_line("林默", "您好。我来办理共同居住配额。", "male", "young")
	_sent = true
