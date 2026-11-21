class_name Icons
extends RefCounted
## Item, boss and UI icons: 16×16 glyphs from Kenney's 1-Bit Pack (CC0,
## assets/icons/kenney_1bit.png, white on transparent), tinted when drawn.
## An item icon is its glyph on a coloured tile, so items stay easy to tell
## apart. Keep icon rects a multiple of 16 for crisp pixels.

const SHEET := preload("res://assets/icons/kenney_1bit.png")
const TILE := 16
const INK := Color("13131b")

## Item id -> glyph (column, row on the sheet), tile colour, glyph colour.
const ITEMS := {
	&"sieve": {"glyph": Vector2i(2, 15), "bg": "4b6fd6", "fg": "f2d36b"},  # a web: the sieve
	&"bubble_pump": {"glyph": Vector2i(35, 11), "bg": "2f8f9a", "fg": "e8fffd"},  # bubbles
	&"doubler": {"glyph": Vector2i(38, 20), "bg": "c0504f", "fg": "ffe0d8"},  # ×
	&"warm_cache": {"glyph": Vector2i(15, 10), "bg": "8a4b2a", "fg": "ffc46b"},  # a flame
	&"parity_bit": {"glyph": Vector2i(45, 14), "bg": "4a7d4f", "fg": "dcf5cf"},  # a die showing 4
	&"fibonacci_spiral": {"glyph": Vector2i(41, 20), "bg": "6b4f9e", "fg": "ece0ff"},  # a spiral
	&"power_tower": {"glyph": Vector2i(43, 20), "bg": "7a6a3a", "fg": "f2d36b"},  # a tower
	&"chain_reactor": {"glyph": Vector2i(28, 12), "bg": "3d5f7a", "fg": "ffd36b"},  # a burst
	&"fuse": {"glyph": Vector2i(45, 9), "bg": "5a5a2a", "fg": "fff26b"},  # a bomb
	&"binary_search": {"glyph": Vector2i(21, 21), "bg": "2f6b5a", "fg": "d6fff0"},  # up and down
	&"express_lane": {"glyph": Vector2i(24, 12), "bg": "9a3f6b", "fg": "ffd1ea"},  # an arrow up
	&"spatula": {"glyph": Vector2i(42, 5), "bg": "8a6a3a", "fg": "ffe8b0"},  # a shovel: the spatula
	&"median_of_three": {"glyph": Vector2i(39, 20), "bg": "3d6b8a", "fg": "dff2ff"},  # ÷: divide and conquer
	&"galloping": {"glyph": Vector2i(28, 7), "bg": "7a5a3a", "fg": "ffe8c0"},  # a horse
	&"sift_down": {"glyph": Vector2i(30, 21), "bg": "2f5f8a", "fg": "d6f0ff"},  # a thick arrow down
	&"tail_call": {"glyph": Vector2i(37, 17), "bg": "8a3a5a", "fg": "ffd6e8"},  # 2: scores twice
	&"off_by_one": {"glyph": Vector2i(36, 17), "bg": "4a6a2a", "fg": "e8ffcf"},  # 1
}

## Boss id (RoomSession.BOSSES) -> its face.
const BOSSES := {
	&"adversary": {"glyph": Vector2i(34, 12), "bg": "3a1418", "fg": "f2d36b"},  # a skull
	&"burnt": {"glyph": Vector2i(14, 11), "bg": "3a2418", "fg": "ffb46b"},  # a fire on a grill
	&"leak": {"glyph": Vector2i(28, 11), "bg": "142a3a", "fg": "6bd6ff"},  # a drop
}

## Plain glyphs for the interface, drawn in any colour.
const GLYPHS := {
	&"heart": Vector2i(39, 10),
	&"heart_empty": Vector2i(40, 10),
	&"coin": Vector2i(41, 3),
	&"flame": Vector2i(15, 10),
}


static func draw(ci: CanvasItem, id: StringName, r: Rect2, alpha := 1.0) -> void:
	_draw_tile(ci, ITEMS.get(id, {}), r, alpha)


static func draw_boss(ci: CanvasItem, r: Rect2, alpha := 1.0, boss: StringName = &"adversary") -> void:
	_draw_tile(ci, BOSSES.get(boss, BOSSES[&"adversary"]), r, alpha)


## One glyph, no tile behind it.
static func draw_glyph(ci: CanvasItem, name: StringName, r: Rect2, color: Color) -> void:
	var cell: Vector2i = GLYPHS.get(name, Vector2i(-1, -1))
	if cell.x < 0:
		return
	ci.draw_texture_rect_region(SHEET, r, _region(cell), color)


static func _region(cell: Vector2i) -> Rect2:
	return Rect2(cell.x * TILE, cell.y * TILE, TILE, TILE)


static func _draw_tile(ci: CanvasItem, spec: Dictionary, r: Rect2, alpha: float) -> void:
	if spec.is_empty():
		ci.draw_rect(r, Color(Palette.PANEL_EDGE, alpha))
		return
	ci.draw_rect(r, Color(Color(spec["bg"]), alpha))
	ci.draw_rect(r, Color(INK, 0.6 * alpha), false, 1.0)
	ci.draw_texture_rect_region(SHEET, r, _region(spec["glyph"]), Color(Color(spec["fg"]), alpha))
