extends AfterWorkProprietorScene


func _configure_scene() -> void:
	background_texture = preload("res://assets/life/interiors/home_12c.png")
	proprietor_textures = {
		"idle": preload("res://assets/characters/after_work/qin_caretaker/idle.png"),
		"talk": preload("res://assets/characters/after_work/qin_caretaker/talk.png"),
		"success": preload("res://assets/characters/after_work/qin_caretaker/success.png"),
		"reject": preload("res://assets/characters/after_work/qin_caretaker/reject.png"),
	}
	proprietor_idle_frames = [
		preload("res://assets/characters/after_work/qin_caretaker/micro_expression/frame_00.png"),
		preload("res://assets/characters/after_work/qin_caretaker/micro_expression/frame_01.png"),
		preload("res://assets/characters/after_work/qin_caretaker/micro_expression/frame_02.png"),
		preload("res://assets/characters/after_work/qin_caretaker/micro_expression/frame_03.png"),
	]
	proprietor_name = "秦叔"
	location_title = "职员宿舍 12-C · 门房交接"
	greeting = "电表没走不代表有电，也可能是表坏了。"
	idle_lines = [
		"水管今晚响得轻，说明别处先停了。",
		"门口那封不是我拆的。它来的时候就没有封严。",
	]
	actions = [
		{"id": "delivery", "label": "查看投递", "description": "检查门房代收的信件与通知", "side": "left"},
		{"id": "repair", "label": "申请报修", "description": "登记宿舍内需要维修的设施", "side": "left"},
		{"id": "forms", "label": "整理个人表单", "description": "打开档案袋整理自己的文件", "side": "right"},
		{"id": "rest", "label": "确认休息", "description": "结束今晚的行动并进入下一天", "side": "right"},
	]


func _handle_action(action_id: String) -> void:
	match action_id:
		"delivery":
			_show_feedback("今晚没有新投递。门缝里的都是旧通知。", true)
		"repair":
			_show_feedback("报修也要表。明早我可以替你问问表号。", false)
		"forms":
			get_tree().change_scene_to_file("res://scenes/application_office.tscn")
		"rest":
			WorkdayState.manager.begin_next_day()
			Sfx.play("start")
			get_tree().change_scene_to_file("res://scenes/pre_work_sequence.tscn")
