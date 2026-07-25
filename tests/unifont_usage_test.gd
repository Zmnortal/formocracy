extends SceneTree

const FONT_RESOURCE := "res://assets/fonts/unifont/unifont_ui.tres"
const PRIMARY_RESOURCE := "res://assets/fonts/unifont/unifont-15.1.04.ttf"
const JAPANESE_RESOURCE := "res://assets/fonts/unifont/unifont_jp-15.1.04.ttf"


func _init() -> void:
	call_deferred("run")


# 验证游戏统一使用 Unifont，并保留日语字形备用链。
func run() -> void:
	var ui_font := load(FONT_RESOURCE) as FontVariation
	assert(ui_font != null, "Unifont UI variation must load")
	assert(ui_font.base_font.resource_path == PRIMARY_RESOURCE, "default Unifont must be the primary UI face")
	assert(ui_font.fallbacks.size() == 1, "Unifont UI face must expose exactly one Japanese fallback")
	assert(ui_font.fallbacks[0].resource_path == JAPANESE_RESOURCE, "Japanese Unifont must be the configured fallback")
	assert((ui_font.base_font as FontFile).antialiasing == TextServer.FONT_ANTIALIASING_NONE, "default Unifont must keep pixel edges without antialiasing")
	assert((ui_font.fallbacks[0] as FontFile).antialiasing == TextServer.FONT_ANTIALIASING_NONE, "Japanese fallback must use the same pixel rendering")
	var theme := load("res://themes/pixel_theme.tres") as Theme
	assert(theme.default_font.resource_path == FONT_RESOURCE, "global project theme must use the unified Unifont resource")
	var old_font_references := _scan_old_font_references()
	assert(old_font_references.is_empty(), "game and UI tools must not retain old Ark Pixel references: %s" % [old_font_references])
	print("FORMOCRACY_UNIFONT_USAGE_TEST_OK")
	quit(0)


# 扫描会影响游戏或界面工具的文本资源；历史说明文档不参与运行时字体约束。
func _scan_old_font_references() -> Array[String]:
	var roots := ["res://scripts", "res://scenes", "res://themes", "res://tools"]
	var matches: Array[String] = []
	for root_path in roots:
		_scan_directory(root_path, matches)
	return matches


func _scan_directory(path: String, matches: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child_path := path.path_join(entry)
		if directory.current_is_dir():
			_scan_directory(child_path, matches)
		elif entry.get_extension() in ["gd", "tscn", "tres", "html", "css"]:
			if FileAccess.get_file_as_string(child_path).contains("assets/fonts/ark_pixel"):
				matches.append(child_path)
		entry = directory.get_next()
	directory.list_dir_end()
