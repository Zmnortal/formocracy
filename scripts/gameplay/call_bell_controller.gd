class_name CallBellController
extends RefCounted

signal called

var root: Node2D
var button: Button
var indicator: ColorRect
var available := false
var call_count := 0


func _init(owner_root: Node2D) -> void:
	root = owner_root
	var housing := Panel.new()
	housing.name = "CallBellHousing"
	housing.position = Vector2(910, 478)
	housing.size = Vector2(92, 78)
	housing.z_index = 48
	housing.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color("29251b"), 5, Color("a78a52"), 2)
	)
	root.add_child(housing)
	button = Button.new()
	button.name = "CallBell"
	button.text = "传 唤"
	button.position = Vector2(9, 20)
	button.size = Vector2(74, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_pressed)
	housing.add_child(button)
	indicator = ColorRect.new()
	indicator.position = Vector2(38, 8)
	indicator.size = Vector2(16, 7)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	housing.add_child(indicator)
	lock()


func unlock() -> void:
	available = true
	button.disabled = false
	indicator.color = Color("b8d56a")


func lock() -> void:
	available = false
	button.disabled = true
	indicator.color = Color("573f32")


func trigger(skip_audio := false) -> void:
	if not available:
		return
	lock()
	call_count += 1
	if not skip_audio:
		Sfx.play("call_bell")
		await root.get_tree().create_timer(0.22).timeout
		Sfx.play("call_intercom")
	called.emit()


func _on_pressed() -> void:
	trigger()
