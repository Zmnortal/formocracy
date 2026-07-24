extends Node

# 工作日状态。
# 管理玩家每日的案件记录、结算、存档、工作时长与跨日推进，是连接玩法与持久化的核心状态。

const CASES_PER_DAY := 3
const DEFAULT_SAVE_PATH := "user://formocracy-save.json"
const SAVE_TREE_VERSION := 7

# 当前工作日的核心数据
var day_number := 1
var records: Array[Dictionary] = []
var save_path := DEFAULT_SAVE_PATH
var current_level_id := "day_1"
var target_case_count := CASES_PER_DAY
var report_title := "工作日处理回执"
var player_name := ""
var reinstatement_date := ""
var player_signature: Array = []

# 案件决策缓存与后续后果
var decision_by_case_id: Dictionary = {}
var persistence_enabled := true

# 工作时长与经济状态
var workday_duration := 180.0
var seconds_remaining := 180.0
var base_salary := 0
var living_expenses: Dictionary = {}
var balance := 0
var political_credit := 0
var delayed_consequences: Array[Dictionary] = []
var settled_day_number := 0
var machine_capacity := 2
var archived_cases: Array[Dictionary] = []
var next_archive_serial := 1

# 夜间地图状态
var evening_day_number := 0
var evening_actions_remaining := 2
var evening_location_id := "LOCATION-OFFICE"
var personal_form_inventory: Array[Dictionary] = []
var next_inventory_serial := 1
var water_covered_until_day := 1
var water_deprived := false
var last_personal_review_results: Array[Dictionary] = []

# 当前临时进度所基于的不可变检查点。完成下一天时，新节点会挂在它下面。
var active_checkpoint_id := ""


# 使用 CSV 关卡配置初始化工作日状态。
func configure_level(level_id: String, configured_day: int, case_count: int, configured_report_title: String) -> void:
	current_level_id = level_id
	day_number = configured_day
	target_case_count = maxi(1, case_count)
	report_title = configured_report_title
	records.clear()


# 使用 JSON 工作日本体配置初始化工作日状态（时长、日薪、生活支出等）。
func configure_workday(workday: Dictionary) -> void:
	current_level_id = String(workday.get("id", "WORKDAY-001"))
	# 工作日配置定义的是该关卡最早可出现的日期，不能覆盖存档中已经推进的日期。
	# 否则进入下一天主场景时，WORKDAY-001 会把 day_number 从 2 写回 1，
	# 夜间地图便会误判为同一天并保留已经用尽的行动次数。
	day_number = maxi(day_number, int(workday.get("day_number", 1)))
	target_case_count = workday.get("case_ids", []).size()
	report_title = String(workday.get("report_title", "工作日处理回执"))
	workday_duration = float(workday.get("duration_seconds", 180))
	machine_capacity = maxi(1, int(workday.get("machine_capacity", 2)))
	seconds_remaining = workday_duration
	base_salary = int(workday.get("base_salary", 0))
	living_expenses = workday.get("living_expenses", {}).duplicate(true)
	if records.is_empty():
		decision_by_case_id.clear()


# 将一份申请的处理结果追加到当日记录。
# case_data 为原始案件字典，stamp_type 为处理决策（通常为“批准”或“驳回”）。
# 会对缺失字段使用默认值（未标明部门 / 未编号事项 / 身份记录受限 / 事项内容受限），并设置 submitted 为 true、effective 为 false。
# 记录一份案件的处理结果（简化版，无程序错误与耗时）。
func record_case(case_data: Dictionary, stamp_type: String) -> void:
	record_case_result(case_data, stamp_type, [], 0.0, [])


# 记录一份案件的处理结果，包括决策、程序错误、耗时与已装袋材料。
# 根据规则评估判断是否决策正确，并应用对应的后果（绩效、罚款、政治信用等）。
func record_case_result(case_data: Dictionary, stamp_type: String, procedure_errors: Array, elapsed_seconds: float, packed_document_ids: Array) -> void:
	var evaluation: Dictionary = ConfigDatabase.evaluate_gameplay_case(case_data) if case_data.has("rule_ids") else {"decision": String(case_data.get("correct_decision", stamp_type)), "violation_ids": []}
	var correct := stamp_type == String(evaluation.get("decision", "")) and procedure_errors.is_empty()
	var consequence_id := String(case_data.get("consequence_correct_id" if correct else "consequence_wrong_id", ""))
	var consequence := ConfigDatabase.get_ontology("consequences", consequence_id)
	records.append({
		"case_id": String(case_data.get("case_id", "")),
		"character_id": String(case_data.get("character_id", "")),
		"department": String(case_data.get("department", "未标明部门")),
		"code": String(case_data.get("code", "未编号事项")),
		"applicant": String(case_data.get("applicant", "身份记录受限")),
		"request": String(case_data.get("request", "事项内容受限")),
		"decision": stamp_type,
		"correct_decision": evaluation.get("decision", ""),
		"correct": correct,
		"violation_ids": evaluation.get("violation_ids", []),
		"procedure_errors": procedure_errors.duplicate(),
		"packed_document_ids": packed_document_ids.duplicate(),
		"elapsed_seconds": elapsed_seconds,
		"performance": int(consequence.get("performance", 0)),
		"fine": int(consequence.get("fine", 0)),
		"political_credit": int(consequence.get("political_credit", 0)),
		"consequence_id": consequence_id,
		"submitted": true,
		"effective": false
	})
	var recorded: Dictionary = records[-1]
	archived_cases.append({
		"archive_id": "ARCHIVE-%05d" % next_archive_serial,
		"case_id": recorded.case_id,
		"character_id": recorded.character_id,
		"applicant": recorded.applicant,
		"request": recorded.request,
		"decision": recorded.decision,
		"procedure_errors": recorded.procedure_errors.duplicate(),
		"archived_day": day_number,
		"waiting_days": 0,
		"status": "ARCHIVED",
		"loaded": false,
		"effective_day": 0,
	})
	next_archive_serial += 1
	var delay_days := int(consequence.get("delay_days", 0))
	if delay_days > 0:
		delayed_consequences.append({"due_day": day_number + delay_days, "case_id": case_data.get("case_id", ""), "consequence_id": consequence_id})
	political_credit += int(consequence.get("political_credit", 0))
	var case_id := String(case_data.get("case_id", ""))
	if not case_id.is_empty():
		decision_by_case_id[case_id] = stamp_type
	if persistence_enabled:
		save_progress()


# 每帧推进工作倒计时，秒数不会低于 0。
func tick(delta: float) -> void:
	seconds_remaining = maxf(0.0, seconds_remaining - delta)


# 判断当日工作时长是否已耗尽。
func is_time_up() -> bool:
	return seconds_remaining <= 0.0


# 计算当前工作日的结算（日薪、绩效、罚款、生活支出与净结余）。
func get_settlement() -> Dictionary:
	var performance := 0
	var fines := 0
	for record in records:
		performance += int(record.get("performance", 0))
		fines += int(record.get("fine", 0))
	var expenses := 0
	for amount in living_expenses.values():
		expenses += int(amount)
	return {
		"base_salary": base_salary,
		"performance": performance,
		"fines": fines,
		"living_expenses": expenses,
		"net": base_salary + performance - fines - expenses,
		"balance_after": balance + base_salary + performance - fines - expenses,
		"political_evaluation": "受到关注" if political_credit < 0 else "评价稳定",
	}


# 判断当前工作日是否已积累足够案件以触发日报场景。
# 当 records 数量达到 CASES_PER_DAY（3 件）时返回 true。
func should_show_report() -> bool:
	return records.size() >= target_case_count


# 查询指定案件在本工作日的玩家决策。
func get_case_decision(case_id: String) -> String:
	return String(decision_by_case_id.get(case_id, ""))


func get_pending_archives() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for archive in archived_cases:
		if String(archive.get("status", "ARCHIVED")) != "EFFECTIVE":
			pending.append(archive)
	return pending


func validate_archive_batch(archive_ids: Array) -> bool:
	if archive_ids.is_empty() or archive_ids.size() > machine_capacity:
		return false
	var selected := {}
	for archive_id in archive_ids:
		selected[archive_id] = true
	for archive in archived_cases:
		if selected.has(String(archive.get("archive_id", ""))) and String(archive.get("status", "ARCHIVED")) == "EFFECTIVE":
			return false
	for archive in archived_cases:
		if not selected.has(String(archive.get("archive_id", ""))):
			continue
		archive.status = "EFFECTIVE"
		archive.loaded = false
		archive.effective_day = day_number
		for record in records:
			if String(record.get("case_id", "")) == String(archive.get("case_id", "")):
				record.effective = true
	if persistence_enabled:
		save_progress()
	return true


# 遍历当日记录并生成统计摘要。
# 统计字段包括 reviewed（已审查数）、submitted（已送交数）、approved（批准数）、rejected（驳回数）、returned（退回补正数，当前固定 0）、
# effective（已取得现实效力数）与 pending（等待设施处理数）。返回的字典供日报界面使用。
func get_summary() -> Dictionary:
	var approved := 0
	var rejected := 0
	var effective := 0
	var procedure_errors := 0
	for record in records:
		if record.decision == "批准":
			approved += 1
		elif record.decision == "驳回":
			rejected += 1
		if record.effective:
			effective += 1
		procedure_errors += record.get("procedure_errors", []).size()
	return {
		"reviewed": records.size(),
		"submitted": records.size(),
		"approved": approved,
		"rejected": rejected,
		"returned": 0,
		"effective": effective,
		"pending": records.size() - effective
		,"procedure_errors": procedure_errors
	}


# 进入下一工作日。
# 将 day_number 加 1，并清空 records 数组，准备接收新一天的案件。
# 进入下一工作日：更新余额并清空当日记录。
func begin_next_day() -> void:
	var completed_day := day_number
	settle_current_day()
	for archive in archived_cases:
		if String(archive.get("status", "ARCHIVED")) != "EFFECTIVE":
			archive.waiting_days = int(archive.get("waiting_days", 0)) + 1
	day_number += 1
	records.clear()
	# 跨日时立即建立新一天的夜间额度，避免主场景或存档恢复期间短暂携带昨日的 0 次行动。
	evening_day_number = day_number
	evening_actions_remaining = 2
	evening_location_id = "LOCATION-OFFICE"
	process_due_personal_forms()
	prepare_new_workday()
	if persistence_enabled:
		create_checkpoint(completed_day)


# 初始化当前工作日的夜间地图状态。重复进入同一天地图时保留行动次数与当前位置。
func begin_evening() -> void:
	settle_current_day()
	if evening_day_number != day_number:
		evening_day_number = day_number
		evening_actions_remaining = 2
		evening_location_id = "LOCATION-OFFICE"
	if persistence_enabled:
		save_progress()


# 将日报中的日薪、绩效、罚款与生活支出结算到余额，同一天最多执行一次。
func settle_current_day() -> void:
	if settled_day_number == day_number:
		return
	balance = int(get_settlement().balance_after)
	settled_day_number = day_number


# 购买一份配置定义的空白个人表单，成功时扣除工本费并生成唯一库存条目。
func purchase_personal_form(form_type_id: String) -> bool:
	var form := ConfigDatabase.get_ontology("personal_forms", form_type_id)
	if form.is_empty():
		return false
	var fee := int(form.get("fee", 0))
	if balance < fee:
		return false
	balance -= fee
	personal_form_inventory.append({
		"inventory_id": "INV-%02d-%04d" % [day_number, next_inventory_serial],
		"form_type_id": form_type_id,
		"status": String(form.get("status_on_purchase", "blank")),
		"acquired_day": day_number,
		"version": String(form.get("version", "01")),
	})
	next_inventory_serial += 1
	if persistence_enabled:
		save_progress()
	return true


# 返回档案袋中指定表单类型的持有数量，可按状态筛选。
func get_personal_form_count(form_type_id: String, status := "") -> int:
	var count := 0
	for item in personal_form_inventory:
		if String(item.get("form_type_id", "")) == form_type_id and (status.is_empty() or String(item.get("status", "")) == status):
			count += 1
	return count


# 将档案袋中的第一份指定空白表单填写并送交。
func submit_personal_form(form_type_id: String, fields: Dictionary) -> bool:
	var form := ConfigDatabase.get_ontology("personal_forms", form_type_id)
	if form.is_empty():
		return false
	var required_fields: Array = form.get(
		"required_fields",
		["applicant_name", "residence", "request_reason"]
	)
	for field in required_fields:
		if String(fields.get(field, "")).strip_edges().is_empty():
			return false
	for item in personal_form_inventory:
		if String(item.get("form_type_id", "")) != form_type_id or String(item.get("status", "")) != "blank":
			continue
		item.status = "pending"
		item.fields = fields.duplicate(true)
		item.submitted_day = day_number
		item.effective_day = day_number + int(form.get("effective_delay_days", 1))
		item.fulfillment_id = String(form.get("fulfillment_id", ""))
		item.memory_clue_id = String(form.get("memory_clue_id", ""))
		if persistence_enabled:
			save_progress()
		return true
	return false


# 返回档案袋中的空白表单条目，供申请局生成可提交目录。
func get_blank_personal_forms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in personal_form_inventory:
		if String(item.get("status", "")) == "blank":
			result.append(item)
	return result


# 审核到期的个人表单。饮水表字段与登记身份一致时核发，否则退回补正。
func process_due_personal_forms() -> void:
	last_personal_review_results.clear()
	for item in personal_form_inventory:
		if String(item.get("status", "")) != "pending" or int(item.get("effective_day", 999999)) > day_number:
			continue
		var form_type_id := String(item.get("form_type_id", ""))
		var fields: Dictionary = item.get("fields", {})
		var form := ConfigDatabase.get_ontology("personal_forms", form_type_id)
		var required_fields: Array = form.get("required_fields", [])
		var approved := bool(fields.get("truth_declared", false))
		for field in required_fields:
			approved = approved and not String(fields.get(field, "")).strip_edges().is_empty()
		if form_type_id == "PERSONAL-FORM-WATER-R01":
			approved = (
				approved
				and (player_name.is_empty() or String(fields.get("applicant_name", "")) == player_name)
				and String(fields.get("residence", "")).contains("12-C")
			)
		item.status = "effective" if approved else "returned"
		item.processed_day = day_number
		item.review_result = "批准" if approved else "退回补正"
		if approved and form_type_id == "PERSONAL-FORM-WATER-R01":
			water_covered_until_day = maxi(water_covered_until_day, day_number + int(form.get("valid_for_days", 1)) - 1)
		else:
			item.review_reason = "申请人身份、登记住所、申请事由或真实性声明不符合记录"
		last_personal_review_results.append({
			"inventory_id": item.get("inventory_id", ""),
			"form_type_id": form_type_id,
			"result": item.review_result,
			"reason": item.get("review_reason", "记录核验通过"),
		})


# 根据饮水保障状态准备新工作日，缺水会缩短时间并降低拖拽响应。
func prepare_new_workday() -> void:
	water_deprived = day_number > water_covered_until_day
	var time_penalty := 20.0 if water_deprived else 0.0
	seconds_remaining = maxf(60.0, workday_duration - time_penalty)


func get_drag_response_multiplier() -> float:
	return 0.72 if water_deprived else 1.0


func get_personal_review_summary() -> Dictionary:
	if last_personal_review_results.is_empty():
		return {
			"result": "未收到有效申请",
			"detail": "本周期饮水配额未获续接。",
			"water_deprived": water_deprived,
		}
	var latest: Dictionary = last_personal_review_results[-1]
	return {
		"result": String(latest.get("result", "等待处理")),
		"detail": "饮水配额已核发至第 %02d 工作日。" % water_covered_until_day if latest.get("result") == "批准" else String(latest.get("reason", "退回补正")),
		"water_deprived": water_deprived,
	}


# 在抵达地点后登记一次夜间行动。回家始终可达，行动数不会低于零。
func arrive_at_evening_location(location_id: String) -> void:
	evening_location_id = location_id
	if evening_actions_remaining > 0:
		evening_actions_remaining -= 1
	if persistence_enabled:
		save_progress()


# 判断是否存在可加载的存档文件。
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


# 返回全部不可变时间线节点。旧版单存档会在此处自动迁移。
func get_checkpoint_nodes() -> Array[Dictionary]:
	var document := _read_or_migrate_document()
	var result: Array[Dictionary] = []
	for node in document.get("nodes", []):
		if node is Dictionary:
			result.append(node.duplicate(true))
	return result


# 读取存档选择页所需的当前临时进度摘要，不改变运行状态。
func get_save_summary() -> Dictionary:
	var document := _read_or_migrate_document()
	if document.is_empty():
		return {}
	var state: Dictionary = document.get("working_state", {})
	var modified := int(document.get("updated_at", FileAccess.get_modified_time(save_path)))
	var datetime := Time.get_datetime_dict_from_unix_time(modified)
	return {
		"day_number": maxi(1, int(state.get("day_number", 1))),
		"player_name": String(state.get("player_name", "")),
		"date": "%02d/%02d" % [datetime.month, datetime.day],
		"time": "%02d:%02d" % [datetime.hour, datetime.minute],
	}


# 删除整棵工作档案树。
func delete_save() -> bool:
	if not has_save():
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path)) == OK


# 创建 Opening 完成后的“一开始”根节点。
func create_initial_checkpoint() -> bool:
	var document := {
		"version": SAVE_TREE_VERSION,
		"nodes": [],
		"active_checkpoint_id": "",
		"working_state": _capture_state(),
		"updated_at": int(Time.get_unix_time_from_system()),
	}
	var root_id := _new_checkpoint_id(0)
	document.nodes.append(_make_checkpoint(root_id, "", 0, 0))
	document.active_checkpoint_id = root_id
	active_checkpoint_id = root_id
	return _write_document_atomic(document)


# 将刚完成的一天保存为当前节点的新子节点。已有同日子节点不会被覆盖。
func create_checkpoint(completed_day: int) -> bool:
	var document := _read_or_migrate_document()
	if document.is_empty():
		document = {
			"version": SAVE_TREE_VERSION,
			"nodes": [],
			"active_checkpoint_id": "",
			"working_state": {},
		}
	var parent_id := active_checkpoint_id
	if parent_id.is_empty():
		parent_id = String(document.get("active_checkpoint_id", ""))
	var sibling_count := 0
	for node in document.get("nodes", []):
		if String(node.get("parent_id", "")) == parent_id:
			sibling_count += 1
	var node_id := _new_checkpoint_id(completed_day)
	document.nodes.append(_make_checkpoint(node_id, parent_id, completed_day, sibling_count))
	document.active_checkpoint_id = node_id
	document.working_state = _capture_state()
	document.updated_at = int(Time.get_unix_time_from_system())
	active_checkpoint_id = node_id
	return _write_document_atomic(document)


# 从指定历史节点恢复，并将其设为后续新分支的父节点。
func load_checkpoint(node_id: String) -> bool:
	var document := _read_or_migrate_document()
	for node in document.get("nodes", []):
		if String(node.get("node_id", "")) != node_id:
			continue
		var state = node.get("state", {})
		if not state is Dictionary or state.is_empty():
			return false
		_apply_state(state)
		active_checkpoint_id = node_id
		document.active_checkpoint_id = node_id
		document.working_state = _capture_state()
		document.updated_at = int(Time.get_unix_time_from_system())
		persistence_enabled = true
		return _write_document_atomic(document)
	return false


# 删除选中节点及全部后代；“一开始”根节点不可删除。
func delete_checkpoint(node_id: String) -> bool:
	var document := _read_or_migrate_document()
	var target: Dictionary = {}
	for node in document.get("nodes", []):
		if String(node.get("node_id", "")) == node_id:
			target = node
			break
	if target.is_empty() or int(target.get("completed_day", 0)) == 0:
		return false
	var deleting := {node_id: true}
	var changed := true
	while changed:
		changed = false
		for node in document.get("nodes", []):
			var id := String(node.get("node_id", ""))
			if not deleting.has(id) and deleting.has(String(node.get("parent_id", ""))):
				deleting[id] = true
				changed = true
	var kept: Array = []
	for node in document.get("nodes", []):
		if not deleting.has(String(node.get("node_id", ""))):
			kept.append(node)
	document.nodes = kept
	if deleting.has(String(document.get("active_checkpoint_id", ""))):
		var parent_id := String(target.get("parent_id", ""))
		document.active_checkpoint_id = parent_id
		active_checkpoint_id = parent_id
		for node in kept:
			if String(node.get("node_id", "")) == parent_id:
				document.working_state = node.get("state", {}).duplicate(true)
				break
	document.updated_at = int(Time.get_unix_time_from_system())
	return _write_document_atomic(document)


# 开始新游戏：重置所有状态并删除旧存档。
func start_new_game() -> void:
	day_number = 1
	records.clear()
	current_level_id = "day_1"
	target_case_count = CASES_PER_DAY
	report_title = "工作日处理回执"
	player_name = ""
	reinstatement_date = ""
	player_signature.clear()
	decision_by_case_id.clear()
	balance = 0
	political_credit = 0
	delayed_consequences.clear()
	settled_day_number = 0
	machine_capacity = 2
	archived_cases.clear()
	next_archive_serial = 1
	evening_day_number = 0
	evening_actions_remaining = 2
	evening_location_id = "LOCATION-OFFICE"
	personal_form_inventory.clear()
	next_inventory_serial = 1
	water_covered_until_day = 1
	water_deprived = false
	last_personal_review_results.clear()
	active_checkpoint_id = ""
	persistence_enabled = true
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# 将当前状态捕获为可独立恢复的完整快照。
func _capture_state() -> Dictionary:
	return {
		"day_number": day_number,
		"records": records,
		"current_level_id": current_level_id,
		"target_case_count": target_case_count,
		"report_title": report_title,
		"player_name": player_name,
		"reinstatement_date": reinstatement_date,
		"player_signature": player_signature,
		"decision_by_case_id": decision_by_case_id,
		"balance": balance,
		"political_credit": political_credit,
		"delayed_consequences": delayed_consequences,
		"settled_day_number": settled_day_number,
		"machine_capacity": machine_capacity,
		"archived_cases": archived_cases,
		"next_archive_serial": next_archive_serial,
		"evening_day_number": evening_day_number,
		"evening_actions_remaining": evening_actions_remaining,
		"evening_location_id": evening_location_id,
		"personal_form_inventory": personal_form_inventory,
		"next_inventory_serial": next_inventory_serial,
		"water_covered_until_day": water_covered_until_day,
		"water_deprived": water_deprived,
		"last_personal_review_results": last_personal_review_results,
	}


func save_progress() -> bool:
	var document := _read_or_migrate_document()
	if document.is_empty():
		document = {
			"version": SAVE_TREE_VERSION,
			"nodes": [],
			"active_checkpoint_id": active_checkpoint_id,
		}
	document.version = SAVE_TREE_VERSION
	document.active_checkpoint_id = active_checkpoint_id
	document.working_state = _capture_state()
	document.updated_at = int(Time.get_unix_time_from_system())
	return _write_document_atomic(document)


# 载入最近一次临时进度。
func load_progress() -> bool:
	var document := _read_or_migrate_document()
	if document.is_empty():
		return false
	var state = document.get("working_state", {})
	if not state is Dictionary or state.is_empty():
		return false
	_apply_state(state)
	active_checkpoint_id = String(document.get("active_checkpoint_id", ""))
	if decision_by_case_id.is_empty():
		for record in records:
			var saved_case_id := String(record.get("case_id", ""))
			if not saved_case_id.is_empty():
				decision_by_case_id[saved_case_id] = String(record.get("decision", ""))
	persistence_enabled = true
	return true


func _apply_state(state: Dictionary) -> void:
	day_number = maxi(1, int(state.get("day_number", 1)))
	records.assign(state.get("records", []))
	current_level_id = String(state.get("current_level_id", "day_1"))
	target_case_count = maxi(1, int(state.get("target_case_count", CASES_PER_DAY)))
	report_title = String(state.get("report_title", "工作日处理回执"))
	player_name = String(state.get("player_name", ""))
	reinstatement_date = String(state.get("reinstatement_date", ""))
	player_signature = state.get("player_signature", []).duplicate(true)
	decision_by_case_id = state.get("decision_by_case_id", {}).duplicate()
	balance = int(state.get("balance", 0))
	political_credit = int(state.get("political_credit", 0))
	delayed_consequences.assign(state.get("delayed_consequences", []))
	settled_day_number = int(state.get("settled_day_number", 0))
	machine_capacity = maxi(1, int(state.get("machine_capacity", 2)))
	archived_cases.assign(state.get("archived_cases", []))
	next_archive_serial = maxi(1, int(state.get("next_archive_serial", archived_cases.size() + 1)))
	evening_day_number = int(state.get("evening_day_number", 0))
	evening_actions_remaining = clampi(int(state.get("evening_actions_remaining", 2)), 0, 2)
	evening_location_id = String(state.get("evening_location_id", "LOCATION-OFFICE"))
	personal_form_inventory.assign(state.get("personal_form_inventory", []))
	next_inventory_serial = maxi(1, int(state.get("next_inventory_serial", personal_form_inventory.size() + 1)))
	water_covered_until_day = int(state.get("water_covered_until_day", 1))
	water_deprived = bool(state.get("water_deprived", false))
	last_personal_review_results.assign(state.get("last_personal_review_results", []))


func _make_checkpoint(node_id: String, parent_id: String, completed_day: int, branch_order: int) -> Dictionary:
	return {
		"node_id": node_id,
		"parent_id": parent_id,
		"completed_day": completed_day,
		"branch_order": branch_order,
		"created_at": int(Time.get_unix_time_from_system()),
		"player_name": player_name,
		"state": _capture_state(),
	}


func _new_checkpoint_id(completed_day: int) -> String:
	return "day-%02d-%d" % [completed_day, Time.get_ticks_usec()]


func _read_or_migrate_document() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	if int(parsed.get("version", 1)) >= SAVE_TREE_VERSION and parsed.has("nodes"):
		if active_checkpoint_id.is_empty():
			active_checkpoint_id = String(parsed.get("active_checkpoint_id", ""))
		return parsed
	return _migrate_legacy_document(parsed)


func _migrate_legacy_document(legacy: Dictionary) -> Dictionary:
	var legacy_day := maxi(1, int(legacy.get("day_number", 1)))
	var completed_day := maxi(0, legacy_day - 1)
	var root_state := legacy.duplicate(true)
	root_state.day_number = 1
	root_state.records = []
	root_state.settled_day_number = 0
	root_state.evening_day_number = 0
	root_state.evening_actions_remaining = 2
	var root_id := _new_checkpoint_id(0)
	var root_node := {
		"node_id": root_id,
		"parent_id": "",
		"completed_day": 0,
		"branch_order": 0,
		"created_at": int(FileAccess.get_modified_time(save_path)),
		"player_name": String(legacy.get("player_name", "")),
		"state": root_state,
	}
	var nodes: Array = [root_node]
	var active_id := root_id
	if completed_day > 0:
		active_id = _new_checkpoint_id(completed_day)
		nodes.append({
			"node_id": active_id,
			"parent_id": root_id,
			"completed_day": completed_day,
			"branch_order": 0,
			"created_at": int(FileAccess.get_modified_time(save_path)),
			"player_name": String(legacy.get("player_name", "")),
			"state": legacy.duplicate(true),
		})
	var document := {
		"version": SAVE_TREE_VERSION,
		"nodes": nodes,
		"active_checkpoint_id": active_id,
		"working_state": legacy.duplicate(true),
		"updated_at": int(Time.get_unix_time_from_system()),
	}
	active_checkpoint_id = active_id
	_write_document_atomic(document)
	return document


func _write_document_atomic(document: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(save_path)
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("无法写入临时存档：%s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(document))
	file.close()
	var verify := FileAccess.open(temporary, FileAccess.READ)
	if verify == null or not JSON.parse_string(verify.get_as_text()) is Dictionary:
		DirAccess.remove_absolute(temporary)
		return false
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(absolute):
		if DirAccess.rename_absolute(absolute, backup) != OK:
			DirAccess.remove_absolute(temporary)
			return false
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, absolute)
		return false
	return true


# 修复 v5 及更早版本可能产生的跨日卡死存档：
# 当日案件已经全部完成并结算，但日期仍停留在行动耗尽的同一夜晚。
func repair_legacy_exhausted_evening(save_version: int) -> bool:
	if (
		save_version > 5
		or evening_actions_remaining > 0
		or evening_day_number != day_number
		or settled_day_number != day_number
		or records.size() < target_case_count
	):
		return false
	day_number += 1
	records.clear()
	evening_day_number = day_number
	evening_actions_remaining = 2
	evening_location_id = "LOCATION-OFFICE"
	process_due_personal_forms()
	prepare_new_workday()
	return true


# 测试与调试辅助方法。
# 将 day_number 重置为 1 并清空 records，恢复游戏到初始状态。
func reset_for_tests() -> void:
	day_number = 1
	records.clear()
	current_level_id = "day_1"
	target_case_count = CASES_PER_DAY
	report_title = "工作日处理回执"
	player_name = ""
	reinstatement_date = ""
	player_signature.clear()
	decision_by_case_id.clear()
	workday_duration = 180.0
	seconds_remaining = workday_duration
	base_salary = 0
	living_expenses.clear()
	balance = 0
	political_credit = 0
	delayed_consequences.clear()
	settled_day_number = 0
	machine_capacity = 2
	archived_cases.clear()
	next_archive_serial = 1
	evening_day_number = 0
	evening_actions_remaining = 2
	evening_location_id = "LOCATION-OFFICE"
	personal_form_inventory.clear()
	next_inventory_serial = 1
	water_covered_until_day = 1
	water_deprived = false
	last_personal_review_results.clear()
	persistence_enabled = false
