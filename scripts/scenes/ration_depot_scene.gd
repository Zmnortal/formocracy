extends AfterWorkProprietorScene

const WATER_FORM_ID := "PERSONAL-FORM-WATER-R01"


func _configure_scene() -> void:
	background_texture = preload("res://assets/concepts/after_work_interiors/ration_depot_concept.png")
	proprietor_textures = {
		"idle": preload("res://assets/characters/after_work/ma_ration/idle.png"),
		"talk": preload("res://assets/characters/after_work/ma_ration/talk.png"),
		"success": preload("res://assets/characters/after_work/ma_ration/success.png"),
		"reject": preload("res://assets/characters/after_work/ma_ration/reject.png"),
	}
	proprietor_idle_frames = [
		preload("res://assets/characters/after_work/ma_ration/micro_expression/frame_00.png"),
		preload("res://assets/characters/after_work/ma_ration/micro_expression/frame_01.png"),
		preload("res://assets/characters/after_work/ma_ration/micro_expression/frame_02.png"),
		preload("res://assets/characters/after_work/ma_ration/micro_expression/frame_03.png"),
	]
	proprietor_name = "马姐"
	location_title = "公共配给站 · 第三领取窗"
	greeting = "今天的水没有昨天黄。你就当这是好消息。"
	idle_lines = [
		"罐子拿稳，摔坏了算你的，洒出去也算你的。",
		"隔壁楼已经来第三趟了。人没多，表倒是一张不少。",
	]
	actions = [
		{"id": "identity", "label": "出示证件", "description": "让窗口核验住址与配给资格", "side": "left"},
		{"id": "buy_form", "label": "购买饮水表", "description": "用配给券领取一张空白饮水表", "side": "left"},
		{"id": "collect_water", "label": "领取饮水", "description": "凭当日有效回执领取饮用水", "side": "right"},
		{"id": "collect_food", "label": "领取食品", "description": "查询今晚可领取的食品份额", "side": "right"},
	]


func _handle_action(action_id: String) -> void:
	match action_id:
		"identity":
			_show_feedback("身份有效。住址还是 12-C，至少档案上没变。", true)
		"buy_form":
			if WorkdayState.manager.purchase_personal_form(WATER_FORM_ID):
				Sfx.play("stamp")
				_show_feedback("空白饮水表。收好，填错了不补发工本费。", true)
			else:
				_show_feedback("配给券不够。窗口不能替你记账。", false)
		"collect_water":
			_show_feedback("没有当日有效领取回执。先去把申请交了。", false)
		"collect_food":
			_show_feedback("食品窗口今晚只处理提前登记件。", false)
