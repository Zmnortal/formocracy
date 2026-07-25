extends SceneTree

# 验证新版眼镜秘书协议，同时确保现有 last_emitted_event 测试钩子仍然保留。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var bridge := root.get_node("RealityBridge")
	bridge.secretary_daybrief(3, [{"headline": "供水许可重新核发", "body": "第十二区仍有住户等待。"}], [{"formId": "CASE-001", "title": "共同居住申请", "decision": "approved", "day": 2}])
	assert(bridge.last_emitted_event.type == "secretary_daybrief", "daybrief must use the delivered protocol type")
	assert(bridge.last_emitted_event.newspaper.size() == 1, "daybrief must preserve newspaper context")
	assert(bridge.last_emitted_event.decisions.size() == 1, "daybrief must preserve decision history")

	bridge.secretary_briefing_chat(3)
	assert(bridge.last_emitted_event.type == "secretary_daybrief", "arrival chat must wait for the daybrief network lead time")
	await create_timer(bridge.SECRETARY_DAYBRIEF_LEAD_SECONDS + 0.6).timeout
	assert(bridge.last_emitted_event == {"type": "secretary_briefing_chat", "day": 3}, "arrival chat must include the current day")

	bridge.secretary_pick_comment("CASE-002", "供水配额复核", "add", 1, "已等待 2 日")
	assert(bridge.last_emitted_event.type == "secretary_pick_comment", "candidate selection must use the delivered protocol type")
	assert(bridge.last_emitted_event.remainingSlots == 1, "candidate selection must use camelCase protocol fields")

	bridge.secretary_chat_start()
	assert(bridge.last_emitted_event.type == "secretary_chat_start", "press-to-talk must emit its start event")
	bridge.secretary_chat_stop()
	assert(bridge.last_emitted_event.type == "secretary_chat_stop", "press-to-talk must emit its stop event")

	print("FORMOCRACY_REALITY_BRIDGE_SECRETARY_API_TEST_OK")
	quit()
