extends Node2D
## The title screen, the settings and the pause menu, drawn in the game's own
## 640×360 like the other screens. Settings apply and save right here; the
## signals tell main.gd what to do next.

signal play_pressed
signal demo_pressed
signal resume_pressed
signal title_pressed
signal quit_pressed
signal crt_changed(on: bool)
signal fullscreen_changed(on: bool)
signal arrival_mode_changed(mode: RoomSession.ArrivalMode)

enum Page { TITLE, SETTINGS, PAUSE }

const S := 16
const M := 20
const L := 32
const ROW_H := 28.0
const MENU_W := 320.0

## What each page lists, in order. Settings rows change a value; the rest act.
const PAGES := {
	Page.TITLE: [&"play", &"demo", &"settings", &"quit"],
	Page.PAUSE: [&"resume", &"settings", &"to_title", &"quit"],
	Page.SETTINGS: [&"language", &"crt", &"fullscreen", &"arrivals", &"back"],
}
const LABELS := {
	&"play": "MENU_PLAY", &"demo": "MENU_DEMO", &"settings": "MENU_SETTINGS", &"quit": "MENU_QUIT",
	&"resume": "MENU_RESUME", &"to_title": "MENU_TO_TITLE", &"back": "MENU_BACK",
	&"language": "SET_LANGUAGE", &"crt": "SET_CRT", &"fullscreen": "SET_FULLSCREEN", &"arrivals": "SET_ARRIVALS",
}
## Rows that change a value (A / D, arrows, click).
const VALUES: Array[StringName] = [&"language", &"crt", &"fullscreen", &"arrivals"]

## A few numbers that bubble-sort themselves behind the title.
const BG_COUNT := 14
const BG_STEP := 0.22
const BG_VMAX := 12

var page := Page.TITLE
## Where Back goes from the settings: the title or the pause menu.
var settings_from := Page.TITLE
var selected := 0
var time := 0.0
var page_t := 0.0
var font: Font

var crt := true
var fullscreen := false
var arrival_mode := RoomSession.ArrivalMode.TURNS

var _bg: Array[Dictionary] = []  # {"value": int, "x": float} in slot order
var _bg_j := 0
var _bg_swapped := false
var _bg_t := 0.0
var _bg_rest := 0.0


func _ready() -> void:
	font = preload("res://ui/room_view.gd").load_pixel_font()
	_shuffle_bg()


func open(new_page: Page) -> void:
	page = new_page
	selected = 0
	page_t = 0.0
	visible = true


func items() -> Array:
	return PAGES[page]


# --- input -------------------------------------------------------------------

func handle_input(event: InputEvent, local: Vector2) -> void:
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		match key.keycode:
			KEY_UP, KEY_W:
				selected = (selected - 1 + items().size()) % items().size()
			KEY_DOWN, KEY_S:
				selected = (selected + 1) % items().size()
			KEY_LEFT, KEY_A:
				if not key.echo:
					_change(items()[selected], -1)
			KEY_RIGHT, KEY_D:
				if not key.echo:
					_change(items()[selected], 1)
			KEY_SPACE, KEY_ENTER:
				if not key.echo:
					_activate(items()[selected])
			KEY_ESCAPE:
				if not key.echo:
					back()
	elif event is InputEventMouseMotion:
		var row := _row_at(local)
		if row >= 0:
			selected = row
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var row := _row_at(local)
		if row >= 0:
			selected = row
			_activate(items()[row])


## ESC: settings go back where they came from, the pause menu resumes.
func back() -> void:
	match page:
		Page.SETTINGS:
			var from := settings_from
			open(from)
			selected = PAGES[from].find(&"settings")
		Page.PAUSE:
			resume_pressed.emit()


func _activate(id: StringName) -> void:
	if id in VALUES:
		_change(id, 1)
		return
	match id:
		&"play":
			play_pressed.emit()
		&"demo":
			demo_pressed.emit()
		&"resume":
			resume_pressed.emit()
		&"to_title":
			title_pressed.emit()
		&"quit":
			quit_pressed.emit()
		&"settings":
			settings_from = page
			open(Page.SETTINGS)
		&"back":
			back()


## Changes a setting one step (every setting has two values, except the
## language list, which wraps around) and saves it.
func _change(id: StringName, direction: int) -> void:
	match id:
		&"language":
			var langs := Settings.LANGUAGES
			var i := langs.find(TranslationServer.get_locale().substr(0, 2))
			var next := langs[(i + direction + langs.size()) % langs.size()]
			TranslationServer.set_locale(next)
			Settings.save_language(next)
		&"crt":
			crt = not crt
			Settings.save_crt(crt)
			crt_changed.emit(crt)
		&"fullscreen":
			fullscreen = not fullscreen
			fullscreen_changed.emit(fullscreen)
		&"arrivals":
			arrival_mode = RoomSession.ArrivalMode.TIME if arrival_mode == RoomSession.ArrivalMode.TURNS \
					else RoomSession.ArrivalMode.TURNS
			Settings.save_arrival_mode(arrival_mode)
			arrival_mode_changed.emit(arrival_mode)


func _value_text(id: StringName) -> String:
	match id:
		&"language":
			return Settings.LANGUAGE_NAMES.get(TranslationServer.get_locale().substr(0, 2), "?")
		&"crt":
			return tr("SET_ON") if crt else tr("SET_OFF")
		&"fullscreen":
			return tr("SET_ON") if fullscreen else tr("SET_OFF")
		&"arrivals":
			return tr("SET_ARRIVALS_TURNS") if arrival_mode == RoomSession.ArrivalMode.TURNS else tr("SET_ARRIVALS_TIME")
	return ""


func _rows_top() -> float:
	return 186.0 if page == Page.TITLE else 132.0


func _row_rect(i: int) -> Rect2:
	var w := MENU_W if page != Page.SETTINGS else 400.0
	return Rect2((640.0 - w) * 0.5, _rows_top() + i * ROW_H - 19.0, w, 25.0)


func _row_at(p: Vector2) -> int:
	for i in items().size():
		if _row_rect(i).has_point(p):
			return i
	return -1


# --- update ------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	time += delta
	page_t += delta
	_step_bg(delta)
	queue_redraw()


func _shuffle_bg() -> void:
	_bg.clear()
	for i in BG_COUNT:
		_bg.append({"value": randi_range(1, BG_VMAX), "x": float(i)})
	_bg_j = 0
	_bg_swapped = false
	_bg_rest = 0.0


## One compare per step, like a bubble-sort pass; a sorted row rests a moment
## and is shuffled again.
func _step_bg(delta: float) -> void:
	for i in _bg.size():
		_bg[i]["x"] = lerpf(_bg[i]["x"], float(i), 1.0 - exp(-14.0 * delta))
	if _bg_rest > 0.0:
		_bg_rest -= delta
		if _bg_rest <= 0.0:
			_shuffle_bg()
		return
	_bg_t += delta
	if _bg_t < BG_STEP:
		return
	_bg_t = 0.0
	if int(_bg[_bg_j]["value"]) > int(_bg[_bg_j + 1]["value"]):
		var tmp: Dictionary = _bg[_bg_j]
		_bg[_bg_j] = _bg[_bg_j + 1]
		_bg[_bg_j + 1] = tmp
		_bg_swapped = true
	_bg_j += 1
	if _bg_j >= _bg.size() - 1:
		if not _bg_swapped:
			_bg_rest = 2.5
		_bg_j = 0
		_bg_swapped = false


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var keys_y := 344.0
	if page == Page.PAUSE or (page == Page.SETTINGS and settings_from == Page.PAUSE):
		# Over the paused game: dim it and put the menu (and its keys) on a panel.
		draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.72))
		var top := _row_rect(0)
		var bottom := _row_rect(items().size() - 1)
		var w := maxf(top.size.x + 48, 460.0)
		var panel := Rect2((640.0 - w) * 0.5, 46, w, bottom.end.y - 46 + 48)
		draw_rect(panel, Palette.BG)
		draw_rect(panel, Palette.PANEL_EDGE, false, 1.0)
		keys_y = panel.end.y - 12
	else:
		draw_rect(Rect2(0, 0, 640, 360), Palette.BG)
		_draw_bg()
	match page:
		Page.TITLE:
			_draw_title()
		Page.PAUSE:
			_heading(tr("MENU_PAUSED"))
		Page.SETTINGS:
			_heading(tr("SET_TITLE"))
	_draw_rows()
	var keys := tr("MENU_KEYS")
	if page == Page.PAUSE:
		keys = tr("MENU_KEYS_PAUSE")
	elif page == Page.SETTINGS:
		keys = tr("MENU_KEYS_BACK")
	_text(keys, Vector2(0, keys_y), S, Palette.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 640)


## The sorting row along the bottom, dim so the menu stays readable.
func _draw_bg() -> void:
	var w := 640.0 / BG_COUNT
	var base := 324.0
	for i in _bg.size():
		var e: Dictionary = _bg[i]
		var v := int(e["value"])
		var h := 6.0 + v * 3.5
		var x := float(e["x"]) * w + 4.0
		var lit := not (_bg_rest > 0.0) and (i == _bg_j or i == _bg_j + 1)
		var c := Palette.value_color(v, BG_VMAX)
		draw_rect(Rect2(x, base - h, w - 8.0, h), Color(c, 0.55 if lit else 0.22))
	draw_line(Vector2(0, base + 1), Vector2(640, base + 1), Color(Palette.PANEL_EDGE, 0.8))


func _draw_title() -> void:
	var a := Anim.clamp01(page_t / 0.4)
	# The logo: the 32 px font at a whole-number scale stays crisp.
	var s := 2.0
	var drop := 10.0 * (1.0 - Anim.ease_out_cubic(page_t / 0.5))
	draw_set_transform(Vector2(320, 88 - drop), 0.0, Vector2(s, s))
	_text("ROGUESORT", Vector2(-160 + 1, 1), L, Color(Palette.INK, a), HORIZONTAL_ALIGNMENT_CENTER, 320)
	_text("ROGUESORT", Vector2(-160, 0), L, Color(Palette.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, 320)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_text(tr("MENU_TAGLINE"), Vector2(0, 124), M, Color(Palette.SOFT, Anim.clamp01((page_t - 0.2) / 0.4)),
			HORIZONTAL_ALIGNMENT_CENTER, 640)
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if version != "":
		_text("v" + version, Vector2(0, 22), S, Palette.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 624)


func _heading(text: String) -> void:
	_text(text, Vector2(0, 84), L, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 640)


func _draw_rows() -> void:
	var list := items()
	for i in list.size():
		var id: StringName = list[i]
		var r := _row_rect(i)
		var a := Anim.clamp01((page_t - 0.05 * i) / 0.25)
		var on := i == selected
		if on:
			draw_rect(r, Color(Palette.PANEL, a))
			draw_rect(r, Color(Palette.GOLD, a), false, 1.0)
		var color := Palette.GOLD if on else Palette.TEXT
		var y := r.position.y + 19.0
		if id in VALUES:
			_text(tr(LABELS[id]), Vector2(r.position.x + 12, y), M, Color(Palette.SOFT if not on else color, a))
			var value := _value_text(id)
			var shown := ("<  %s  >" % value) if on else value
			_text(shown, Vector2(r.position.x, y), M, Color(color, a), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 12)
		else:
			_text(tr(LABELS[id]), Vector2(r.position.x, y), M, Color(color, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _text(s: String, pos: Vector2, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, pos, s, align, width, size, color)
