extends Node2D

# 主工作台场景只负责 Godot 生命周期；全部玩法功能统一委托给 WorkbenchManager。

var manager: WorkbenchManager


func _ready() -> void:
	manager = WorkbenchManager.new(self)
	manager.start()


func _process(delta: float) -> void:
	if manager != null:
		manager.process(delta)


func _exit_tree() -> void:
	if manager != null:
		manager.shutdown()
