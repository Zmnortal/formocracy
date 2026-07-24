extends SceneTree

const CONNECTION_TIMEOUT_SECONDS := 8.0
const DELIVERY_GRACE_SECONDS := 1.0

var _elapsed := 0.0
var _sent := false
var _delivery_elapsed := 0.0
var _bridge: Node


func _initialize() -> void:
	_bridge = root.get_node_or_null("RealityBridge")
	if _bridge == null:
		push_error("[RealityBridgeLiveTest] RealityBridge AutoLoad 未加载")
		quit(1)
		return
	if _bridge.is_connected_to_glass():
		_send_test()
	else:
		_bridge.glass_connected.connect(_send_test, CONNECT_ONE_SHOT)


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _sent and _elapsed >= CONNECTION_TIMEOUT_SECONDS:
		push_error("[RealityBridgeLiveTest] 连接眼镜超时")
		quit(1)
		return true

	if _sent:
		_delivery_elapsed += delta
		if _delivery_elapsed >= DELIVERY_GRACE_SECONDS:
			print("[RealityBridgeLiveTest] send_test() 已发送")
			quit(0)
			return true
	return false


func _send_test() -> void:
	_bridge.send_test()
	_sent = true
