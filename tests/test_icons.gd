extends TestCase
## Icons come from a sheet of 16×16 glyphs: every item has one, and every
## chosen cell is on the sheet and actually holds a drawing.


func _cell_has_pixels(img: Image, cell: Vector2i) -> bool:
	for y in Icons.TILE:
		for x in Icons.TILE:
			if img.get_pixel(cell.x * Icons.TILE + x, cell.y * Icons.TILE + y).a > 0.5:
				return true
	return false


func _check_cell(img: Image, cell: Vector2i, what: String) -> void:
	var cols := img.get_width() / Icons.TILE
	var rows := img.get_height() / Icons.TILE
	var inside := cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows
	check(inside, "%s: cell %s is on the %dx%d sheet" % [what, cell, cols, rows])
	if inside:
		check(_cell_has_pixels(img, cell), "%s: cell %s is not empty" % [what, cell])


func test_every_item_has_an_icon() -> void:
	for id in ItemCatalog.IDS:
		check(Icons.ITEMS.has(id), "icon for %s" % id)


func test_every_boss_has_a_face() -> void:
	for boss in RoomSession.BOSSES:
		check(Icons.BOSSES.has(boss), "icon for boss %s" % boss)


func test_icon_cells_hold_drawings() -> void:
	var img := Icons.SHEET.get_image()
	check(img != null, "sheet loads")
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	for id: StringName in Icons.ITEMS:
		_check_cell(img, Icons.ITEMS[id]["glyph"], String(id))
	for boss: StringName in Icons.BOSSES:
		_check_cell(img, Icons.BOSSES[boss]["glyph"], "boss %s" % boss)
	for name: StringName in Icons.GLYPHS:
		_check_cell(img, Icons.GLYPHS[name], String(name))


func test_items_are_told_apart() -> void:
	var seen := {}
	for id: StringName in Icons.ITEMS:
		var key := "%s/%s" % [Icons.ITEMS[id]["glyph"], Icons.ITEMS[id]["bg"]]
		check(not seen.has(key), "%s looks like %s" % [id, seen.get(key, "")])
		seen[key] = id
