extends SceneTree


# 验证统一对话框的逐字、补全、箭头和手动推进状态机。
func _init() -> void:
	call_deferred("run")


# 一句话必须经过两次手动操作，且等待期间绝不自行推进。
func run() -> void:
	assert(ResourceLoader.exists("res://assets/audio/sfx/dialogue_type_tick.wav", "AudioStream"), "dialogue typewriter tick must import as a playable audio stream")
	var box := DialogueBox.new()
	root.add_child(box)
	await process_frame
	box.characters_per_second = 1.0
	box.show_line("测试人员", "逐字显示", "npc")
	assert(box.visible, "dialogue box must cover the scene while a line is active")
	assert(box.state == DialogueBox.DialogueState.TYPING, "new dialogue must start in typing state")
	assert(box.dialogue_label.visible_characters == 0, "new dialogue must never appear all at once")
	assert(not box.advance_arrow.visible, "advance arrow must remain hidden while typing")

	box._process(1.1)
	assert(box.dialogue_label.visible_characters == 1, "typewriter must reveal characters progressively")
	var advances: Array[bool] = []
	box.advance_requested.connect(func(): advances.append(true))
	box._handle_manual_advance()
	assert(box.state == DialogueBox.DialogueState.WAITING_FOR_INPUT, "first input must complete the current line")
	assert(box.dialogue_label.visible_characters == -1, "first input must reveal the complete current line")
	assert(box.advance_arrow.visible, "completion must reveal a right-facing arrow")
	assert(advances.is_empty(), "the input that completes a line must not also advance it")

	await create_timer(0.15).timeout
	assert(advances.is_empty(), "completed dialogue must never advance on a timer")
	box._handle_manual_advance()
	assert(advances.size() == 1, "second input must advance exactly once")
	box.close()
	assert(not box.visible and box.state == DialogueBox.DialogueState.HIDDEN, "closing dialogue must release the scene")

	var bubble := NpcSpeechBubble.new()
	root.add_child(bubble)
	await process_frame
	bubble.play_line("申请人", "请您看看这份材料。")
	assert(bubble.visible, "NPC dialogue must use a visible speech bubble")
	assert(bubble.position.y < DialogueBox.PANEL_POSITION.y, "NPC bubble must stay near the character rather than use the bottom form")
	assert(bubble.size == NpcSpeechBubble.BUBBLE_SIZE, "NPC bubble must retain the compact porch-sized composition")
	assert(bubble.position.x + bubble.size.x <= 850.0, "NPC bubble must stay inside the middle porch opening")
	assert(bubble.z_index >= 4000, "NPC bubble must render above workbench forms")
	assert(bubble.dialogue_label.visible_characters == 0, "NPC speech must also begin with typewriter reveal")
	bubble._process(0.08)
	assert(bubble.dialogue_label.visible_characters > 0, "NPC speech bubble must reveal text progressively")
	var bubble_finishes: Array[bool] = []
	bubble.finished.connect(func(): bubble_finishes.append(true))
	bubble._handle_pointer_advance()
	assert(bubble.visible and not bubble.typing, "the first screen click must complete the current NPC line without closing it")
	assert(bubble.dialogue_label.visible_characters == -1, "the first screen click must reveal the complete NPC line")
	bubble._handle_pointer_advance()
	assert(not bubble.visible, "the second screen click must dismiss the completed NPC line immediately")
	assert(bubble_finishes.size() == 1, "manual NPC dismissal must release the waiting performance exactly once")

	bubble.play_line("申请人", "这是另一条自动收束测试。")
	assert(bubble.visible and bubble.typing, "a manually dismissed bubble must remain reusable")
	await create_timer(5.3).timeout
	assert(not bubble.visible, "NPC speech bubble must auto-hide after about five seconds")

	print("FORMOCRACY_DIALOGUE_BOX_TEST_OK")
	quit(0)
