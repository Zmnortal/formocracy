extends SceneTree

const CONFIG_PATH := "res://data/narrative/newspapers.json"
const PAGE_RECT := Rect2(0, 0, 350, 525)
const TEXT_CELLS := ["edition", "headline", "article_left", "article_right", "day"]


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	assert(parsed is Dictionary, "newspaper config must parse")
	for publisher_value: Variant in WorkdayContext.read_array(parsed, "publishers"):
		assert(publisher_value is Dictionary, "publisher entry must be a dictionary")
		var publisher: Dictionary = publisher_value
		var grid := WorkdayContext.read_dictionary(publisher, "reading_grid")
		var image_rect := _grid_rect(WorkdayContext.read_array(grid, "image"))
		assert(PAGE_RECT.encloses(image_rect), "image cell must stay inside the newspaper page")
		var occupied: Array[Rect2] = []
		for cell_name: String in TEXT_CELLS:
			var text_rect := _grid_rect(WorkdayContext.read_array(grid, cell_name))
			assert(PAGE_RECT.encloses(text_rect), "%s must stay inside the newspaper page" % cell_name)
			assert(not text_rect.intersects(image_rect), "%s must not overlap the newspaper image" % cell_name)
			for existing: Rect2 in occupied:
				assert(not text_rect.intersects(existing), "%s must not overlap another text cell" % cell_name)
			occupied.append(text_rect)
	print("FORMOCRACY_NEWSPAPER_LAYOUT_GRID_TEST_OK")
	quit(0)


func _grid_rect(values: Array) -> Rect2:
	assert(values.size() >= 4, "grid cell requires x, y, width and height")
	return Rect2(
		Vector2(float(values[0]), float(values[1])),
		Vector2(float(values[2]), float(values[3]))
	)
