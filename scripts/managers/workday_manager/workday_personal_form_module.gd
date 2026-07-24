class_name WorkdayPersonalFormModule
extends RefCounted

# 管理玩家购买、持有、提交和等待审核的个人表单。

var state: WorkdayContext
var config: WorkdayConfigGateway


# 记录所属的工作日状态引用。
func _init(owner_state: WorkdayContext, config_gateway: WorkdayConfigGateway) -> void:
	state = owner_state
	config = config_gateway


# 购买指定类型的个人表单：扣费并加入库存，余额不足返回 false。
func purchase(form_type_id: String) -> bool:
	var form := config.get_ontology("personal_forms", form_type_id)
	if form.is_empty():
		return false
	var fee := WorkdayContext.read_int(form, "fee")
	if state.balance < fee:
		return false
	state.balance -= fee
	(
		state
		. personal_form_inventory
		. append(
			{
				"inventory_id": "INV-%02d-%04d" % [state.day_number, state.next_inventory_serial],
				"form_type_id": form_type_id,
				"status": WorkdayContext.read_string(form, "status_on_purchase", "blank"),
				"acquired_day": state.day_number,
				"version": WorkdayContext.read_string(form, "version", "01"),
			}
		)
	)
	state.next_inventory_serial += 1
	if state.persistence_enabled:
		state.save_progress()
	return true


# 统计库存中指定类型（可按状态过滤）的表单数量。
func get_count(form_type_id: String, status: String = "") -> int:
	var count := 0
	for item in state.personal_form_inventory:
		if WorkdayContext.read_string(item, "form_type_id") == form_type_id and (status.is_empty() or WorkdayContext.read_string(item, "status") == status):
			count += 1
	return count


# 校验必填字段后提交一张空白表单，进入等待审核状态。
func submit(form_type_id: String, fields: Dictionary) -> bool:
	var form := config.get_ontology("personal_forms", form_type_id)
	if form.is_empty():
		return false
	var required_fields := WorkdayContext.read_array(form, "required_fields", ["applicant_name", "residence", "request_reason"])
	for field: Variant in required_fields:
		if WorkdayContext.read_string(fields, WorkdayContext.stringify_value(field)).strip_edges().is_empty():
			return false
	for item in state.personal_form_inventory:
		if WorkdayContext.read_string(item, "form_type_id") != form_type_id or WorkdayContext.read_string(item, "status") != "blank":
			continue
		item.status = "pending"
		item.fields = fields.duplicate(true)
		item.submitted_day = state.day_number
		item.effective_day = state.day_number + WorkdayContext.read_int(form, "effective_delay_days", 1)
		item.fulfillment_id = WorkdayContext.read_string(form, "fulfillment_id")
		item.memory_clue_id = WorkdayContext.read_string(form, "memory_clue_id")
		if state.persistence_enabled:
			state.save_progress()
		return true
	return false


# 返回库存中所有未填写的空白表单。
func get_blank_forms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in state.personal_form_inventory:
		if WorkdayContext.read_string(item, "status") == "blank":
			result.append(item)
	return result


# 审核所有到期的待处理表单，核发或退回并记录审核结果。
func process_due_forms() -> void:
	state.last_personal_review_results.clear()
	for item in state.personal_form_inventory:
		if WorkdayContext.read_string(item, "status") != "pending" or WorkdayContext.read_int(item, "effective_day", 999999) > state.day_number:
			continue
		var form_type_id := WorkdayContext.read_string(item, "form_type_id")
		var fields := WorkdayContext.read_dictionary(item, "fields")
		var form := config.get_ontology("personal_forms", form_type_id)
		var required_fields := WorkdayContext.read_array(form, "required_fields")
		var approved := WorkdayContext.read_bool(fields, "truth_declared")
		for field: Variant in required_fields:
			approved = (approved and not WorkdayContext.read_string(fields, WorkdayContext.stringify_value(field)).strip_edges().is_empty())
		if form_type_id == "PERSONAL-FORM-WATER-R01":
			approved = (
				approved
				and (state.player_name.is_empty() or WorkdayContext.read_string(fields, "applicant_name") == state.player_name)
				and WorkdayContext.read_string(fields, "residence").contains("12-C")
			)
		item.status = "effective" if approved else "returned"
		item.processed_day = state.day_number
		item.review_result = "批准" if approved else "退回补正"
		if approved and form_type_id == "PERSONAL-FORM-WATER-R01":
			state.water_covered_until_day = maxi(state.water_covered_until_day, state.day_number + WorkdayContext.read_int(form, "valid_for_days", 1) - 1)
		else:
			item.review_reason = "申请人身份、登记住所、申请事由或真实性声明不符合记录"
		(
			state
			. last_personal_review_results
			. append(
				{
					"inventory_id": WorkdayContext.read_string(item, "inventory_id"),
					"form_type_id": form_type_id,
					"result": WorkdayContext.read_string(item, "review_result"),
					"reason": WorkdayContext.read_string(item, "review_reason", "记录核验通过"),
				}
			)
		)


# 返回最近一次个人表单审核结果的摘要信息。
func get_review_summary() -> Dictionary:
	if state.last_personal_review_results.is_empty():
		return {
			"result": "未收到有效申请",
			"detail": "本周期饮水配额未获续接。",
			"water_deprived": state.water_deprived,
		}
	var latest: Dictionary = state.last_personal_review_results[-1]
	return {
		"result": WorkdayContext.read_string(latest, "result", "等待处理"),
		"detail": "饮水配额已核发至第 %02d 工作日。" % state.water_covered_until_day if WorkdayContext.read_string(latest, "result") == "批准" else WorkdayContext.read_string(latest, "reason", "退回补正"),
		"water_deprived": state.water_deprived,
	}
