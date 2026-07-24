class_name WorkbenchCallBellModule
extends RefCounted

signal called

const BELL_TEXTURE := preload("res://assets/office/interactive/call_bell.png")

var root: Node2D
var housing: Control
var button: Button
var bell_image: TextureRect
var indicator: ColorRect
var available := false
var call_count := 0


# 初始化呼叫铃的节点结构、纹理、按钮与指示灯，初始状态为锁定。
func _init(owner_root: Node2D) -> void:
	root = owner_root
	housing = Control.new()
	housing.name = "CallBellHousing"
	housing.position = Vector2(930, 568)
	housing.size = Vector2(72, 78)
	housing.pivot_offset = housing.size / 2.0
	housing.z_index = 48
	root.add_child(housing)

	bell_image = TextureRect.new()
	bell_image.name = "BellAsset"
	bell_image.texture = BELL_TEXTURE
	bell_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bell_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bell_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bell_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	housing.add_child(bell_image)
	bell_image.position = Vector2.ZERO
	bell_image.size = housing.size

	button = Button.new()
	button.name = "CallBell"
	button.text = ""
	button.position = Vector2.ZERO
	button.size = housing.size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var transparent_style := WorkbenchUI.style_box(Color(0, 0, 0, 0), 0)
	button.add_theme_stylebox_override("normal", transparent_style)
	button.add_theme_stylebox_override("hover", transparent_style)
	button.add_theme_stylebox_override("pressed", transparent_style)
	button.add_theme_stylebox_override("disabled", transparent_style)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	housing.add_child(button)

	indicator = ColorRect.new()
	indicator.position = Vector2(31, 65)
	indicator.size = Vector2(9, 6)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	housing.add_child(indicator)
	lock()


# 将呼叫铃注册为桌面可拖拽/可点击实体。
func enable_desk_movement(controller: DeskItemController) -> void:
	controller.register_item(housing, "call_bell", _on_pressed)


# 解锁呼叫铃，允许玩家点击呼叫。
func unlock() -> void:
	available = true
	button.disabled = false
	indicator.color = Color("b8d56a")
	bell_image.modulate = Color.WHITE


# 锁定呼叫铃，防止重复点击。
func lock() -> void:
	available = false
	button.disabled = true
	indicator.color = Color("573f32")
	bell_image.modulate = Color(0.62, 0.62, 0.58, 1.0)


# 触发呼叫铃：锁定、播放音效并发射 called 信号。
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


# 呼叫铃被按下时的动画与触发逻辑。
func _on_pressed() -> void:
	var press := root.create_tween()
	press.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	press.tween_property(housing, "scale", Vector2(1.0, 0.88), 0.07)
	press.tween_property(housing, "scale", Vector2.ONE, 0.12)
	trigger()
