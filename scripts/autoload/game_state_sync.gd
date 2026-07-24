extends Node

# 将游戏中的展示状态按顺序发布到 Hono 服务。
# 网络错误只记录警告，不阻塞或修改本地游戏流程。

const DEFAULT_SERVER_URL := "http://127.0.0.1:3000"
const DEFAULT_GAME_ID := "adventurex-demo"

var server_url := DEFAULT_SERVER_URL
var game_id := DEFAULT_GAME_ID
var enabled := true
var pending_updates: Array[Dictionary] = []
var active_request: HTTPRequest
var last_response_code := 0


# 从环境变量读取同步服务器地址、游戏 ID 与启用开关。
func _ready() -> void:
	var configured_url := OS.get_environment("FORMOCRACY_SYNC_URL").strip_edges()
	var configured_game_id := OS.get_environment("FORMOCRACY_GAME_ID").strip_edges()
	var configured_enabled := OS.get_environment("FORMOCRACY_SYNC_ENABLED").strip_edges().to_lower()
	if not configured_url.is_empty():
		server_url = configured_url.trim_suffix("/")
	if not configured_game_id.is_empty():
		game_id = configured_game_id
	if configured_enabled in ["0", "false", "no"]:
		enabled = false


# 将状态更新加入队列并尝试立即发送。
func publish_state(update: Dictionary) -> void:
	if not enabled:
		return
	pending_updates.append(update.duplicate(true))
	_flush_next()


# 发布场景切换状态。
func scene_changed(scene: String, phase: String, metadata: Dictionary = {}) -> void:
	publish_state(
		{
			"scene": scene,
			"phase": phase,
			"speaker": null,
			"dialogue": null,
			"metadata": metadata,
		}
	)


# 发布对话开始状态，包含发言人信息与台词内容。
func speaker_started(speaker_id: String, speaker_name: String, speaker_kind: String, text: String, phase: String, metadata: Dictionary = {}) -> void:
	publish_state(
		{
			"phase": phase,
			"speaker":
			{
				"id": speaker_id,
				"name": speaker_name,
				"kind": speaker_kind,
			},
			"dialogue": {"text": text},
			"metadata": metadata,
		}
	)


# 发布对话结束状态，清空当前发言人。
func speaker_stopped(phase: String) -> void:
	publish_state(
		{
			"phase": phase,
			"speaker": null,
			"dialogue": null,
		}
	)


# 构造并返回游戏状态同步 API 端点 URL。
func state_endpoint() -> String:
	return "%s/api/games/%s/state" % [server_url.trim_suffix("/"), game_id.uri_encode()]


# 从队列取出一个待发送状态，通过 HTTP PUT 请求发送到服务端。
func _flush_next() -> void:
	if active_request != null or pending_updates.is_empty():
		return
	var update: Dictionary = pending_updates.pop_front()
	active_request = HTTPRequest.new()
	active_request.timeout = 3.0
	add_child(active_request)
	active_request.request_completed.connect(_on_request_completed)
	var error: Error = active_request.request(state_endpoint(), ["Content-Type: application/json"], HTTPClient.METHOD_PUT, JSON.stringify(update))
	if error != OK:
		push_warning("游戏状态同步请求启动失败：%s" % error_string(error))
		active_request.queue_free()
		active_request = null
		call_deferred("_flush_next")


# HTTP 请求完成后记录状态码，失败时输出警告，并继续处理队列。
func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	last_response_code = response_code
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning("游戏状态同步失败：result=%d status=%d" % [result, response_code])
	active_request.queue_free()
	active_request = null
	_flush_next()
