class_name Icons
extends RefCounted
## Small pixel icons drawn from rectangles on a 16×16 grid, so every item and
## the boss has a face without outside art. `draw(ci, id, rect)` fits the icon
## into `rect` (keep it a multiple of 16 for crisp pixels).

const INK := Color("13131b")

## Each item: background tint and a list of [x, y, w, h, colour] cells on the
## 16 grid. Colours: "a" accent, "b" light, "i" ink.
const ITEMS := {
	&"sieve": {"bg": "4b6fd6", "cells": [
		[2, 2, 3, 3, "b"], [7, 2, 3, 3, "a"], [12, 2, 2, 3, "a"],
		[2, 7, 3, 3, "a"], [7, 7, 3, 3, "b"], [12, 7, 2, 3, "a"],
		[2, 12, 3, 2, "b"], [7, 12, 3, 2, "a"], [12, 12, 2, 2, "b"]], "a": "f2d36b", "b": "1d2c5c"},
	&"bubble_pump": {"bg": "2f8f9a", "cells": [
		[3, 10, 4, 4, "b"], [9, 6, 5, 5, "b"], [5, 2, 3, 3, "b"],
		[4, 11, 1, 1, "a"], [10, 7, 1, 1, "a"], [6, 3, 1, 1, "a"]], "a": "ffffff", "b": "bdf3f0"},
	&"doubler": {"bg": "c0504f", "cells": [
		[2, 3, 7, 7, "i"], [3, 4, 5, 5, "b"], [7, 6, 7, 7, "i"], [8, 7, 5, 5, "a"]], "a": "ffd0c8", "b": "f08a7e"},
	&"warm_cache": {"bg": "8a4b2a", "cells": [
		[7, 2, 2, 2, "a"], [6, 4, 4, 2, "a"], [5, 6, 6, 3, "a"], [4, 9, 8, 3, "a"],
		[7, 8, 2, 4, "b"], [4, 12, 8, 2, "i"]], "a": "ffb347", "b": "ffe9a8"},
	&"parity_bit": {"bg": "4a7d4f", "cells": [
		[3, 3, 4, 4, "a"], [9, 3, 4, 4, "a"], [3, 9, 4, 4, "a"], [9, 9, 4, 4, "a"],
		[4, 4, 2, 2, "b"], [10, 10, 2, 2, "b"]], "a": "cfeec0", "b": "4a7d4f"},
	&"fibonacci_spiral": {"bg": "6b4f9e", "cells": [
		[2, 2, 12, 1, "a"], [13, 2, 1, 12, "a"], [2, 13, 12, 1, "a"], [2, 5, 1, 9, "a"],
		[2, 5, 8, 1, "a"], [9, 5, 1, 6, "a"], [5, 10, 5, 1, "a"], [5, 7, 1, 4, "a"], [5, 7, 2, 1, "b"]],
		"a": "e6d6ff", "b": "f2d36b"},
	&"power_tower": {"bg": "7a6a3a", "cells": [
		[7, 2, 2, 2, "a"], [6, 5, 4, 3, "a"], [4, 9, 8, 5, "a"], [7, 10, 2, 3, "i"]], "a": "f2d36b", "b": "ffffff"},
	&"chain_reactor": {"bg": "3d5f7a", "cells": [
		[2, 4, 7, 2, "a"], [2, 4, 2, 7, "a"], [2, 9, 7, 2, "a"], [7, 4, 2, 4, "a"],
		[7, 7, 7, 2, "b"], [12, 7, 2, 7, "b"], [7, 12, 7, 2, "b"], [7, 9, 2, 3, "b"]], "a": "9fd6ff", "b": "ffd36b"},
	&"fuse": {"bg": "5a5a2a", "cells": [
		[8, 1, 4, 2, "a"], [7, 3, 4, 2, "a"], [6, 5, 4, 2, "a"], [5, 7, 7, 2, "a"],
		[8, 9, 3, 2, "a"], [7, 11, 3, 2, "a"], [6, 13, 2, 2, "a"]], "a": "fff26b", "b": "ffffff"},
	&"binary_search": {"bg": "2f6b5a", "cells": [
		[3, 2, 7, 1, "a"], [2, 3, 1, 7, "a"], [10, 3, 1, 7, "a"], [3, 10, 7, 1, "a"],
		[3, 3, 7, 7, "b"], [6, 3, 1, 7, "a"], [10, 10, 2, 2, "a"], [12, 12, 2, 2, "a"]], "a": "d6fff0", "b": "4fa88f"},
	&"express_lane": {"bg": "9a3f6b", "cells": [
		[7, 2, 2, 12, "a"], [4, 5, 2, 2, "a"], [10, 5, 2, 2, "a"], [5, 3, 2, 2, "a"], [9, 3, 2, 2, "a"],
		[3, 11, 10, 2, "b"]], "a": "ffd1ea", "b": "f2d36b"},
}

## The Adversary: a horned eye.
const BOSS := {"bg": "3a1418", "cells": [
	[1, 1, 3, 2, "a"], [2, 3, 2, 2, "a"], [12, 1, 3, 2, "a"], [12, 3, 2, 2, "a"],
	[3, 6, 10, 6, "b"], [2, 7, 12, 4, "b"], [7, 6, 2, 6, "i"], [6, 8, 4, 2, "i"], [5, 12, 6, 1, "a"]],
	"a": "d65a5a", "b": "f2d36b"}


static func draw(ci: CanvasItem, id: StringName, r: Rect2, alpha := 1.0) -> void:
	_draw_spec(ci, ITEMS.get(id, {}), r, alpha)


static func draw_boss(ci: CanvasItem, r: Rect2, alpha := 1.0) -> void:
	_draw_spec(ci, BOSS, r, alpha)


static func _draw_spec(ci: CanvasItem, spec: Dictionary, r: Rect2, alpha: float) -> void:
	if spec.is_empty():
		ci.draw_rect(r, Color(Palette.PANEL_EDGE, alpha))
		return
	var u := r.size.x / 16.0
	ci.draw_rect(r, Color(Color(spec["bg"]), alpha))
	ci.draw_rect(r, Color(INK, 0.6 * alpha), false, 1.0)
	for cell: Array in spec["cells"]:
		var key: String = cell[4]
		var c := INK if key == "i" else Color(spec[key])
		ci.draw_rect(Rect2(r.position + Vector2(cell[0], cell[1]) * u, Vector2(cell[2], cell[3]) * u), Color(c, alpha))
