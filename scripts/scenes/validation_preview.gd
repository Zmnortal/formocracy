extends Control


# 场景就绪时连接视口尺寸变化信号，并执行一次窗口适配。
func _ready() -> void:
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


# 以 1280x720 为设计分辨率按实际视口等比例缩放 Control，使其在不同分辨率下铺满全屏。
func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	position = Vector2.ZERO
