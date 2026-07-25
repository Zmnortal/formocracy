extends Button

# 文件袋封皮拖拽面只在没有更前方桌面物件时参与 Godot GUI 命中。

var hit_test: Callable


func _has_point(point: Vector2) -> bool:
	if hit_test.is_valid():
		return WorkdayContext.to_bool(hit_test.call(self, point))
	return Rect2(Vector2.ZERO, size).has_point(point)
