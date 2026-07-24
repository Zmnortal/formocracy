class_name DocumentBackground
extends TextureRect

# 通用行政文书底板。业务页面只负责在安全区域内叠加动态内容。

const DOCUMENT_TEXTURE := preload("res://assets/documents/common_document_bg.png")
const SAFE_MARGIN := Vector4(56.0, 52.0, 56.0, 58.0)


# 节点就绪时应用底板贴图与显示参数。
func _ready() -> void:
	configure()


# 设置文书底板贴图、拉伸模式、最近邻过滤并忽略鼠标事件。
func configure() -> void:
	texture = DOCUMENT_TEXTURE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# 在指定位置以指定尺寸创建并配置好的文书底板实例。
static func create(at: Vector2, display_size: Vector2) -> DocumentBackground:
	var paper := DocumentBackground.new()
	paper.position = at
	paper.size = display_size
	paper.configure()
	return paper


# 返回扣除四边安全边距后的内容安全区域矩形。
func get_safe_rect() -> Rect2:
	return Rect2(Vector2(SAFE_MARGIN.x, SAFE_MARGIN.y), size - Vector2(SAFE_MARGIN.x + SAFE_MARGIN.z, SAFE_MARGIN.y + SAFE_MARGIN.w))
