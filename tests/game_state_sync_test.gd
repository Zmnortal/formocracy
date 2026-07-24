extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var sync = root.get_node("GameStateSync")
	sync.enabled = false
	sync.server_url = "https://sync.example.com/"
	sync.game_id = "demo-room"
	assert(
		sync.state_endpoint() == "https://sync.example.com/api/games/demo-room/state",
		"state endpoint must normalize the server URL and include the configured room"
	)

	sync.scene_changed("workbench", "briefing", {"day": 1})
	assert(sync.pending_updates.is_empty(), "disabled synchronization must not queue network work")

	print("FORMOCRACY_GAME_STATE_SYNC_TEST_OK")
	quit(0)
