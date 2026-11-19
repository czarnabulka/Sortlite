extends Node2D
## One room drawn at 640×360, for any algorithm. All rules live in core/;
## this node draws the board, animates what the event bus reports, and turns
## input into moves. The run screen gives it a session and listens for
## `continue_pressed` once the room is over.
##
## Both algorithms use a column with the exit at the top:
## - Bubble: index 0 is the bottom; the biggest leaves through the top.
## - Insertion: index 0 is the top; the sorted part grows from the top, the
##   key (first unsorted element) is inserted into it, the smallest leaves.

signal continue_pressed

const TANK_CX := 300.0
const TANK_TOP := 46.0
const TANK_W := 104.0
const SLOT_H := 32.0
const EL_W := 84.0
const EL_H := 26.0
const PANEL_L := 14.0
const PANEL_R := 420.0
const PANEL_R_W := 206.0

const SWAP_DUR := 0.14
const ARRIVE_DUR := 0.28
const RISE_DUR := 0.12
const POP_DUR := 0.24
const CHAIN_STEP := 0.16
const DEMO_STEP := 0.32
## How far the Insertion key sticks out of the column.
const KEY_PULL := 12.0

## Text sizes. Jersey 10 stays crisp at these; anything smaller loses letters.
const S := 16
const M := 20
const L := 32

const FONT_PATH := "res://assets/fonts/Jersey10-Regular.ttf"


class Vis:
	var pos := Vector2.ZERO
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var t := 1.0
	var dur := SWAP_DUR
	var arc := 0.0
	var alpha := 1.0


class Ghost:
	var value := 0
	var start := Vector2.ZERO
	var pos := Vector2.ZERO
	var delay := 0.0
	var t := 0.0
	var popped := false
	var points := 0
	var mult := 0
	var gained := 0
	var chain := 1
	var notes: Array[StringName] = []


class Floater:
	var text := ""
	var pos := Vector2.ZERO
	var color := Color.WHITE
	var size := 16
	var t := 0.0
	var life := 0.9


var session: RoomSession
var room_no := 1
var room_total := 1
var room_kind: StringName = &"fight"
var bits := 0
var mode := RoomSession.ArrivalMode.TURNS
var demo := false
var help_open := false
## The rules card of this room's algorithm (I). Opens by itself the first
## time an algorithm shows up in a run. The room waits while a card is open.
var rules_open := false
var overlay_t := 0.0
var intro_t := 0.0
var end_t := 0.0

var selected := 0
var hover := -1
var focus_item: StringName = &""
var vis: Dictionary = {}  # uid -> Vis
var pending_arc: Dictionary = {}  # uid -> float
var ghosts: Array[Ghost] = []
var floaters: Array[Floater] = []
var item_flash: Dictionary = {}  # item id -> seconds left
var pop_line := 0

var score_target := 0
var shown_score := 0.0
var last_points := 0
var last_mult := 0
var formula_bump := 0.0
var shake := 0.0
var tank_flash := 0.0
var banner_text := ""
var banner_delay := 0.0
var banner_t := 9.0
var demo_timer := 0.0
var time := 0.0

var font: Font
var _style_cache: Dictionary = {}


func _ready() -> void:
	font = load_pixel_font()


func set_session(p_session: RoomSession, p_room_no: int, p_room_total: int, p_kind: StringName, p_bits: int,
		show_rules := false) -> void:
	session = p_session
	intro_t = 0.0
	end_t = 0.0
	overlay_t = 0.0
	rules_open = show_rules
	room_no = p_room_no
	room_total = p_room_total
	room_kind = p_kind
	bits = p_bits
	mode = session.mode
	vis.clear()
	pending_arc.clear()
	ghosts.clear()
	floaters.clear()
	item_flash.clear()
	focus_item = session.items[0].id if not session.items.is_empty() else &""
	score_target = session.room.score
	shown_score = score_target
	last_points = 0
	last_mult = 0
	banner_t = 9.0
	pop_line = 0
	var bus := session.bus
	# Added after the items, so the screen sees the final points and mult.
	bus.on(Events.SWAP, _on_swap)
	bus.on(Events.INSERT, _on_insert)
	bus.on(Events.WRONG_MOVE, _on_wrong)
	bus.on(Events.SURFACE, _on_surface)
	bus.on(Events.CHAIN, _on_chain)
	bus.on(Events.OVERFLOW, _on_overflow)
	bus.on(Events.ITEM_TRIGGERED, _on_item_triggered)
	_reset_selection()
	_sync_visuals()
	# The starting numbers rise into the column one after another, once the
	# panels have slid in.
	var cells := session.room.board.cells
	for i in cells.size():
		var v: Vis = vis[cells[i].uid]
		v.from = v.to + Vector2(0.0, 48.0)
		v.pos = v.from
		v.dur = 0.32
		v.t = -(0.22 + 0.05 * i) / v.dur
		v.alpha = 0.0


func is_bubble() -> bool:
	return session.room.algorithm.id == Algorithms.BUBBLE


func is_over() -> bool:
	return not session.is_playing() and ghosts.is_empty()


# --- input -----------------------------------------------------------------

func handle_input(event: InputEvent, local: Vector2) -> void:
	if session == null:
		return
	if rules_open or help_open:
		# Any of these closes the card; nothing else happens meanwhile.
		var close := false
		if event is InputEventKey and event.pressed and not event.echo:
			close = event.keycode in [KEY_SPACE, KEY_ENTER, KEY_I, KEY_H]
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close = true
		if close:
			rules_open = false
			help_open = false
		return
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if is_over():
			if not key.echo and key.keycode in [KEY_SPACE, KEY_ENTER]:
				continue_pressed.emit()
			return
		match key.keycode:
			KEY_UP, KEY_W:
				_step_selection(1)
			KEY_DOWN, KEY_S:
				_step_selection(-1)
			KEY_SPACE, KEY_ENTER:
				if not key.echo:
					_act(selected)
			KEY_F:
				if not key.echo:
					session.deliver()
					_reset_selection()
			KEY_D:
				if not key.echo:
					demo = not demo
			KEY_H:
				if not key.echo:
					help_open = true
					overlay_t = 0.0
			KEY_I:
				if not key.echo:
					rules_open = true
					overlay_t = 0.0
			KEY_M:
				if not key.echo:
					mode = RoomSession.ArrivalMode.TIME if mode == RoomSession.ArrivalMode.TURNS else RoomSession.ArrivalMode.TURNS
					session.set_mode(mode)
	elif event is InputEventMouseMotion:
		hover = _target_at(local)
		var row := _item_row_at(local)
		if row >= 0:
			focus_item = session.items[row].id
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_step_selection(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_step_selection(-1)
			MOUSE_BUTTON_LEFT:
				if is_over():
					continue_pressed.emit()
					return
				var j := _target_at(local)
				if j >= 0:
					if j == selected:
						_act(j)
					else:
						selected = j


## +1 = towards the exit (up on screen) for both algorithms.
func _step_selection(direction: int) -> void:
	var lo_hi := _selection_range()
	if lo_hi.y < lo_hi.x:
		return
	selected += direction if is_bubble() else -direction
	selected = clampi(selected, lo_hi.x, lo_hi.y)


## Bubble: pairs 0..size-2. Insertion: places 0..k-1 before the key at k.
func _selection_range() -> Vector2i:
	var board := session.room.board
	if is_bubble():
		return Vector2i(0, board.size() - 2)
	var k := board.sorted_prefix_length()
	if k >= board.size():
		return Vector2i(0, -1)
	return Vector2i(0, k - 1)


func _reset_selection() -> void:
	var r := _selection_range()
	if is_bubble():
		selected = clampi(selected, r.x, maxi(r.y, 0))
	else:
		selected = maxi(r.y, 0)  # nearest place: costs 1


func _act(target: int) -> void:
	var wrong_before := session.room.wrong_moves
	var move := {"type": Events.SWAP, "index": target} if is_bubble() else {"type": Events.INSERT, "to": target}
	if not session.play(move):
		return
	if session.room.wrong_moves > wrong_before:
		shake = maxf(shake, 2.0)
	if is_bubble():
		# After a correct swap follow the element up, so SPACE keeps carrying it.
		if session.room.wrong_moves == wrong_before:
			selected = target + 1
		var r := _selection_range()
		selected = clampi(selected, r.x, maxi(r.y, 0))
	else:
		_reset_selection()


func _target_at(p: Vector2) -> int:
	var board := session.room.board
	if absf(p.x - TANK_CX) > TANK_W * 0.5:
		return -1
	var r := _selection_range()
	if r.y < r.x:
		return -1
	var j: int
	if is_bubble():
		j = int(roundf((_tank_bottom() - p.y) / SLOT_H)) - 1
	else:
		j = int(floorf((p.y - TANK_TOP) / SLOT_H))
	return j if j >= r.x and j <= r.y and j < board.size() else -1


func _item_row_at(p: Vector2) -> int:
	if p.x < PANEL_R or p.x > PANEL_R + PANEL_R_W:
		return -1
	var i := int(floorf((p.y - 118.0) / 22.0))
	return i if i >= 0 and i < session.items.size() else -1


# --- bus events --------------------------------------------------------------

func _on_swap(data: Dictionary) -> void:
	var j: int = data["move"]["index"]
	var cells := session.room.board.cells
	pending_arc[cells[j].uid] = -12.0
	pending_arc[cells[j + 1].uid] = 12.0


func _on_insert(data: Dictionary) -> void:
	var p: int = data["move"]["to"]
	pending_arc[session.room.board.cells[p].uid] = 22.0  # the key swings out and in


func _on_wrong(data: Dictionary) -> void:
	var move: Dictionary = data["move"]
	var j: int = move.get("index", move.get("to", 0))
	if is_bubble():
		_float(tr("WRONG_SWAP"), Vector2(TANK_CX + TANK_W * 0.5 + 14, _slot_pos(j).y - 8), Palette.BAD, S)
	else:
		var text := tr("WRONG_INSERT")
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, M).x
		_float(text, Vector2(TANK_CX - w * 0.5, _slot_pos(j).y + 6), Palette.BAD, M)


func _on_surface(data: Dictionary) -> void:
	var ctx: ScoreContext = data["ctx"]
	var g := Ghost.new()
	g.value = ctx.element.value
	var v: Vis = vis.get(ctx.element.uid)
	g.start = v.pos if v != null else _slot_pos(0 if not is_bubble() else session.room.board.size())
	g.pos = g.start
	g.chain = ctx.chain
	g.delay = SWAP_DUR + (ctx.chain - 1) * CHAIN_STEP
	g.points = ctx.points
	g.mult = ctx.mult
	g.gained = ctx.total()
	g.notes = ctx.notes.duplicate()
	ghosts.append(g)
	vis.erase(ctx.element.uid)


func _on_chain(data: Dictionary) -> void:
	var length: int = data["length"]
	banner_text = tr("CHAIN_BANNER") % length
	banner_delay = SWAP_DUR + (length - 1) * CHAIN_STEP + RISE_DUR
	banner_t = -1.0


func _on_overflow(data: Dictionary) -> void:
	# The Fuse sets "absorbed" before us: it then costs nothing.
	if data["absorbed"]:
		_float(tr("FUSE_BLOWN"), Vector2(TANK_CX + TANK_W * 0.5 + 14, TANK_TOP + 60), Palette.GOLD, S)
		return
	shake = 5.0
	tank_flash = 0.5
	_float(tr("OVERFLOW"), Vector2(TANK_CX + TANK_W * 0.5 + 14, TANK_TOP + 60), Palette.BAD, S)


func _on_item_triggered(data: Dictionary) -> void:
	var id: StringName = data["id"]
	item_flash[id] = 0.6
	focus_item = id


# --- update ------------------------------------------------------------------

func _process(delta: float) -> void:
	if session == null:
		return
	time += delta
	intro_t += delta
	overlay_t += delta
	end_t = end_t + delta if is_over() else 0.0
	var paused := rules_open or help_open
	if demo and rules_open and overlay_t > 1.6:
		rules_open = false  # the demo reads the card, then plays
	if not paused:
		session.update(delta)
	if demo and session.is_playing() and not paused and intro_t > 0.6:
		demo_timer += delta
		if demo_timer >= DEMO_STEP:
			demo_timer = 0.0
			var move := Bots.choose_for(session.room)
			if move.is_empty():
				session.deliver()
				_reset_selection()
			else:
				selected = move.get("index", move.get("to", 0))
				_act(selected)
	var r := _selection_range()
	if r.y >= r.x:
		selected = clampi(selected, r.x, r.y)

	_sync_visuals()
	for v: Vis in vis.values():
		if v.t < 1.0:
			v.t = minf(v.t + delta / v.dur, 1.0)
			var p := Anim.clamp01(v.t)
			v.pos = v.from.lerp(v.to, _ease_in_out(p)) + Vector2(v.arc * sin(PI * p), 0.0)
		if v.t > 0.0:  # a negative t is a delay before it starts
			v.alpha = minf(v.alpha + delta * 5.0, 1.0)

	_update_ghosts(delta)

	var kept: Array[Floater] = []
	for f in floaters:
		f.t += delta
		if f.t < f.life:
			kept.append(f)
	floaters = kept
	if floaters.is_empty():
		pop_line = 0

	for id in item_flash.keys():
		item_flash[id] = float(item_flash[id]) - delta
		if float(item_flash[id]) <= 0.0:
			item_flash.erase(id)

	if banner_t < 0.0:
		banner_delay -= delta
		if banner_delay <= 0.0:
			banner_t = 0.0
	else:
		banner_t += delta

	shown_score = lerpf(shown_score, float(score_target), 1.0 - exp(-10.0 * delta))
	if absf(shown_score - score_target) < 0.5:
		shown_score = score_target
	formula_bump = maxf(formula_bump - delta * 3.0, 0.0)
	shake = maxf(shake - delta * 18.0, 0.0)
	tank_flash = maxf(tank_flash - delta, 0.0)
	queue_redraw()


func _sync_visuals() -> void:
	var cells := session.room.board.cells
	var alive: Dictionary = {}
	for i in cells.size():
		var e := cells[i]
		alive[e.uid] = true
		var target := _slot_pos(i)
		var v: Vis = vis.get(e.uid)
		if v == null:
			v = Vis.new()
			# Rises into its slot from just below, fading in.
			v.pos = target + Vector2(0.0, SLOT_H * 0.6)
			v.from = v.pos
			v.to = target
			v.t = 0.0
			v.dur = ARRIVE_DUR
			v.alpha = 0.0
			vis[e.uid] = v
		elif v.to != target:
			v.from = v.pos
			v.to = target
			v.t = 0.0
			v.dur = SWAP_DUR
			v.arc = float(pending_arc.get(e.uid, 0.0))
	pending_arc.clear()
	for uid in vis.keys():
		if not alive.has(uid):
			vis.erase(uid)


func _update_ghosts(delta: float) -> void:
	var exit_pos := Vector2(TANK_CX, TANK_TOP - 14.0)
	var kept: Array[Ghost] = []
	for g in ghosts:
		if g.delay > 0.0:
			g.delay -= delta
			kept.append(g)
			continue
		g.t += delta
		if g.t < RISE_DUR:
			g.pos = g.start.lerp(exit_pos, _ease_in_out(g.t / RISE_DUR))
		elif not g.popped:
			g.popped = true
			g.pos = exit_pos
			_pop(g)
		if g.t < RISE_DUR + POP_DUR:
			kept.append(g)
	ghosts = kept


func _pop(g: Ghost) -> void:
	score_target += g.gained
	last_points = g.points
	last_mult = g.mult
	formula_bump = 1.0
	for id in g.notes:
		item_flash[id] = 0.6
		focus_item = id
	# One line per score while earlier ones are still visible, so nothing overlaps.
	# Bubble: right of the column. Insertion keeps that side for the key and
	# its arrow, so its scores go on the left.
	var fy := TANK_TOP + 10.0 + (pop_line % 9) * 16.0
	pop_line += 1
	var fx := TANK_CX + TANK_W * 0.5 + 14 if is_bubble() else TANK_CX - TANK_W * 0.5 - 38
	_float("+%d" % g.gained, Vector2(fx, fy), Palette.GOLD, S)


func _float(text: String, pos: Vector2, color: Color, size: int) -> void:
	var f := Floater.new()
	f.text = text
	f.pos = pos
	f.color = color
	f.size = size
	floaters.append(f)


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Palette.BG)
	if session == null:
		return
	var off := Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0.0 else Vector2.ZERO
	# Side panels slide in from the edges when the room starts.
	var slide := 1.0 - Anim.ease_out_cubic(intro_t / 0.35)
	draw_set_transform(off + Vector2(-230.0 * slide, 0.0))
	_draw_left_panel()
	draw_set_transform(off + Vector2(0.0, 24.0 * slide))
	_draw_tank()
	draw_set_transform(off)
	_draw_elements()
	_draw_ghosts()
	draw_set_transform(off + Vector2(230.0 * slide, 0.0))
	_draw_right_panel()
	draw_set_transform(off)
	_draw_floaters()
	_draw_banner()
	draw_set_transform(Vector2.ZERO)
	if is_over():
		_draw_end_overlay()
	if rules_open:
		_draw_rules()
	elif help_open:
		_draw_help()


func _draw_left_panel() -> void:
	var x := PANEL_L
	var w := 196.0
	var room := session.room
	var right := HORIZONTAL_ALIGNMENT_RIGHT
	var kind_color := Palette.BAD if room_kind == Run.BOSS else Palette.GOLD
	_text(tr("KIND_" + String(room_kind).to_upper()), Vector2(x, 22), M, kind_color)
	_text(tr("ROOM_N_OF") % [room_no, room_total], Vector2(x, 22), M, Palette.MUTED, right, w)
	_text(tr("ALGO_" + String(room.algorithm.id).to_upper()), Vector2(x, 39), S, Palette.SOFT)

	# Score against target
	_panel(Rect2(x, 46, w, 66))
	_text(tr("SCORE"), Vector2(x + 8, 62), S, Palette.MUTED)
	_text(str(int(shown_score)), Vector2(x + 8, 94), L, Palette.TEXT)
	_text("/ %d" % room.target, Vector2(x + 8, 94), M, Palette.MUTED, right, w - 16)
	_bar(Rect2(x + 8, 101, w - 16, 5), shown_score / float(room.target), Palette.GOLD)

	# Move budget
	_panel(Rect2(x, 118, w, 40))
	_text(tr("MOVES"), Vector2(x + 8, 136), S, Palette.MUTED)
	_text("%d / %d" % [room.budget, session.budget_max], Vector2(x + 8, 137), M, Palette.TEXT, right, w - 16)
	var low := room.budget <= 8
	_bar(Rect2(x + 8, 146, w - 16, 4), float(room.budget) / float(session.budget_max), Palette.BAD if low else Palette.CHIPS)

	# Lives and bits
	_panel(Rect2(x, 164, w, 30))
	_text(tr("LIVES"), Vector2(x + 8, 184), S, Palette.MUTED)
	for i in session.max_lives:
		var r := Rect2(x + 62 + i * 16, 173, 11, 11)
		if i < session.lives:
			draw_rect(r, Palette.BAD)
		else:
			draw_rect(r, Palette.PANEL_EDGE, false, 1.0)
	_text("%s %d" % [tr("BITS"), bits], Vector2(x + 8, 184), S, Palette.GOLD, right, w - 16)

	# Stats
	_panel(Rect2(x, 200, w, 50))
	_text(tr("BEST_CHAIN"), Vector2(x + 8, 220), S, Palette.MUTED)
	_text("×%d" % room.best_chain, Vector2(x + 8, 220), M, Palette.GOLD, right, w - 16)
	_text(tr("WRONG_MOVES"), Vector2(x + 8, 241), S, Palette.MUTED)
	_text(str(room.wrong_moves), Vector2(x + 8, 241), M, Palette.BAD if room.wrong_moves > 0 else Palette.TEXT, right, w - 16)

	# Arrivals
	_panel(Rect2(x, 256, w, 46))
	_text(tr("ARRIVALS"), Vector2(x + 8, 274), S, Palette.MUTED)
	var how := tr("EVERY_N_MOVES") % session.every_moves if mode == RoomSession.ArrivalMode.TURNS else tr("EVERY_N_SEC") % int(session.interval_sec)
	_text(how, Vector2(x + 8, 274), S, Palette.TEXT, right, w - 16)
	_text(tr("LET_IN_NOW"), Vector2(x + 8, 293), S, Palette.SOFT)

	# How this room works
	var hint := "HINT_ADVERSARY" if session.feed == RoomSession.FEED_ADVERSARY else "HINT_" + String(room.algorithm.id).to_upper()
	draw_multiline_string(font, Vector2(x, 320), tr(hint), HORIZONTAL_ALIGNMENT_LEFT, w, S, 2,
			Palette.BAD.lightened(0.2) if session.feed == RoomSession.FEED_ADVERSARY else Palette.SOFT)


func _draw_tank() -> void:
	var board := session.room.board
	var cap := board.capacity
	var bottom := _tank_bottom()
	var r := Rect2(TANK_CX - TANK_W * 0.5, TANK_TOP, TANK_W, cap * SLOT_H)
	draw_rect(r, Palette.TANK)
	for i in range(1, cap):
		var y := TANK_TOP + i * SLOT_H
		draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), Palette.SLOT_LINE, 1.0)
	var edge := Palette.PANEL_EDGE
	if tank_flash > 0.0:
		edge = edge.lerp(Palette.BAD, tank_flash * 2.0)
	elif board.is_full():
		edge = edge.lerp(Palette.BAD, 0.4 + 0.3 * sin(time * 8.0))
	draw_rect(r, edge, false, 1.0)

	# Exit line
	draw_dashed_line(Vector2(r.position.x - 6, TANK_TOP - 4), Vector2(r.end.x + 6, TANK_TOP - 4), Palette.GOLD.darkened(0.3), 1.0, 4.0)
	_text(tr("EXIT"), Vector2(r.position.x, TANK_TOP - 9), S, Palette.GOLD.darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER, TANK_W)

	# Fill level ticks on the side (Insertion uses that side for the arrow)
	if is_bubble():
		for i in cap:
			var c := Palette.GOLD if i < board.size() else Palette.PANEL_EDGE
			draw_rect(Rect2(r.end.x + 5, _slot_pos(i).y - 2, 3, 4), c)

	var playing := session.is_playing()
	if is_bubble():
		if hover >= 0 and hover != selected:
			draw_rect(_pair_rect(hover), Palette.MUTED.darkened(0.3), false, 1.0)
		if board.size() >= 2 and playing:
			var pr := _pair_rect(selected)
			draw_rect(pr, Palette.GOLD, false, 1.0)
			_marker(Vector2(pr.position.x, pr.get_center().y))
	else:
		_draw_insertion_guides(r, playing)

	# Next arrival
	var nb := Rect2(r.position.x, bottom + 5, TANK_W, 40)
	_panel(nb)
	_text(tr("NEXT"), Vector2(nb.position.x + 6, nb.position.y + 17), S, Palette.MUTED)
	var info := tr("IN_N_MOVES") % session.moves_until_arrival() if mode == RoomSession.ArrivalMode.TURNS else "%.1f s" % (session.interval_sec - session.timer)
	_text(info, Vector2(nb.position.x + 6, nb.position.y + 34), S, Palette.TEXT)
	var chip := Rect2(nb.end.x - 34, nb.position.y + 7, 28, 26)
	_rounded(chip, Palette.value_color(session.next_value, session.vmax), 3)
	_text(str(session.next_value), Vector2(chip.position.x, chip.position.y + 19), M, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, chip.size.x)
	_bar(Rect2(nb.position.x, nb.end.y + 2, nb.size.x, 3), session.arrival_progress(), Palette.GOLD)


## The sorted part (green bracket), the key, and where it would go.
func _draw_insertion_guides(r: Rect2, playing: bool) -> void:
	var board := session.room.board
	var k := board.sorted_prefix_length()
	if k > 0:
		var y1 := TANK_TOP + 3.0
		var y2 := TANK_TOP + k * SLOT_H - 3.0
		draw_line(Vector2(r.position.x - 5, y1), Vector2(r.position.x - 5, y2), Palette.GOOD, 2.0)
	if not playing or k >= board.size():
		return
	var key_pos := _slot_pos(k)
	var v: Vis = vis.get(board.cells[k].uid)
	if v != null:
		key_pos = v.pos
	if hover >= 0 and hover != selected:
		var hy := TANK_TOP + hover * SLOT_H
		draw_line(Vector2(r.position.x + 4, hy), Vector2(r.end.x - 4, hy), Palette.MUTED, 1.0)
	# The gap the key would go into, and an arrow from the key to it.
	var gy := TANK_TOP + selected * SLOT_H
	var pulse := 0.75 + 0.25 * sin(time * 6.0)
	draw_rect(Rect2(r.position.x + 2, gy - 1.5, TANK_W - 4, 3), Color(Palette.GOLD, pulse))
	_marker(Vector2(r.position.x, gy))
	_insert_arrow(key_pos.x + EL_W * 0.5 + KEY_PULL + 2.0, r.end.x - 2.0, key_pos.y, gy)
	var lane := key_pos.x + EL_W * 0.5 + KEY_PULL + 18.0
	_text(tr("KEY"), Vector2(lane, key_pos.y + 6), S, Palette.GOLD)
	var cost := session.room.algorithm.move_cost(board, {"type": Events.INSERT, "to": selected})
	_text(tr("COST_N") % cost, Vector2(lane, gy + 6), S, Palette.BAD if cost > session.room.budget else Palette.TEXT)


func _marker(at: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(at.x - 9, at.y - 5), Vector2(at.x - 3, at.y), Vector2(at.x - 9, at.y + 5)]), Palette.GOLD)


func _draw_elements() -> void:
	var board := session.room.board
	if board.is_empty():
		return
	# The element that leaves next: the biggest in Bubble, the smallest in Insertion.
	var leaver := board.max_value() if is_bubble() else board.min_value()
	var key_index := -1 if is_bubble() else board.sorted_prefix_length()
	for i in board.size():
		var e := board.cells[i]
		var v: Vis = vis.get(e.uid)
		if v == null:
			continue
		var r := Rect2(v.pos - Vector2(EL_W, EL_H) * 0.5, Vector2(EL_W, EL_H))
		if i == key_index and session.is_playing():
			r.position.x += KEY_PULL  # the key sticks out: it is in your hand
		var c := Palette.value_color(e.value, session.vmax)
		c.a = v.alpha
		_rounded(r, c, 4)
		if i == key_index and session.is_playing():
			draw_rect(r.grow(2), Palette.GOLD, false, 2.0)
		elif e.value == leaver:
			draw_rect(r.grow(2), Color(Palette.GOLD, 0.5 + 0.3 * sin(time * 5.0)), false, 1.0)
		_text(str(e.value), Vector2(r.position.x, r.position.y + 20), M, Color(Palette.INK, v.alpha), HORIZONTAL_ALIGNMENT_CENTER, EL_W)
		if NumberProps.is_prime(e.value):
			draw_rect(Rect2(r.position.x + 4, r.position.y + 4, 3, 3), Color(Palette.INK, 0.6 * v.alpha))


func _draw_ghosts() -> void:
	for g in ghosts:
		var c := Palette.value_color(g.value, session.vmax)
		var s := 1.0
		if g.popped:
			var p := clampf((g.t - RISE_DUR) / POP_DUR, 0.0, 1.0)
			s = 1.0 + 0.6 * p
			c.a = 1.0 - p
			draw_arc(g.pos, 10.0 + 40.0 * p, 0.0, TAU, 24, Color(Palette.GOLD, 1.0 - p), 1.0)
		var size := Vector2(EL_W, EL_H) * s
		var r := Rect2(g.pos - size * 0.5, size)
		_rounded(r, c, 4)
		_text(str(g.value), Vector2(r.position.x, g.pos.y + 7), M, Color(Palette.INK, c.a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_right_panel() -> void:
	var x := PANEL_R
	var w := PANEL_R_W

	# points × mult of the last scoring, like chips × mult
	_text(tr("POINTS_X_MULT"), Vector2(x, 22), S, Palette.MUTED)
	var bump := formula_bump * 2.0
	var chips := Rect2(x, 30 - bump, 88, 36 + bump * 2)
	var mult := Rect2(x + w - 88, 30 - bump, 88, 36 + bump * 2)
	_rounded(chips, Palette.CHIPS, 4)
	_rounded(mult, Palette.MULT, 4)
	_text(str(last_points), Vector2(chips.position.x, 55), M, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, chips.size.x)
	_text(str(last_mult), Vector2(mult.position.x, 55), M, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, mult.size.x)
	_text("×", Vector2(chips.end.x, 55), M, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER, mult.position.x - chips.end.x)
	_text("= %d" % (last_points * last_mult), Vector2(x, 88), M, Palette.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, w)

	# Items, one row each in slot order (= effect order), then the focused one
	_text("%s  %d/%d" % [tr("ITEMS"), session.items.size(), Run.MAX_SLOTS], Vector2(x, 112), S, Palette.MUTED)
	var y := 118.0
	if session.items.is_empty():
		_text(tr("NO_ITEMS"), Vector2(x + 8, y + 16), S, Palette.MUTED)
	var focused: Item = null
	for item in session.items:
		var flash := float(item_flash.get(item.id, 0.0))
		var is_focus := item.id == focus_item
		if is_focus:
			focused = item
		var row := Rect2(x, y, w, 20)
		_panel(row, Palette.GOLD if flash > 0.0 else (Palette.SOFT.darkened(0.4) if is_focus else Palette.PANEL_EDGE),
				Palette.PANEL.lerp(Palette.GOLD, flash * 0.3))
		_text(tr(item.name_key), Vector2(x + 6, y + 15), S, Palette.GOLD if flash > 0.0 else Palette.TEXT)
		y += 22.0
	if focused != null:
		var box := Rect2(x, 236, w, 94)
		_panel(box)
		draw_multiline_string(font, Vector2(x + 8, 256), tr(focused.name_key), HORIZONTAL_ALIGNMENT_LEFT, w - 16, M, 1, Palette.GOLD)
		draw_multiline_string(font, Vector2(x + 8, 278), tr(focused.desc_key), HORIZONTAL_ALIGNMENT_LEFT, w - 16, S, 3, Palette.SOFT)

	_text(tr("HELP_HINT"), Vector2(x, 346), S, Palette.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, w)


func _draw_floaters() -> void:
	for f in floaters:
		var p := f.t / f.life
		var c := f.color
		c.a = 1.0 - p * p
		var pos := f.pos + Vector2(0, -12.0 * p)
		_text(f.text, pos + Vector2(1, 1), f.size, Color(Palette.INK, c.a))  # shadow, readable over anything
		_text(f.text, pos, f.size, c)


func _draw_banner() -> void:
	if banner_t < 0.0 or banner_t > 1.1:
		return
	var p := banner_t / 1.1
	var a := 1.0 if p < 0.7 else 1.0 - (p - 0.7) / 0.3
	var y := TANK_TOP + 76.0 - 10.0 * p
	_text(banner_text, Vector2(TANK_CX - 120 + 2, y + 2), L, Color(Palette.INK, a), HORIZONTAL_ALIGNMENT_CENTER, 240)
	_text(banner_text, Vector2(TANK_CX - 120, y), L, Color(Palette.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, 240)


func _draw_end_overlay() -> void:
	var room := session.room
	draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.6 * Anim.clamp01(end_t / 0.2)))
	var r := Rect2(140, 96, 360, 168)
	draw_set_transform_matrix(Anim.around(r.get_center(), Anim.pop_scale(end_t - 0.05, 0.32)))
	if end_t < 0.05:
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	var won := room.state == Room.State.WON
	_panel(r, Palette.GOLD if won else Palette.BAD)
	var c := HORIZONTAL_ALIGNMENT_CENTER
	_text(tr("ROOM_CLEARED") if won else tr("ROOM_LOST"), Vector2(r.position.x, r.position.y + 40), L,
			Palette.GOLD if won else Palette.BAD, c, r.size.x)
	var why := ""
	if not won:
		why = tr("OUT_OF_LIVES") if session.lives <= 0 else tr("OUT_OF_MOVES")
	_text(why, Vector2(r.position.x, r.position.y + 62), S, Palette.SOFT, c, r.size.x)
	_text(tr("SCORE_OF") % [room.score, room.target], Vector2(r.position.x, r.position.y + 92), M, Palette.TEXT, c, r.size.x)
	_text(tr("END_STATS") % [room.best_chain, room.wrong_moves, room.budget],
			Vector2(r.position.x, r.position.y + 116), S, Palette.SOFT, c, r.size.x)
	_text(tr("CONTINUE"), Vector2(r.position.x, r.position.y + 150), S,
			Color(Palette.TEXT, 0.65 + 0.35 * sin(time * 3.0)), c, r.size.x)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Controls card (H). Each line in the table is "keys|what they do".
func _draw_help() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.7 * Anim.clamp01(overlay_t / 0.15)))
	var lines: Array[String] = [
		"HELP_SELECT", "HELP_SWAP", "HELP_LET_IN", "HELP_RULES", "HELP_DEMO",
		"HELP_MODE", "HELP_CRT", "HELP_LANG", "HELP_TOGGLE",
	]
	var r := Rect2(110, 26, 420, 52 + lines.size() * 26)
	draw_set_transform_matrix(Anim.around(r.get_center(), Anim.pop_scale(overlay_t)))
	_panel(r, Palette.GOLD)
	_text(tr("HELP_TITLE"), Vector2(r.position.x, r.position.y + 30), M, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var y := r.position.y + 62
	for key in lines:
		var parts := tr(key).split("|")
		_text(parts[0], Vector2(r.position.x + 20, y), S, Palette.GOLD)
		if parts.size() > 1:
			_text(parts[1], Vector2(r.position.x + 170, y), S, Palette.TEXT)
		y += 26
	draw_set_transform_matrix(Transform2D.IDENTITY)


## How this room works, with a small picture: shown the first time an
## algorithm appears in a run, and again with I.
func _draw_rules() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.72 * Anim.clamp01(overlay_t / 0.15)))
	var r := Rect2(40, 24, 560, 312)
	draw_set_transform_matrix(Anim.around(r.get_center(), Anim.pop_scale(overlay_t)))
	_panel(r, Palette.GOLD)
	var algo := String(session.room.algorithm.id).to_upper()
	_text(tr("ALGO_" + algo).to_upper(), Vector2(r.position.x, r.position.y + 32), M, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

	# Picture on the left
	if is_bubble():
		_draw_rules_picture_bubble(Vector2(r.position.x + 24, r.position.y + 62))
	else:
		_draw_rules_picture_insertion(Vector2(r.position.x + 24, r.position.y + 62))

	# Rules on the right, one numbered line each
	var x := r.position.x + 196
	var w := r.end.x - 16 - x
	var y := r.position.y + 64
	var keys: Array[String] = []
	for i in range(1, 5):
		keys.append("RULES_%s_%d" % [algo, i])
	if session.feed == RoomSession.FEED_ADVERSARY:
		keys.append("RULES_ADVERSARY")
	for i in keys.size():
		var color := Palette.BAD.lightened(0.2) if keys[i] == "RULES_ADVERSARY" else Palette.TEXT
		_text("%d." % (i + 1), Vector2(x, y), S, Palette.GOLD)
		draw_multiline_string(font, Vector2(x + 20, y), tr(keys[i]), HORIZONTAL_ALIGNMENT_LEFT, w - 20, S, 3, color)
		var lines := mini(3, int(ceil(font.get_string_size(tr(keys[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, S).x / (w - 20))))
		y += 18.0 * maxi(lines, 1) + 10.0
	var blink := 0.65 + 0.35 * sin(time * 3.0)
	_text(tr("RULES_CLOSE"), Vector2(r.position.x, r.end.y - 14), S, Color(Palette.GOLD, blink), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _mini_box(center: Vector2, value: int, outline := Color(0, 0, 0, 0)) -> void:
	var r := Rect2(center - Vector2(28, 10), Vector2(56, 20))
	_rounded(r, Palette.value_color(value, 12), 3)
	if outline.a > 0.0:
		draw_rect(r.grow(2), outline, false, 2.0)
	_text(str(value), Vector2(r.position.x, r.position.y + 16), S, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Bubble: a column with the exit on top; the gold pair 9 over 2 gets swapped.
func _draw_rules_picture_bubble(o: Vector2) -> void:
	var cx := o.x + 60
	draw_dashed_line(Vector2(cx - 40, o.y + 6), Vector2(cx + 40, o.y + 6), Palette.GOLD.darkened(0.3), 1.0, 4.0)
	_text(tr("EXIT"), Vector2(cx - 40, o.y), S, Palette.GOLD.darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER, 80)
	var values := [3, 2, 9, 1]  # top to bottom
	for i in values.size():
		_mini_box(Vector2(cx, o.y + 26 + i * 24), values[i])
	draw_rect(Rect2(cx - 32, o.y + 26 + 24 - 13, 64, 50), Palette.GOLD, false, 1.0)
	_marker(Vector2(cx - 32, o.y + 26 + 36))
	# swap arrows on the right
	var ax := cx + 40
	draw_line(Vector2(ax, o.y + 52), Vector2(ax, o.y + 72), Palette.GOLD, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(ax - 4, o.y + 54), Vector2(ax + 4, o.y + 54), Vector2(ax, o.y + 47)]), Palette.GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(ax - 4, o.y + 70), Vector2(ax + 4, o.y + 70), Vector2(ax, o.y + 77)]), Palette.GOLD)
	_text("9 > 2", Vector2(ax + 10, o.y + 66), S, Palette.GOLD)
	_text(tr("RULES_PIC_BUBBLE"), Vector2(o.x, o.y + 140), S, Palette.SOFT)


## Insertion: the sorted top (green), the gold key pulled out, and the arrow
## to its place between 2 and 5 (it passes 8 and 5: cost 2).
func _draw_rules_picture_insertion(o: Vector2) -> void:
	var cx := o.x + 52
	draw_dashed_line(Vector2(cx - 40, o.y + 6), Vector2(cx + 40, o.y + 6), Palette.GOLD.darkened(0.3), 1.0, 4.0)
	_text(tr("EXIT"), Vector2(cx - 40, o.y), S, Palette.GOLD.darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER, 80)
	var values := [2, 5, 8]
	for i in values.size():
		_mini_box(Vector2(cx, o.y + 26 + i * 24), values[i])
	draw_line(Vector2(cx - 34, o.y + 17), Vector2(cx - 34, o.y + 83), Palette.GOOD, 2.0)
	var key_y := o.y + 26 + 3 * 24
	_mini_box(Vector2(cx + 10, key_y), 4, Palette.GOLD)
	_mini_box(Vector2(cx, key_y + 24), 7)
	var gap_y := o.y + 26 + 12
	_insert_arrow(cx + 40, cx + 30, key_y, gap_y)
	draw_rect(Rect2(cx - 30, gap_y - 1, 60, 2), Palette.GOLD)
	_text(tr("COST_N") % 2, Vector2(cx + 52, (key_y + gap_y) * 0.5 + 6), S, Palette.TEXT)
	_text(tr("RULES_PIC_INSERTION"), Vector2(o.x, o.y + 164), S, Palette.SOFT)


## An elbow arrow from the key (at key_y) up to the gap (at gap_y).
func _insert_arrow(from_x: float, lane_x: float, key_y: float, gap_y: float) -> void:
	var lx := maxf(from_x, lane_x) + 8.0
	var c := Palette.GOLD
	draw_line(Vector2(from_x, key_y), Vector2(lx, key_y), c, 2.0)
	draw_line(Vector2(lx, key_y), Vector2(lx, gap_y), c, 2.0)
	draw_line(Vector2(lx, gap_y), Vector2(lane_x + 6, gap_y), c, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(lane_x, gap_y), Vector2(lane_x + 7, gap_y - 4), Vector2(lane_x + 7, gap_y + 4)]), c)


# --- helpers -----------------------------------------------------------------

func _tank_bottom() -> float:
	return TANK_TOP + session.room.board.capacity * SLOT_H


func _slot_pos(i: int) -> Vector2:
	if is_bubble():
		return Vector2(TANK_CX, _tank_bottom() - (i + 0.5) * SLOT_H)
	return Vector2(TANK_CX, TANK_TOP + (i + 0.5) * SLOT_H)


func _pair_rect(j: int) -> Rect2:
	var top := _slot_pos(j + 1).y - SLOT_H * 0.5
	return Rect2(TANK_CX - TANK_W * 0.5 + 3, top + 1, TANK_W - 6, SLOT_H * 2 - 2)


func _text(s: String, pos: Vector2, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, pos, s, align, width, size, color)


func _panel(r: Rect2, edge := Palette.PANEL_EDGE, fill := Palette.PANEL) -> void:
	draw_rect(r, fill)
	draw_rect(r, edge, false, 1.0)


func _bar(r: Rect2, fraction: float, color: Color) -> void:
	draw_rect(r, Palette.PANEL_EDGE)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(fraction, 0.0, 1.0), r.size.y)), color)


func _rounded(r: Rect2, color: Color, radius: int) -> void:
	var key := "%s|%d" % [color.to_html(), radius]
	var sb: StyleBoxFlat = _style_cache.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = false
		_style_cache[key] = sb
	draw_style_box(sb, r)


## Jersey 10 (OFL, assets/fonts), drawn without smoothing: crisp at S, M and L.
static func load_pixel_font() -> Font:
	var base := load(FONT_PATH) as FontFile
	if base == null:
		return ThemeDB.fallback_font
	var f := base.duplicate() as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


static func _ease_in_out(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)
