extends Node

const CASES_PER_DAY := 3

var day_number := 1
var records: Array[Dictionary] = []


# 将一份申请的处理结果追加到当日记录。
# case_data 为原始案件字典，stamp_type 为处理决策（通常为“批准”或“驳回”）。
# 会对缺失字段使用默认值（未标明部门 / 未编号事项 / 身份记录受限 / 事项内容受限），并设置 submitted 为 true、effective 为 false。
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


# 判断当前工作日是否已积累足够案件以触发日报场景。
# 当 records 数量达到 CASES_PER_DAY（3 件）时返回 true。
func should_show_report() -> bool:
	return records.size() >= CASES_PER_DAY


# 遍历当日记录并生成统计摘要。
# 统计字段包括 reviewed（已审查数）、submitted（已送交数）、approved（批准数）、rejected（驳回数）、returned（退回补正数，当前固定 0）、
# effective（已取得现实效力数）与 pending（等待设施处理数）。返回的字典供日报界面使用。
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


# 进入下一工作日。
# 将 day_number 加 1，并清空 records 数组，准备接收新一天的案件。
func begin_next_day() -> void:
	day_number += 1
	records.clear()


# 测试与调试辅助方法。
# 将 day_number 重置为 1 并清空 records，恢复游戏到初始状态。
func reset_for_tests() -> void:
	day_number = 1
	records.clear()
