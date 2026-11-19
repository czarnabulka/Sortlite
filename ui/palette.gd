class_name Palette
extends RefCounted
## Dark, low-glare colours. One place to change the whole look.

const BG := Color("13131b")
const PANEL := Color("1b1b26")
const PANEL_EDGE := Color("2b2b3b")
const TANK := Color("171722")
const SLOT_LINE := Color("23232f")
const TEXT := Color("d4d4de")
const MUTED := Color("8a8aa3")
## Body text that must be read (item descriptions): softer than TEXT, brighter than MUTED.
const SOFT := Color("b4b4c8")
const INK := Color("13131b")
const CHIPS := Color("4b8ed6")
const MULT := Color("d65a5a")
const GOLD := Color("dcb44c")
const GOOD := Color("5cb87a")
const BAD := Color("d65a5a")


## Cool blue for small values to warm red for big ones, kept soft.
static func value_color(v: int, vmax: int) -> Color:
	var t := clampf(float(v - 1) / float(maxi(vmax - 1, 1)), 0.0, 1.0)
	return Color.from_hsv(lerpf(0.60, 0.02, t), 0.40, 0.80)
