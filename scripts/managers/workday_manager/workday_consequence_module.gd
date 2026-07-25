class_name WorkdayConsequenceModule
extends RefCounted

# 记录案件后果、政治信用和延迟问责，并负责外部后果反馈。

var state: WorkdayContext
var config: WorkdayConfigGateway


# 记录所属的工作日状态引用。
func _init(owner_state: WorkdayContext, config_gateway: WorkdayConfigGateway) -> void:
	state = owner_state
	config = config_gateway


# 评估决策正误并生成案件记录，应用政治信用与延迟问责后果。
func record_case_result(
	case_data: Dictionary, stamp_type: String, procedure_errors: Array, elapsed_seconds: float, packed_document_ids: Array, document_stamps: Array, envelope_snapshot: Dictionary
) -> Dictionary:
	var evaluation: Dictionary = (
		config.evaluate_gameplay_case(case_data)
		if case_data.has("rule_ids")
		else {
			"decision": WorkdayContext.read_string(case_data, "correct_decision", stamp_type),
			"violation_ids": [],
		}
	)
	var correct := stamp_type == WorkdayContext.read_string(evaluation, "decision") and procedure_errors.is_empty()
	var consequence_id := WorkdayContext.read_string(case_data, "consequence_correct_id" if correct else "consequence_wrong_id", "")
	var consequence := config.get_ontology("consequences", consequence_id)
	var record := {
		"case_id": WorkdayContext.read_string(case_data, "case_id"),
		"character_id": WorkdayContext.read_string(case_data, "character_id"),
		"department": WorkdayContext.read_string(case_data, "department", "未标明部门"),
		"code": WorkdayContext.read_string(case_data, "code", "未编号事项"),
		"applicant": WorkdayContext.read_string(case_data, "applicant", "身份记录受限"),
		"request": WorkdayContext.read_string(case_data, "request", "事项内容受限"),
		"decision": stamp_type,
		"correct_decision": evaluation.get("decision", ""),
		"correct": correct,
		"violation_ids": evaluation.get("violation_ids", []),
		"procedure_errors": procedure_errors.duplicate(),
		"packed_document_ids": packed_document_ids.duplicate(),
		"envelope_snapshot": envelope_snapshot.duplicate(true),
		"document_stamps": document_stamps.duplicate(true),
		"elapsed_seconds": elapsed_seconds,
		"performance": WorkdayContext.read_int(consequence, "performance"),
		"fine": WorkdayContext.read_int(consequence, "fine"),
		"political_credit": WorkdayContext.read_int(consequence, "political_credit"),
		"consequence_id": consequence_id,
		"submitted": true,
		"effective": false,
	}
	state.records.append(record)
	var delay_days := WorkdayContext.read_int(consequence, "delay_days")
	if delay_days > 0:
		(
			state
			. delayed_consequences
			. append(
				{
					"due_day": state.day_number + delay_days,
					"case_id": WorkdayContext.read_string(case_data, "case_id"),
					"consequence_id": consequence_id,
				}
			)
		)
	state.political_credit += WorkdayContext.read_int(consequence, "political_credit")
	var case_id := WorkdayContext.read_string(case_data, "case_id")
	if not case_id.is_empty():
		state.decision_by_case_id[case_id] = stamp_type
	return record


# 汇总记录列表中的政治信用变化总和。
func get_credit_delta(records: Array[Dictionary]) -> int:
	var credit_delta := 0
	for record in records:
		credit_delta += WorkdayContext.read_int(record, "political_credit")
	return credit_delta


# 当存在罚款或信用下降时，向 RealityBridge 发送工作日后果通知。
func send_workday_consequences(completed_day: int, settlement: Dictionary, credit_delta: int) -> void:
	var fines := WorkdayContext.read_int(settlement, "fines")
	if fines <= 0 and credit_delta >= 0:
		return
	var bridge := state.get_tree().root.get_node_or_null("RealityBridge")
	if bridge == null:
		return
	(
		bridge
		. call(
			"consequence",
			"第 %02d 工作日 · 后果回流" % completed_day,
			(
				"行政罚款：-%d\n政治信用：%+d\n系统评价：%s"
				% [
					fines,
					credit_delta,
					WorkdayContext.read_string(settlement, "political_evaluation", "评价稳定"),
				]
			),
			"critical" if fines >= 100 or credit_delta <= -3 else "warning"
		)
	)


# 发送已到期的延迟问责通知，并保留未到期项。
func send_due_delayed_consequences() -> void:
	var bridge := state.get_tree().root.get_node_or_null("RealityBridge")
	var remaining: Array[Dictionary] = []
	for item in state.delayed_consequences:
		if WorkdayContext.read_int(item, "due_day", 999999) > state.day_number:
			remaining.append(item)
			continue
		if bridge != null:
			(
				bridge
				. call(
					"consequence",
					"延迟问责已生效",
					(
						"案件 %s 的现实后果已于第 %02d 工作日写入记录。"
						% [
							WorkdayContext.read_string(item, "case_id", "未编号事项"),
							state.day_number,
						]
					),
					"critical"
				)
			)
	state.delayed_consequences.assign(remaining)
