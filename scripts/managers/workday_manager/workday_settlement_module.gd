class_name WorkdaySettlementModule
extends RefCounted

# 计算工作日经济结算和日报统计。

var state: WorkdayContext


# 记录所属的工作日状态引用。
func _init(owner_state: WorkdayContext) -> void:
	state = owner_state


# 计算当日结算明细：底薪、绩效、罚款、生活支出与结余。
func get_settlement() -> Dictionary:
	var performance := 0
	var fines := 0
	for record in state.records:
		performance += WorkdayContext.read_int(record, "performance")
		fines += WorkdayContext.read_int(record, "fine")
	var expenses := 0
	for amount: Variant in state.living_expenses.values():
		expenses += WorkdayContext.to_int(amount)
	return {
		"base_salary": state.base_salary,
		"performance": performance,
		"fines": fines,
		"living_expenses": expenses,
		"net": state.base_salary + performance - fines - expenses,
		"balance_after": state.balance + state.base_salary + performance - fines - expenses,
		"political_evaluation": "受到关注" if state.political_credit < 0 else "评价稳定",
	}


# 将当日结算写入余额；同一天不会重复结算。
func settle_current_day() -> void:
	if state.settled_day_number == state.day_number:
		return
	state.balance = WorkdayContext.read_int(get_settlement(), "balance_after")
	state.settled_day_number = state.day_number


# 判断当日案件是否已全部处理完，可展示日报。
func should_show_report() -> bool:
	return state.records.size() >= state.target_case_count


# 统计当日批准、驳回、生效与程序错误数量的日报摘要。
func get_summary() -> Dictionary:
	var approved := 0
	var rejected := 0
	var effective := 0
	var procedure_errors := 0
	var abnormal_records := 0
	for record in state.records:
		if record.decision == "批准":
			approved += 1
		elif record.decision == "驳回":
			rejected += 1
		if record.effective:
			effective += 1
		var record_errors := WorkdayContext.read_array(record, "procedure_errors")
		procedure_errors += record_errors.size()
		if not record_errors.is_empty():
			abnormal_records += 1
	return {
		"reviewed": state.records.size(),
		"submitted": effective,
		"approved": approved,
		"rejected": rejected,
		"returned": 0,
		"effective": effective,
		"pending": state.records.size() - effective,
		"procedure_errors": procedure_errors,
		"abnormal_records": abnormal_records,
	}
