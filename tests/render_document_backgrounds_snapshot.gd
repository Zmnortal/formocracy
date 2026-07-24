extends SceneTree

const REPORT_OUTPUT := "user://document-daily-report.png"
const RECEIPT_OUTPUT := "user://document-next-day-receipt.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.player_name = "测试职员"
	state.balance = 42
	state.records.clear()
	state.records.append(
		{
			"code": "R-12/住房用途变更申请",
			"applicant": "周砚",
			"decision": "批准",
			"effective": true,
			"procedure_errors": [],
			"performance": 8,
			"fine": 0,
			"political_credit": 1,
		}
	)
	state.records.append(
		{
			"code": "T-04/私人终端购置申请",
			"applicant": "许冬",
			"decision": "驳回",
			"effective": false,
			"procedure_errors": ["遗漏材料"],
			"performance": -4,
			"fine": 12,
			"political_credit": -1,
		}
	)
	var error := change_scene_to_file("res://scenes/daily_report.tscn")
	assert(error == OK)
	await process_frame
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_DOCUMENT_BACKGROUNDS_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return
	var image := root.get_viewport().get_texture().get_image()
	assert(image.save_png(REPORT_OUTPUT) == OK)

	state.begin_evening()
	error = change_scene_to_file("res://scenes/evening_map.tscn")
	assert(error == OK)
	await process_frame
	await process_frame
	current_scene.next_day_receipt.visible = true
	current_scene.review_result_label.text = "处理结果：批准"
	current_scene.review_detail_label.text = "个人饮水配额申请已完成核验，现实效力自今日起记录。"
	current_scene.next_day_effect_label.text = "生活状态：饮水正常 / 操作响应恢复"
	await process_frame
	image = root.get_viewport().get_texture().get_image()
	assert(image.save_png(RECEIPT_OUTPUT) == OK)
	print("FORMOCRACY_DOCUMENT_DAILY_REPORT=%s" % ProjectSettings.globalize_path(REPORT_OUTPUT))
	print("FORMOCRACY_DOCUMENT_NEXT_DAY_RECEIPT=%s" % ProjectSettings.globalize_path(RECEIPT_OUTPUT))
	quit(0)
