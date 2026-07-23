extends Node

const CASES_PER_DAY := 3

var day_number := 1
var records: Array[Dictionary] = []


func record_case(case_data: Dictionary, stamp_type: String) -> void:
	records.append({
		"department": String(case_data.get("department", "未标明部门")),
		"code": String(case_data.get("code", "未编号事项")),
		"applicant": String(case_data.get("applicant", "身份记录受限")),
		"request": String(case_data.get("request", "事项内容受限")),
		"decision": stamp_type,
		"submitted": true,
		"effective": false
	})


func should_show_report() -> bool:
	return records.size() >= CASES_PER_DAY


func get_summary() -> Dictionary:
	var approved := 0
	var rejected := 0
	var effective := 0
	for record in records:
		if record.decision == "批准":
			approved += 1
		elif record.decision == "驳回":
			rejected += 1
		if record.effective:
			effective += 1
	return {
		"reviewed": records.size(),
		"submitted": records.size(),
		"approved": approved,
		"rejected": rejected,
		"returned": 0,
		"effective": effective,
		"pending": records.size() - effective
	}


func begin_next_day() -> void:
	day_number += 1
	records.clear()


func reset_for_tests() -> void:
	day_number = 1
	records.clear()
