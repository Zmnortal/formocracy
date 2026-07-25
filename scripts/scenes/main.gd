extends Node2D

# 主工作台场景只负责 Godot 生命周期；全部玩法功能统一委托给 WorkbenchManager。

var manager: WorkbenchManager


func _ready() -> void:
	manager = WorkbenchManager.new(self)
	manager.start()


func _process(delta: float) -> void:
	if manager != null:
		manager.process(delta)


# 把未命中任何交互控件的点击交给工作台，用于收起文件袋或立起文件。
func _unhandled_input(event: InputEvent) -> void:
	if manager != null:
		manager.handle_unhandled_input(event)


func _exit_tree() -> void:
	if manager != null:
		manager.shutdown()
