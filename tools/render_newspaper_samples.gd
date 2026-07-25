extends SceneTree

const CONFIG_PATH := "res://data/narrative/newspapers.json"
const OUTPUT_DIR := "res://output/newspaper-7day-samples/images"
const PAGE_SIZE := Vector2(350, 525)
const OUTPUT_SCALE := 2.0
const FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	assert(parsed is Dictionary, "newspaper configuration must parse")
	var publishers := WorkdayContext.read_array(parsed, "publishers")
	assert(publishers.size() == 4, "sample renderer expects four newspaper publishers")

	var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIR)
	assert(DirAccess.make_dir_recursive_absolute(absolute_output) == OK, "sample output directory must be created")

	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(PAGE_SIZE.x * OUTPUT_SCALE), int(PAGE_SIZE.y * OUTPUT_SCALE))
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var rendered := 0
	for day in range(1, 8):
		for publisher_value: Variant in publishers:
			assert(publisher_value is Dictionary, "publisher entry must be a dictionary")
			var publisher: Dictionary = publisher_value
			var issue := _issue_for_day(publisher, day)
			assert(not issue.is_empty(), "%s day %d issue must exist" % [publisher.get("name", ""), day])
			var page := _build_page(publisher, issue, day)
			viewport.add_child(page)
			await process_frame
			await process_frame
			RenderingServer.force_draw(false)
			var image := viewport.get_texture().get_image()
			assert(not image.is_empty(), "rendered newspaper image must not be empty")
			var filename := "day-%02d-%s.png" % [day, _publisher_slug(publisher)]
			var output_path := "%s/%s" % [absolute_output, filename]
			assert(image.save_png(output_path) == OK, "sample image must save: %s" % output_path)
			rendered += 1
			page.queue_free()
			await process_frame

	assert(rendered == 28, "seven days times four publishers must render 28 samples")
	print("FORMOCRACY_NEWSPAPER_SAMPLES_RENDERED=%d" % rendered)
	print("FORMOCRACY_NEWSPAPER_SAMPLES_DIR=%s" % absolute_output)
	quit(0)


func _build_page(publisher: Dictionary, issue: Dictionary, day: int) -> Control:
	var page := Control.new()
	page.size = PAGE_SIZE
	page.scale = Vector2(OUTPUT_SCALE, OUTPUT_SCALE)
	page.clip_contents = true

	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.texture = load(WorkdayContext.read_string(publisher, "template_asset")) as Texture2D
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(paper)

	var grid := WorkdayContext.read_dictionary(publisher, "reading_grid")
	var edition_color := Color("e8dfc3") if WorkdayContext.read_string(publisher, "id") == "NEWSPAPER-ADMIN-GAZETTE" else Color("25231c")
	var edition := _make_label(
		"%s\n%s" % [
			WorkdayContext.read_string(publisher, "name"),
			WorkdayContext.read_string(publisher, "tagline"),
		],
		WorkdayContext.read_array(grid, "edition"),
		edition_color,
		HORIZONTAL_ALIGNMENT_CENTER,
		VERTICAL_ALIGNMENT_CENTER
	)
	page.add_child(edition)

	var headline := _make_label(
		WorkdayContext.read_string(issue, "headline"),
		WorkdayContext.read_array(grid, "headline"),
		Color("201f19"),
		HORIZONTAL_ALIGNMENT_CENTER,
		VERTICAL_ALIGNMENT_CENTER
	)
	page.add_child(headline)

	var article_columns := _split_article_columns(WorkdayContext.read_string(issue, "article"))
	page.add_child(
		_make_label(
			article_columns[0],
			WorkdayContext.read_array(grid, "article_left"),
			Color("373229"),
			HORIZONTAL_ALIGNMENT_LEFT,
			VERTICAL_ALIGNMENT_TOP
		)
	)
	page.add_child(
		_make_label(
			article_columns[1],
			WorkdayContext.read_array(grid, "article_right"),
			Color("373229"),
			HORIZONTAL_ALIGNMENT_LEFT,
			VERTICAL_ALIGNMENT_TOP
		)
	)

	page.add_child(
		_make_label(
			"第 %02d 工作日 · 今日精读" % day,
			WorkdayContext.read_array(grid, "day"),
			Color(0.15, 0.14, 0.11, 0.78),
			HORIZONTAL_ALIGNMENT_RIGHT,
			VERTICAL_ALIGNMENT_CENTER
		)
	)
	return page


func _make_label(
	text_value: String,
	values: Array,
	color: Color,
	horizontal: HorizontalAlignment,
	vertical: VerticalAlignment
) -> Label:
	assert(values.size() >= 5, "text grid requires x, y, width, height and font size")
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", int(values[4]))
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 2)
	label.horizontal_alignment = horizontal
	label.vertical_alignment = vertical
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(float(values[0]), float(values[1]))
	label.size = Vector2(float(values[2]), float(values[3]))
	return label


func _issue_for_day(publisher: Dictionary, day: int) -> Dictionary:
	for issue_value: Variant in WorkdayContext.read_array(publisher, "issues"):
		if issue_value is Dictionary and WorkdayContext.read_int(issue_value, "day") == day:
			return issue_value
	return {}


func _publisher_slug(publisher: Dictionary) -> String:
	return (
		WorkdayContext.read_string(publisher, "id")
		.to_lower()
		.trim_prefix("newspaper-")
		.replace("-", "_")
	)


func _split_article_columns(text: String) -> Array[String]:
	if text.length() < 2:
		return [text, ""]
	var midpoint := text.length() / 2
	var split_at := midpoint
	var punctuation := "。！？；"
	for distance in range(0, mini(24, text.length() - midpoint)):
		var forward := midpoint + distance
		if forward < text.length() and punctuation.contains(text.substr(forward, 1)):
			split_at = forward + 1
			break
		var backward := midpoint - distance
		if backward > 0 and punctuation.contains(text.substr(backward, 1)):
			split_at = backward + 1
			break
	return [text.substr(0, split_at).strip_edges(), text.substr(split_at).strip_edges()]
