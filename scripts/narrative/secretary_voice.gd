class_name SecretaryVoice
extends RefCounted

# 广播、眼镜与流程提示共享同一名说话人，避免界面把秘书重新伪装成无人格系统。
const ID := "SECRETARY"
const NAME := "秘书"
const KIND := "secretary"


# 生成每日简报的第一句：先报工作信息，再留一点克制的人情味。
static func morning_opening(day_number: int) -> String:
	return "早上好。第十二区，第 %02d 工作日。您的工位已经准备好了——至少它看起来是。" % day_number


# 生成晨间简报结束提示。
static func briefing_complete() -> String:
	return "简报到这里。请按下召唤铃，请第一位申请人进来——别让他们以为铃坏了。"


# 生成召唤下一位申请人的固定提示。
static func call_next() -> String:
	return "下一位。请让申请人进来——走廊已经替我们排好了。"


# 生成夜间窗口关闭提示。
static func night_close() -> String:
	return "第十二区夜间窗口已经关闭。该回登记住所了——今天的表格不会趁您不在自己变少。"


# 生成简报配置缺失时仍可执行的兜底提示。
static func missing_briefing() -> String:
	return "今天的流程配置没有送到。我会继续找；您先按铃开始工作。"


# 生成简报读取失败时的兜底提示。
static func unreadable_briefing() -> String:
	return "今天的简报打不开。请先按铃开始工作——我暂时不把责任写在您名下。"
