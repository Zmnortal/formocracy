extends AfterWorkProprietorScene


func _configure_scene() -> void:
	background_texture = preload("res://assets/concepts/after_work_interiors/central_forms_department_concept.png")
	proprietor_textures = {
		"idle": preload("res://assets/characters/after_work/yuan_clerk/idle.png"),
		"talk": preload("res://assets/characters/after_work/yuan_clerk/talk.png"),
		"success": preload("res://assets/characters/after_work/yuan_clerk/success.png"),
		"reject": preload("res://assets/characters/after_work/yuan_clerk/reject.png"),
	}
	proprietor_name = "袁科员"
	location_title = "中央表单部 · 夜间受理"
	greeting = "机器没坏。它只是不认可你放进去的东西。"
	idle_lines = [
		"下班时间是给楼里的。表单没有下班时间。",
		"你当然可以再交一次。退件次数不设上限。",
	]
	actions = [
		{"id": "dossier", "label": "打开档案袋", "side": "left"},
		{"id": "attachments", "label": "补充附件", "side": "left"},
		{"id": "submit", "label": "提交申请", "side": "right"},
		{"id": "returns", "label": "查看退件", "side": "right"},
	]


func _handle_action(action_id: String) -> void:
	match action_id:
		"submit", "dossier":
			get_tree().change_scene_to_file("res://scenes/application_office.tscn")
		"attachments":
			_show_feedback("附件窗口今晚只核对原件。复印件要另填证明。", false)
		"returns":
			var pending := WorkdayState.manager.get_blank_personal_forms().size()
			_show_feedback("档案袋中现有 %d 份空白表单，没有新的退件。" % pending, pending == 0)

