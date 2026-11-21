extends Node2D
## One room drawn at 640×360, for any algorithm. All rules live in core/;
## this node draws the board, animates what the event bus reports, and turns
## input into moves. The run screen gives it a session and listens for
## `continue_pressed` once the room is over.
##
## Every algorithm uses a column:
## - Bubble: index 0 is the bottom; the biggest leaves through the top.
## - Insertion: index 0 is the top; the sorted part grows from the top, the
##   key (first unsorted element) is inserted into it, the smallest leaves.
## - Pancake: index 0 is the bottom, and so is the exit (the plate); the
##   spatula flips everything above it, newcomers drop on top.
## - Quick: index 0 is the top (the exit); brackets mark the segments not yet
##   in place, and a pivot splits its segment.

signal continue_pressed
## The player switched arrivals between moves and time (M); the run keeps it.

const TANK_CX := 300.0
const TANK_TOP := 46.0
const TANK_W := 104.0
const SLOT_H := 32.0
const EL_W := 84.0
const EL_H := 26.0
## Heap rooms draw a tree instead of a column: smaller numbers, centred in
## the space between the panels, under a tray of the popped ones.
const HEAP_CX := 315.0
const HEAP_W := 194.0
const HEAP_EL := Vector2(36, 24)
const HEAP_TRAY_Y := 64.0
const HEAP_TREE_Y := 136.0
const HEAP_LEVEL := 36.0
const HEAP_MEMORY_Y := 278.0
## Heap: x offset of each cell of the tree from HEAP_CX (cell 7 hangs under 3).
const HEAP_X: Array[float] = [0.0, -48.0, 48.0, -72.0, -24.0, 24.0, 72.0, -82.0]
const PANEL_L := 14.0
const PANEL_R := 420.0
const PANEL_R_W := 206.0
## Item rows on the right: the first row's top, and the step between rows.
const ITEM_TOP := 118.0
const ITEM_ROW := 20.0

const SWAP_DUR := 0.14
const ARRIVE_DUR := 0.28
const RISE_DUR := 0.12
const POP_DUR := 0.24
const CHAIN_STEP := 0.16
const DEMO_STEP := 0.32
const CURSED_COLOR := Color("b04ad6")
## A number lying burnt side up (the Burnt Stack boss).
const BURNT_COLOR := Color("3a2418")
const BURNT_EDGE := Color("e0823a")
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
	var effects: Array[Dictionary] = []


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
var floor_no := 1
var room_kind: StringName = &"fight"
var bits := 0
var mode := RoomSession.ArrivalMode.TURNS
var demo := false
var help_open := false
## The rules card of this room's algorithm (I). Opens by itself the first
## time an algorithm shows up in a run. The room waits while a card is open.
var rules_open := false
## The boss card: who you are fighting and what it does. Opens on a boss room.
var boss_intro_open := false
## Seconds since the boss started aiming (for the warning to pop in).
var aim_t := 0.0
var overlay_t := 0.0
var intro_t := 0.0
var end_t := 0.0

var selected := 0
## Ship rooms: how many ready numbers E ships (-1 = all of them; Q lowers it).
var ship_n := -1
var banner_sub := ""
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
var banner_color := Palette.GOLD
## Red screen flash (boss phase two).
var rage_flash := 0.0
var banner_delay := 0.0
var banner_t := 9.0
var demo_timer := 0.0
## Played when the banner shows (a hand with a pattern, the boss's rage).
var banner_sound: StringName = &""
## The end-of-room sound plays once, with the result card.
var end_sound_done := false
## The shipment (or classic chain) being scored: its length and mult, so the
## last number can land with a sound sized to it.
var ship_total := 0
var ship_mult := 0
## Last frame's values, so a sound plays once when a line is crossed.
var last_ready := 0
var last_budget := 0
var last_ships := 0
var last_free := 0
var time := 0.0

var font: Font
var _style_cache: Dictionary = {}


func _ready() -> void:
	font = load_pixel_font()


func set_session(p_session: RoomSession, p_room_no: int, p_room_total: int, p_kind: StringName, p_bits: int,
		show_rules := false, p_floor := 1) -> void:
	session = p_session
	floor_no = p_floor
	intro_t = 0.0
	end_t = 0.0
	overlay_t = 0.0
	rules_open = show_rules
	boss_intro_open = p_kind == Run.BOSS
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
	ship_n = -1
	var bus := session.bus
	# Added after the items, so the screen sees the final points and mult.
	bus.on(Events.SWAP, _on_swap)
	bus.on(Events.INSERT, _on_insert)
	bus.on(Events.FLIP, _on_flip)
	bus.on(Events.PARTITION, _on_partition)
	bus.on(Events.MERGE, _on_merge)
	bus.on(Events.SIFT, _on_sift)
	bus.on(Events.POP, _on_pop)
	bus.on(Events.MEMORY_FREED, _on_memory_freed)
	bus.on(Events.WRONG_MOVE, _on_wrong)
	bus.on(Events.SURFACE, _on_surface)
	bus.on(Events.CHAIN, _on_chain)
	bus.on(Events.HAND, _on_hand)
	bus.on(Events.OVERFLOW, _on_overflow)
	bus.on(Events.ITEM_TRIGGERED, _on_item_triggered)
	bus.on(Events.BOSS_AIM, _on_boss_aim)
	bus.on(Events.BOSS_STRIKE, _on_boss_strike)
	bus.on(Events.BOSS_DODGED, _on_boss_dodged)
	bus.on(Events.BOSS_ENRAGED, _on_boss_enraged)
	bus.on(Events.BOSS_SHIELD, _on_boss_shield)
	bus.on(Events.ARRIVE, _on_arrive)
	banner_sound = &""
	end_sound_done = false
	ship_total = 0
	ship_mult = 0
	last_ready = session.room.ready_count()
	last_budget = session.room.budget
	last_ships = session.room.ships_left
	last_free = session.room.board.capacity - session.room.board.size()
	if boss_intro_open:
		Sfx.play(&"boss_intro")
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


## Arrivals by moves or by time (changed in the settings).
func set_arrival_mode(new_mode: RoomSession.ArrivalMode) -> void:
	mode = new_mode
	if session != null:
		session.set_mode(new_mode)


func is_bubble() -> bool:
	return session.room.algorithm.id == Algorithms.BUBBLE


func is_pancake() -> bool:
	return session.room.algorithm.id == Algorithms.PANCAKE


func is_insertion() -> bool:
	return session.room.algorithm.id == Algorithms.INSERTION


func is_quick() -> bool:
	return session.room.algorithm.id == Algorithms.QUICK


func is_merge() -> bool:
	return session.room.algorithm.id == Algorithms.MERGE


func is_heap() -> bool:
	return session.room.algorithm.id == Algorithms.HEAP


## Merge: the first cell of every run that has a next run (what SPACE merges).
func _merge_starts() -> Array[int]:
	var out: Array[int] = []
	for m in session.room.algorithm.legal_moves(session.room.board):
		out.append(int(m["index"]))
	return out


## Heap: how many cells from the bottom form the tree.
func _tree_size() -> int:
	return (session.room.algorithm as HeapAlgorithm).tree_size(session.room.board)


## Heap: what SPACE may act on. Every child whose lift is right now (bigger
## than its parent and not smaller than its sibling): the red lines. With
## none left the tree is a heap, and the root is the one choice (a pop).
func _heap_choices() -> Array[int]:
	var out: Array[int] = []
	var h := _tree_size()
	var algo := session.room.algorithm
	for i in range(1, h):
		if not algo.is_wrong(session.room.board, {"type": Events.SIFT, "index": i}):
			out.append(i)
	if out.is_empty() and h > 0:
		out.append(0)
	return out


## Heap: the selection if it is still a choice, else the first choice (the
## top red line, or the root). Shipments, arrivals and the boss change the
## tree between key presses, so this is asked whenever it is used.
func _heap_selected() -> int:
	var c := _heap_choices()
	if c.is_empty():
		return -1
	return selected if c.has(selected) else c[0]


func _heap_default() -> int:
	var c := _heap_choices()
	return c[0] if not c.is_empty() else 0


## Size of a drawn number: smaller in the Heap tree.
func _el_size() -> Vector2:
	return HEAP_EL if is_heap() else Vector2(EL_W, EL_H)


## Heap: where cell i is drawn. Tree cells by level, root on top; popped
## cells in the tray at the exit, the first to ship on the left, 4 a row.
func _heap_pos(i: int) -> Vector2:
	var h := _tree_size()
	if i >= h:
		var k := session.room.board.size() - 1 - i
		return Vector2(HEAP_CX + (k % 4 - 1.5) * 44.0, HEAP_TRAY_Y + (k / 4) * 30.0)
	var level := 0
	while (1 << (level + 1)) - 1 <= i:
		level += 1
	return Vector2(HEAP_CX + _heap_x(i), HEAP_TREE_Y + level * HEAP_LEVEL)


func _heap_x(i: int) -> float:
	if i < HEAP_X.size():
		return HEAP_X[i]
	return _heap_x(HeapAlgorithm.parent(i)) + (-10.0 if i % 2 == 1 else 10.0)


## Quick: true for every number already in its final place (not a pivot).
func _placed() -> Array[bool]:
	return (session.room.algorithm as QuickAlgorithm).placed(session.room.board)


## Bubble, Pancake and Heap stack from the bottom: index 0 is the lowest cell.
func _bottom_up() -> bool:
	return is_bubble() or is_pancake() or is_heap()


## The exit is over the last cell (Bubble, Heap), not over cell 0.
func _exit_at_end() -> bool:
	return is_bubble() or is_heap()


## Where scored numbers fly to: over the column, or under it in Pancake.
func _exit_pos() -> Vector2:
	if is_heap():
		return Vector2(HEAP_CX, TANK_TOP - 14.0)
	return Vector2(TANK_CX, _tank_bottom() + 14.0) if is_pancake() else Vector2(TANK_CX, TANK_TOP - 14.0)


func is_ship() -> bool:
	return session.room.manual_ship


## How many numbers E would ship now (0 when nothing is ready); at most
## Room.max_ship, however long the ready run is.
func ship_count() -> int:
	var ready := session.room.shippable()
	if ready == 0:
		return 0
	return ready if ship_n < 0 else clampi(ship_n, 1, ready)


func _ship() -> void:
	var n := ship_count()
	if n > 0 and session.play({"type": Events.SHIP, "count": n}):
		ship_n = -1
		Sfx.play(&"ship")


## Q: ship one fewer, wrapping back to all of them.
func _ship_fewer() -> void:
	var n := ship_count()
	if n == 0:
		return
	ship_n = n - 1 if n > 1 else -1
	Sfx.play(&"cursor")


## Board index of the number under `p`, or -1.
func _cell_at(p: Vector2) -> int:
	if is_heap():
		for i in session.room.board.size():
			if Rect2(_slot_pos(i) - HEAP_EL * 0.5, HEAP_EL).grow(2).has_point(p):
				return i
		return -1
	if absf(p.x - TANK_CX) > TANK_W * 0.5:
		return -1
	for i in session.room.board.size():
		if absf(_slot_pos(i).y - p.y) <= SLOT_H * 0.5:
			return i
	return -1


## How far from the exit cell `i` is, counting the exit cell as 1.
func _exit_distance(i: int) -> int:
	return session.room.board.size() - i if _exit_at_end() else i + 1


func is_boss() -> bool:
	return room_kind == Run.BOSS


func is_over() -> bool:
	return not session.is_playing() and ghosts.is_empty()


# --- input -----------------------------------------------------------------

func handle_input(event: InputEvent, local: Vector2) -> void:
	if session == null:
		return
	if boss_intro_open or rules_open or help_open:
		# Any of these closes the top card; nothing else happens meanwhile.
		var close := false
		if event is InputEventKey and event.pressed and not event.echo:
			close = event.keycode in [KEY_SPACE, KEY_ENTER, KEY_I, KEY_H]
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close = true
		if close:
			if boss_intro_open:
				boss_intro_open = false
				overlay_t = 0.0
				Sfx.play(&"confirm")
			else:
				rules_open = false
				help_open = false
				Sfx.play(&"card_close")
		return
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if is_over():
			if not key.echo and key.keycode in [KEY_SPACE, KEY_ENTER]:
				Sfx.play(&"confirm")
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
			KEY_E:
				if not key.echo and is_ship():
					_ship()
			KEY_Q:
				if not key.echo and is_ship():
					_ship_fewer()
			KEY_H:
				if not key.echo:
					help_open = true
					overlay_t = 0.0
					Sfx.play(&"card_open")
			KEY_I:
				if not key.echo:
					rules_open = true
					overlay_t = 0.0
					Sfx.play(&"card_open")
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
			MOUSE_BUTTON_RIGHT:
				# Right-click a ready number: ship up to it (click again to ship).
				var c := _cell_at(local)
				if is_ship() and not is_over() and c >= 0:
					var d := _exit_distance(c)
					if d <= session.room.shippable():
						if d == ship_count():
							_ship()
						else:
							ship_n = d
			MOUSE_BUTTON_LEFT:
				if is_over():
					Sfx.play(&"confirm")
					continue_pressed.emit()
					return
				var j := _target_at(local)
				if j >= 0:
					if j == selected:
						_act(j)
					else:
						selected = j
						Sfx.play(&"cursor")


## +1 = up on screen.
func _step_selection(direction: int) -> void:
	var lo_hi := _selection_range()
	if lo_hi.y < lo_hi.x:
		return
	var before := selected
	if is_heap():
		# Up the list toward the root, down toward the leaves.
		var choices := _heap_choices()
		if choices.is_empty():
			return
		selected = maxi(_heap_selected(), 0)
		var k := choices.find(selected)
		k = clampi(k - direction, 0, choices.size() - 1) if k >= 0 else 0
		if choices[k] != selected:
			selected = choices[k]
			Sfx.play(&"cursor")
		return
	if is_merge():
		# From one run to the next: each run start is a merge.
		var starts := _merge_starts()
		var k := starts.find(selected)
		k = clampi(k - direction, 0, starts.size() - 1) if k >= 0 else 0
		if starts[k] != selected:
			selected = starts[k]
			Sfx.play(&"cursor")
		return
	if is_quick():
		# Skip the numbers already in place: only the others can be pivots.
		var done := _placed()
		var j := selected
		while true:
			j -= direction
			if j < 0 or j >= done.size():
				return
			if not done[j]:
				break
		selected = j
		Sfx.play(&"cursor")
		return
	selected += direction if _bottom_up() else -direction
	selected = clampi(selected, lo_hi.x, lo_hi.y)
	if selected != before:
		Sfx.play(&"cursor")


## Bubble: pairs 0..size-2. Insertion: places 0..k-1 before the key at k.
## Pancake: the lowest flipped number, up to the one under the top (or the
## top itself when numbers have sides).
func _selection_range() -> Vector2i:
	var board := session.room.board
	if is_bubble():
		return Vector2i(0, board.size() - 2)
	if is_pancake():
		var sides := (session.room.algorithm as PancakeAlgorithm).burnt_sides
		return Vector2i(0, board.size() - (1 if sides else 2))
	if is_quick():
		return Vector2i(0, board.size() - 1) if _placed().has(false) else Vector2i(0, -1)
	if is_merge():
		return Vector2i(0, board.size() - 1) if not _merge_starts().is_empty() else Vector2i(0, -1)
	if is_heap():
		return Vector2i(0, _tree_size() - 1)
	var k := board.sorted_prefix_length()
	if k >= board.size():
		return Vector2i(0, -1)
	return Vector2i(0, k - 1)


func _reset_selection() -> void:
	var r := _selection_range()
	if is_heap():
		selected = maxi(_heap_selected(), 0)
		return
	if is_merge():
		# Keep a run start that is still one, else the run nearest the exit.
		var starts := _merge_starts()
		if not starts.has(selected):
			selected = starts[0] if not starts.is_empty() else 0
		return
	if is_quick():
		# Keep a pivot that is still one, else the first number not in place.
		var done := _placed()
		if selected < 0 or selected >= done.size() or done[selected]:
			selected = maxi(done.find(false), 0)
	elif _bottom_up():
		selected = clampi(selected, r.x, maxi(r.y, 0))
	else:
		selected = maxi(r.y, 0)  # nearest place: costs 1


func _act(target: int) -> void:
	if is_heap():
		target = target if _heap_choices().has(target) else _heap_selected()
		if target < 0:
			return
	var wrong_before := session.room.wrong_moves
	var move := {"type": Events.INSERT, "to": target}
	if is_bubble():
		move = {"type": Events.SWAP, "index": target}
	elif is_pancake():
		move = {"type": Events.FLIP, "index": target}
	elif is_quick():
		move = {"type": Events.PARTITION, "index": target}
	elif is_merge():
		move = {"type": Events.MERGE, "index": target}
	elif is_heap():
		move = {"type": Events.POP} if target == 0 else {"type": Events.SIFT, "index": target}
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
	elif is_heap():
		# The next red line from the top, or the root once the tree is a heap.
		selected = _heap_default()
	else:
		_reset_selection()


func _target_at(p: Vector2) -> int:
	var board := session.room.board
	if is_heap():
		var c := _cell_at(p)
		return c if _heap_choices().has(c) else -1
	if absf(p.x - TANK_CX) > TANK_W * 0.5:
		return -1
	var r := _selection_range()
	if r.y < r.x:
		return -1
	var j: int
	if is_bubble():
		j = int(roundf((_tank_bottom() - p.y) / SLOT_H)) - 1
	elif is_pancake():
		j = int(floorf((_tank_bottom() - p.y) / SLOT_H))
	elif is_merge():
		# A click anywhere on a run picks it; the last run merges with the one before.
		j = int(floorf((p.y - TANK_TOP) / SLOT_H))
		if j < 0 or j >= board.size():
			return -1
		var pick := -1
		for st in _merge_starts():
			if st <= j:
				pick = st
		return pick
	elif is_quick():
		j = int(floorf((p.y - TANK_TOP) / SLOT_H))
		if j >= 0 and j < board.size() and _placed()[j]:
			return -1
	else:
		j = int(floorf((p.y - TANK_TOP) / SLOT_H))
	return j if j >= r.x and j <= r.y and j < board.size() else -1


func _item_row_at(p: Vector2) -> int:
	if p.x < PANEL_R or p.x > PANEL_R + PANEL_R_W:
		return -1
	var i := int(floorf((p.y - ITEM_TOP) / ITEM_ROW))
	return i if i >= 0 and i < session.items.size() else -1


# --- bus events --------------------------------------------------------------

func _on_swap(data: Dictionary) -> void:
	if not data["wrong"]:
		Sfx.play(&"swap")
	var j: int = data["move"]["index"]
	var cells := session.room.board.cells
	pending_arc[cells[j].uid] = -12.0
	pending_arc[cells[j + 1].uid] = 12.0


func _on_insert(data: Dictionary) -> void:
	if not data["wrong"]:
		Sfx.play(&"insert")
	var p: int = data["move"]["to"]
	pending_arc[session.room.board.cells[p].uid] = 22.0  # the key swings out and in


## A flip: the flipped numbers swing out to the right, further the further
## they travel. A number turned over alone stays put.
func _on_flip(data: Dictionary) -> void:
	if not data["wrong"]:
		Sfx.play(&"flip")
	var i: int = data["move"]["index"]
	var cells := session.room.board.cells
	var top := cells.size() - 1
	for k in range(i, top + 1):
		pending_arc[cells[k].uid] = 10.0 + 4.0 * absf(2 * k - i - top)


## A split: every number that moves swings out a little on its way.
func _on_partition(_data: Dictionary) -> void:
	Sfx.play(&"partition")
	for e in session.room.board.cells:
		pending_arc[e.uid] = 10.0


## A merge: the numbers of both runs swing out on their way into one run.
func _on_merge(data: Dictionary) -> void:
	Sfx.play(&"merge")
	var cells := session.room.board.cells
	var s0: int = data["move"]["index"]
	for k in range(s0, cells.size()):
		pending_arc[cells[k].uid] = 8.0


func _on_sift(data: Dictionary) -> void:
	if not data["wrong"]:
		Sfx.play(&"swap")
	var i: int = data["move"]["index"]
	var cells := session.room.board.cells
	pending_arc[cells[HeapAlgorithm.parent(i)].uid] = 14.0
	pending_arc[cells[i].uid] = -14.0


## A pop: the root and the last leaf trade places with a wide swing.
func _on_pop(data: Dictionary) -> void:
	if not data["wrong"]:
		Sfx.play(&"pop")
	var cells := session.room.board.cells
	var top := _tree_size()  # a popped root now sits right over the tree
	if top < cells.size():
		pending_arc[cells[top].uid] = 26.0
	pending_arc[cells[0].uid] = -26.0


func _on_memory_freed(_data: Dictionary) -> void:
	Sfx.play(&"heal")
	var text := tr("MEMORY_FREED")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, M).x
	_float(text, Vector2(TANK_CX - w * 0.5, TANK_TOP + 20), Palette.GOOD, M)


func _on_wrong(data: Dictionary) -> void:
	Sfx.play(&"wrong")
	var move: Dictionary = data["move"]
	var j: int = move.get("index", move.get("to", 0))
	if is_bubble():
		_float(tr("WRONG_SWAP"), Vector2(TANK_CX + TANK_W * 0.5 + 14, _slot_pos(j).y - 8), Palette.BAD, S)
	elif is_heap():
		var key := "WRONG_POP" if move.get("type") == Events.POP else "WRONG_SIFT"
		_float(tr(key), Vector2(TANK_CX + TANK_W * 0.5 + 34, _slot_pos(j).y - 8), Palette.BAD, S)
	elif is_pancake():
		_float(tr("WRONG_FLIP"), Vector2(TANK_CX + TANK_W * 0.5 + 14, _slot_pos(j).y - 8), Palette.BAD, S)
	else:
		var text := tr("WRONG_INSERT")
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, M).x
		_float(text, Vector2(TANK_CX - w * 0.5, _slot_pos(j).y + 6), Palette.BAD, M)


func _on_surface(data: Dictionary) -> void:
	var ctx: ScoreContext = data["ctx"]
	var g := Ghost.new()
	g.value = ctx.element.value
	var v: Vis = vis.get(ctx.element.uid)
	g.start = v.pos if v != null else _slot_pos(session.room.board.size() if _exit_at_end() else 0)
	g.pos = g.start
	g.chain = ctx.chain
	g.delay = SWAP_DUR + (ctx.chain - 1) * CHAIN_STEP
	g.points = ctx.points
	g.mult = ctx.mult
	g.gained = ctx.total()
	g.notes = ctx.notes.duplicate()
	g.effects = ctx.effects.duplicate(true)
	ghosts.append(g)
	vis.erase(ctx.element.uid)


func _on_chain(data: Dictionary) -> void:
	if is_ship():
		return  # the hand banner says more
	var length: int = data["length"]
	banner_text = tr("CHAIN_BANNER") % length
	banner_sound = &"pattern"
	ship_total = length
	ship_mult = mini(length, Room.CHAIN_CAP)
	banner_sub = ""
	banner_color = Palette.GOLD
	banner_delay = SWAP_DUR + (length - 1) * CHAIN_STEP + RISE_DUR
	banner_t = -1.0


## A shipment: "×mult" big, and the patterns it made under it.
func _on_hand(data: Dictionary) -> void:
	var count: int = data["count"]
	banner_text = "×%d" % int(data["mult"])
	banner_sub = hand_names(data["patterns"])
	banner_color = Palette.GOLD if not (data["patterns"] as Array).is_empty() else Palette.TEXT
	banner_sound = &"pattern" if not (data["patterns"] as Array).is_empty() else &""
	ship_total = count
	ship_mult = int(data["mult"])
	if _is_fanfare():
		banner_sound = &""  # the fanfare on the last number says it already
	banner_delay = SWAP_DUR + (count - 1) * CHAIN_STEP + RISE_DUR
	banner_t = -1.0


func hand_names(patterns: Array) -> String:
	var names: Array[String] = []
	for p in patterns:
		names.append(tr("HAND_" + String(p).to_upper()))
	return " + ".join(names)


func _on_overflow(data: Dictionary) -> void:
	# The Fuse sets "absorbed" before us: it then costs nothing.
	if data["absorbed"]:
		_float(tr("FUSE_BLOWN"), Vector2(TANK_CX + TANK_W * 0.5 + 14, TANK_TOP + 60), Palette.GOLD, S)
		return
	Sfx.play(&"overflow")
	shake = 5.0
	tank_flash = 0.5
	_float(tr("OVERFLOW"), Vector2(TANK_CX + TANK_W * 0.5 + 14, TANK_TOP + 60), Palette.BAD, S)


func _on_item_triggered(data: Dictionary) -> void:
	var id: StringName = data["id"]
	Sfx.play(&"item")
	item_flash[id] = 0.6
	focus_item = id
	var label: String = data.get("label", "")
	if label != "":
		_item_float(id, tr(label), Palette.GOLD)


func _on_boss_aim(_data: Dictionary) -> void:
	aim_t = 0.0
	Sfx.play(&"boss_aim")


func _on_boss_strike(data: Dictionary) -> void:
	Sfx.play(&"boss_strike")
	if data["mode"] == RoomSession.STRIKE_SCORCH:
		var i: int = data["index"]
		shake = 5.0
		tank_flash = 0.5
		var st := tr("BOSS_SCORCH")
		var sw := font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, L).x
		_float(st, Vector2(TANK_CX - sw * 0.5, _slot_pos(i).y + 10), BURNT_EDGE, L)
		return
	if data["mode"] == RoomSession.STRIKE_LEAK:
		shake = 5.0
		tank_flash = 0.5
		var lt := tr("BOSS_LEAK_HIT")
		var lw := font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, L).x
		var ly := HEAP_MEMORY_Y - 6.0 if is_heap() else _slot_pos(session.room.board.capacity).y + 10
		_float(lt, Vector2(_slot_pos(0).x - lw * 0.5, ly), Palette.BAD, L)
		return
	if data["mode"] == RoomSession.STRIKE_THROW:
		shake = 5.0
		tank_flash = 0.5
		var t := tr("BOSS_THROW")
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, L).x
		_float(t, Vector2(TANK_CX - tw * 0.5, _tank_bottom() - 20), Palette.BAD, L)
		return
	var j: int = data["index"]
	var cells := session.room.board.cells
	pending_arc[cells[j].uid] = 16.0
	pending_arc[cells[j + 1].uid] = -16.0
	shake = 6.0
	tank_flash = 0.6
	var text := tr("BOSS_STRIKE")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, L).x
	_float(text, Vector2(TANK_CX - w * 0.5, _slot_pos(j).y + 10), Palette.BAD, L)


func _on_boss_enraged(_data: Dictionary) -> void:
	banner_text = tr("BOSS_ENRAGED")
	banner_sound = &"boss_enraged"
	banner_sub = ""
	banner_color = Palette.BAD
	banner_delay = 0.0
	banner_t = -1.0
	rage_flash = 1.0
	shake = 8.0


## The phase shield stopped points: say how many, in shield blue.
func _on_boss_shield(data: Dictionary) -> void:
	Sfx.play(&"shield")
	var text := tr("BOSS_SHIELD") % int(data["blocked"])
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, M).x
	_float(text, Vector2(TANK_CX - w * 0.5, TANK_TOP + 90), Palette.CHIPS, M)


func _on_boss_dodged(_data: Dictionary) -> void:
	Sfx.play(&"boss_dodged")
	var text := tr("BOSS_DODGED")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, M).x
	_float(text, Vector2(TANK_CX - w * 0.5, TANK_TOP + 120), Palette.GOOD, M)


## A short text right over the item's row (what that item just did).
func _item_float(id: StringName, text: String, color: Color) -> void:
	var i := -1
	for k in session.items.size():
		if session.items[k].id == id:
			i = k
	if i < 0:
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, M).x
	var f := Floater.new()
	f.text = text
	f.pos = Vector2(PANEL_R + PANEL_R_W - w - 6, ITEM_TOP + i * ITEM_ROW + 15.0)
	f.color = color
	f.size = M
	f.life = 1.0
	floaters.append(f)


# --- update ------------------------------------------------------------------

func _process(delta: float) -> void:
	if session == null:
		return
	time += delta
	intro_t += delta
	overlay_t += delta
	end_t = end_t + delta if is_over() else 0.0
	_sound_cues()
	if is_over() and not end_sound_done:
		end_sound_done = true
		var won := session.room.state == Room.State.WON
		Sfx.play((&"boss_defeated" if is_boss() else &"room_won") if won else &"room_lost")
	aim_t += delta
	var paused := boss_intro_open or rules_open or help_open
	if demo and boss_intro_open and overlay_t > 2.0:
		boss_intro_open = false
		overlay_t = 0.0
	elif demo and rules_open and overlay_t > 1.6:
		rules_open = false  # the demo reads the card, then plays
	if not paused:
		session.update(delta)
	if demo and session.is_playing() and not paused and intro_t > 0.6:
		demo_timer += delta
		if demo_timer >= DEMO_STEP:
			demo_timer = 0.0
			var move := Bots.choose_in(session)
			if move.is_empty():
				session.deliver()
				_reset_selection()
			elif move.get("type") == Events.SHIP:
				ship_n = int(move["count"])
				_ship()
			else:
				selected = move.get("index", move.get("to", 0))
				_act(selected)
	var r := _selection_range()
	if r.y >= r.x:
		selected = clampi(selected, r.x, r.y)
	if is_quick():
		_reset_selection()  # a ship or an arrival can put the pivot in place

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
			if banner_sound != &"":
				Sfx.play(banner_sound)
				banner_sound = &""
	else:
		banner_t += delta

	shown_score = lerpf(shown_score, float(score_target), 1.0 - exp(-10.0 * delta))
	if absf(shown_score - score_target) < 0.5:
		shown_score = score_target
	formula_bump = maxf(formula_bump - delta * 3.0, 0.0)
	shake = maxf(shake - delta * 18.0, 0.0)
	tank_flash = maxf(tank_flash - delta, 0.0)
	rage_flash = maxf(rage_flash - delta * 1.5, 0.0)
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
	var exit_pos := _exit_pos()
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
	Sfx.play(&"score", Sfx.score_pitch(g.chain))
	if g.chain >= 4:
		Sfx.play(&"chips")  # at its own pitch, under the note
	# Items that added to this number show it over their rows; a glass ping
	# on every number as well was too much.
	if g.chain == ship_total and ship_total >= 3:
		# The last number of a shipment: a chord, bigger the longer it was.
		Sfx.play(&"combo_big" if ship_total >= 7 else (&"combo_mid" if ship_total >= 5 else &"combo_small"))
		if _is_fanfare():
			Sfx.play(&"combo_fanfare")
	score_target += g.gained
	last_points = g.points
	last_mult = g.mult
	formula_bump = 1.0
	for id in g.notes:
		item_flash[id] = 0.6
		focus_item = id
	for fx in g.effects:
		var kind: StringName = fx["kind"]
		var amount: int = fx["amount"]
		var mult_side := kind == ScoreContext.MULT or kind == ScoreContext.XMULT
		var text := ("×%d" if kind == ScoreContext.XMULT or kind == ScoreContext.XPOINTS else "+%d") % amount
		_item_float(fx["id"], text, Palette.MULT.lightened(0.2) if mult_side else Palette.CHIPS.lightened(0.2))
	# One line per score while earlier ones are still visible, so nothing overlaps.
	# Bubble: right of the column. Insertion keeps that side for the key and
	# its arrow, so its scores go on the left.
	var fy := TANK_TOP + 10.0 + (pop_line % 9) * 16.0
	pop_line += 1
	var fx := TANK_CX + TANK_W * 0.5 + 14 if _bottom_up() else TANK_CX - TANK_W * 0.5 - 38
	if is_heap():
		# Over the tray, which empties as the shipment leaves.
		fx = HEAP_CX - HEAP_W * 0.5 + 4
		fy = HEAP_TRAY_Y - 8.0 + (pop_line % 3) * 16.0
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
	if is_boss():
		# A boss room glows red from the edges, slowly breathing.
		var angry := session.enraged
		var glow := (0.16 + 0.08 * sin(time * 4.0)) if angry else (0.10 + 0.04 * sin(time * 1.6))
		for k in 6:
			draw_rect(Rect2(k * 6, k * 6, 640 - k * 12, 360 - k * 12), Color(Palette.BAD, glow * (1.0 - k / 6.0)), false, 6.0)
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
	if rage_flash > 0.0:
		draw_rect(Rect2(0, 0, 640, 360), Color(Palette.BAD, 0.35 * rage_flash))
	if is_over():
		_draw_end_overlay()
	if boss_intro_open:
		_draw_boss_intro()
	elif rules_open:
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
	_text(tr("FLOOR_N") % floor_no, Vector2(x, 39), S, Palette.MUTED, right, w)

	if is_boss():
		# Every point you score is damage: the bar empties as the boss loses.
		_panel(Rect2(x, 46, w, 66), Palette.BAD.darkened(0.2))
		Icons.draw_boss(self, Rect2(x + w - 40, 52, 32, 32), 1.0, session.boss)
		_text(tr("BOSS_HP_" + String(session.boss).to_upper()) + ("  " + tr("BOSS_PHASE_2") if session.enraged else ""), Vector2(x + 8, 62), S, Palette.BAD.lightened(0.2))
		var hp := maxi(room.target - int(shown_score), 0)
		_text(str(hp), Vector2(x + 8, 94), L, Palette.TEXT)
		_text("/ %d" % room.target, Vector2(x + 8, 94), S, Palette.MUTED, right, w - 56)
		_bar(Rect2(x + 8, 101, w - 16, 5), float(hp) / float(room.target), Palette.BAD)
		if room.score_cap >= 0:
			# The phase shield: points stop here until the boss is enraged.
			var sx := x + 8 + (w - 16) * (1.0 - float(room.score_cap) / float(room.target))
			draw_rect(Rect2(sx - 1, 97, 2, 13), Palette.CHIPS)
	else:
		_panel(Rect2(x, 46, w, 66))
		_text(tr("SCORE"), Vector2(x + 8, 62), S, Palette.MUTED)
		_text(str(int(shown_score)), Vector2(x + 8, 94), L, Palette.TEXT)
		_text("/ %d" % room.target, Vector2(x + 8, 94), M, Palette.MUTED, right, w - 16)
		_bar(Rect2(x + 8, 101, w - 16, 5), shown_score / float(room.target), Palette.GOLD)

	# Move budget, and in a ship room with a limit the shipments next to it
	_panel(Rect2(x, 118, w, 40))
	var low := room.budget <= 8
	var moves_w := w - 16
	if session.ships_max > 0:
		moves_w = (w - 32) / 2.0
		_draw_ships(Rect2(x + 24 + moves_w, 118, moves_w, 40))
		draw_line(Vector2(x + 16 + moves_w, 124), Vector2(x + 16 + moves_w, 152), Palette.PANEL_EDGE)
	_text(tr("MOVES"), Vector2(x + 8, 136), S, Palette.MUTED)
	_text(("%d/%d" if session.ships_max > 0 else "%d / %d") % [room.budget, session.budget_max],
			Vector2(x + 8, 137), M, Palette.TEXT, right, moves_w)
	_bar(Rect2(x + 8, 146, moves_w, 4), float(room.budget) / float(session.budget_max), Palette.BAD if low else Palette.CHIPS)

	# Lives and bits
	_panel(Rect2(x, 164, w, 30))
	_text(tr("LIVES"), Vector2(x + 8, 184), S, Palette.MUTED)
	for i in session.max_lives:
		var r := Rect2(x + 58 + i * 18, 171, 16, 16)
		Icons.draw_glyph(self, &"heart" if i < session.lives else &"heart_empty", r,
				Palette.BAD if i < session.lives else Palette.PANEL_EDGE.lightened(0.2))
	var bits_text := "%s %d" % [tr("BITS"), bits]
	var bits_w := font.get_string_size(bits_text, HORIZONTAL_ALIGNMENT_LEFT, -1, S).x
	Icons.draw_glyph(self, &"coin", Rect2(x + w - 8 - bits_w - 20, 171, 16, 16), Palette.GOLD)
	_text(bits_text, Vector2(x + 8, 184), S, Palette.GOLD, right, w - 16)

	if is_ship():
		_draw_ship_box(Rect2(x, 200, w, 50))
	else:
		# Stats
		_panel(Rect2(x, 200, w, 50))
		_text(tr("BEST_CHAIN"), Vector2(x + 8, 220), S, Palette.MUTED)
		_text("×%d" % room.best_chain, Vector2(x + 8, 220), M, Palette.GOLD, right, w - 16)
		_text(tr("WRONG_MOVES"), Vector2(x + 8, 241), S, Palette.MUTED)
		_text(str(room.wrong_moves), Vector2(x + 8, 241), M, Palette.BAD if room.wrong_moves > 0 else Palette.TEXT, right, w - 16)

	# Arrivals
	_panel(Rect2(x, 256, w, 46))
	_text(tr("ARRIVALS"), Vector2(x + 8, 274), S, Palette.MUTED)
	var how := tr(_count_key("EVERY_N_MOVES", session.every_moves)) % session.every_moves if mode == RoomSession.ArrivalMode.TURNS else tr("EVERY_N_SEC") % int(session.interval_sec)
	_text(how, Vector2(x + 8, 274), S, Palette.TEXT, right, w - 16)
	_text(tr("LET_IN_NOW"), Vector2(x + 8, 293), S, Palette.SOFT)

	# How this room works; in a boss room, when it strikes next
	if session.boss != RoomSession.BOSS_NONE:
		var aiming := session.is_aiming()
		var warn := tr("BOSS_STRIKES_IN_" + String(session.boss).to_upper()) % session.moves_to_strike
		if aiming:
			warn = tr("BOSS_AIMING_THROW")
			if session.strike_mode == RoomSession.STRIKE_SWAP:
				warn = tr("BOSS_AIMING")
			elif session.strike_mode == RoomSession.STRIKE_SCORCH:
				warn = tr("BOSS_AIMING_SCORCH")
		var a := 0.6 + 0.4 * sin(time * 10.0) if aiming else 1.0
		_panel(Rect2(x, 308, w, 40), Palette.BAD if aiming else Palette.BAD.darkened(0.4))
		draw_multiline_string(font, Vector2(x + 8, 324), warn, HORIZONTAL_ALIGNMENT_LEFT, w - 16, S, 2, Color(Palette.BAD.lightened(0.3), a))
	else:
		var hint := ("HINT_SHIP_" if is_ship() else "HINT_") + String(room.algorithm.id).to_upper()
		draw_multiline_string(font, Vector2(x, 320), tr(hint), HORIZONTAL_ALIGNMENT_LEFT, w, S, 2, Palette.SOFT)


## Shipments left in a ship room: a count and one square per shipment
## (filled = still there). The last one blinks red.
func _draw_ships(r: Rect2) -> void:
	var left := session.room.ships_left
	var last := left == 1 and session.is_playing()
	var a := 0.55 + 0.45 * sin(time * 8.0) if last else 1.0
	_text(tr("SHIPS"), Vector2(r.position.x, 136), S, Palette.MUTED)
	_text("%d/%d" % [left, session.ships_max], Vector2(r.position.x, 137), M,
			Color(Palette.BAD, a) if last else Palette.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x)
	var n := session.ships_max
	var gap := 2.0
	var pip := floorf((r.size.x - gap * (n - 1)) / n)
	for i in n:
		var p := Rect2(r.position.x + i * (pip + gap), 145, pip, 6)
		if i < left:
			draw_rect(p, Color(Palette.BAD, a) if last else Palette.GOOD)
		else:
			draw_rect(p, Palette.PANEL_EDGE, false, 1.0)


## What E would ship now: how many, the hand's mult and its patterns.
func _draw_ship_box(box: Rect2) -> void:
	var n := ship_count() if session.is_playing() else 0
	var right := HORIZONTAL_ALIGNMENT_RIGHT
	var x := box.position.x
	var w := box.size.x
	if n == 0:
		_panel(box)
		_text(tr("SHIP_NOTHING"), Vector2(x + 8, box.position.y + 20), S, Palette.MUTED)
		_text(tr("SHIP_KEYS"), Vector2(x + 8, box.position.y + 41), S, Palette.MUTED)
		return
	var values: Array[int] = []
	for e in session.room.ship_preview(n):
		values.append(e.value)
	var hand := Hands.evaluate(values)
	var patterns: Array = hand["patterns"]
	var pulse := 0.5 + 0.5 * sin(time * 5.0)
	_panel(box, Palette.GOLD.lerp(Palette.PANEL_EDGE, 0.5 * pulse) if not patterns.is_empty() else Palette.GOOD.darkened(0.3))
	_text(tr("SHIP_N") % n, Vector2(x + 8, box.position.y + 20), S, Palette.TEXT)
	_text("×%d" % int(hand["mult"]), Vector2(x + 8, box.position.y + 21), M, Palette.GOLD, right, w - 16)
	var sub := hand_names(patterns) if not patterns.is_empty() else tr("SHIP_KEYS")
	if patterns.is_empty() and session.room.ready_count() > session.room.shippable():
		sub = tr("SHIP_CAP") % session.room.max_ship  # the run is longer than one shipment
	_text(sub, Vector2(x + 8, box.position.y + 41), S, Palette.GOLD if not patterns.is_empty() else Palette.MUTED)


func _draw_tank() -> void:
	var board := session.room.board
	var cap := session.full_capacity
	var bottom := _tank_bottom()
	var r := Rect2(TANK_CX - TANK_W * 0.5, TANK_TOP, TANK_W, cap * SLOT_H)
	if is_heap():
		r = Rect2(HEAP_CX - HEAP_W * 0.5, TANK_TOP, HEAP_W, cap * SLOT_H)
	draw_rect(r, Palette.TANK)
	for i in range(1, cap if not is_heap() else 0):
		var y := TANK_TOP + i * SLOT_H
		draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), Palette.SLOT_LINE, 1.0)
	var edge := Palette.PANEL_EDGE.lerp(Palette.BAD, 0.45) if is_boss() else Palette.PANEL_EDGE
	if tank_flash > 0.0:
		edge = edge.lerp(Palette.BAD, tank_flash * 2.0)
	elif board.is_full():
		edge = edge.lerp(Palette.BAD, 0.4 + 0.3 * sin(time * 8.0))
	draw_rect(r, edge, false, 1.0)
	_draw_leaked(r)

	# Exit line: over the column, or under it in Pancake (the plate)
	var exit_y := bottom + 4.0 if is_pancake() else TANK_TOP - 4.0
	var exit_text_y := bottom + 20.0 if is_pancake() else TANK_TOP - 9.0
	draw_dashed_line(Vector2(r.position.x - 6, exit_y), Vector2(r.end.x + 6, exit_y), Palette.GOLD.darkened(0.3), 1.0, 4.0)
	_text(tr("EXIT"), Vector2(r.position.x, exit_text_y), S, Palette.GOLD.darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

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
	elif is_pancake():
		_draw_spatula(r, playing)
	elif is_quick():
		_draw_quick_guides(r, playing)
	elif is_merge():
		_draw_merge_guides(r, playing)
	elif is_heap():
		_draw_heap_guides(r, playing)
	else:
		_draw_insertion_guides(r, playing)
	if is_ship() and playing and not is_heap():
		_draw_ship_bracket(r)
	if playing and session.is_aiming_cells():
		_draw_aim(r)
	if playing and session.strike_mode == RoomSession.STRIKE_LEAK:
		_draw_leak_aim(r)

	# Next arrival: under the column, or over it in Pancake (it drops on top)
	var nb := Rect2(r.get_center().x - TANK_W * 0.5, bottom + 5, TANK_W, 40)
	if is_pancake():
		nb = Rect2(r.position.x, 3, TANK_W, 36)
	var throwing := playing and session.strike_mode == RoomSession.STRIKE_THROW
	if throwing:
		var a := 0.6 + 0.4 * sin(time * 10.0)
		_panel(nb, Color(Palette.BAD, a), Palette.PANEL.lerp(Palette.BAD, 0.25 * a))
		Icons.draw_boss(self, Rect2(nb.position.x - 24, nb.get_center().y - 8, 16, 16), a, session.boss)
	else:
		_panel(nb)
	var line2 := nb.size.y - 6.0
	_text(tr("NEXT"), Vector2(nb.position.x + 6, nb.position.y + line2 - 17), S, Palette.MUTED)
	var info := tr("IN_N_MOVES") % session.moves_until_arrival() if mode == RoomSession.ArrivalMode.TURNS else "%.1f s" % (session.interval_sec - session.timer)
	_text(info, Vector2(nb.position.x + 6, nb.position.y + line2), S, Palette.TEXT)
	var chip := Rect2(nb.end.x - 34, nb.get_center().y - 13, 28, 26)
	_rounded(chip, Palette.value_color(session.next_value, session.vmax), 3)
	_text(str(session.next_value), Vector2(chip.position.x, chip.position.y + 19), M, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, chip.size.x)
	_bar(Rect2(nb.position.x, nb.end.y + 2, nb.size.x, 3), session.arrival_progress(), Palette.GOLD)


## Ship rooms: a green bracket along the ready run at the exit, gold over
## the part E would ship.
func _draw_ship_bracket(r: Rect2) -> void:
	var ready := session.room.ready_count()
	if ready == 0:
		return
	var bx := r.position.x - 11
	var whole := _run_span(ready)
	draw_line(Vector2(bx, whole.x), Vector2(bx, whole.y), Palette.GOOD, 2.0)
	var part := _run_span(ship_count())
	var a := 0.7 + 0.3 * sin(time * 5.0)
	var c := Color(Palette.GOLD, a)
	draw_line(Vector2(bx - 1, part.x), Vector2(bx - 1, part.y), c, 3.0)
	draw_line(Vector2(bx - 1, part.x), Vector2(bx + 4, part.x), c, 2.0)
	draw_line(Vector2(bx - 1, part.y), Vector2(bx + 4, part.y), c, 2.0)


## Top and bottom y of the `count` cells nearest the exit. Bubble stacks from
## the bottom, so its run is the top of the stack, not the top of the tank.
func _run_span(count: int) -> Vector2:
	var size := session.room.board.size()
	var near := size - 1 if _exit_at_end() else 0
	var far := size - count if _exit_at_end() else count - 1
	var y1 := minf(_slot_pos(near).y, _slot_pos(far).y) - SLOT_H * 0.5 + 3.0
	var y2 := maxf(_slot_pos(near).y, _slot_pos(far).y) + SLOT_H * 0.5 - 3.0
	return Vector2(y1, y2)


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


## Pancake: the spatula under the selected number, its handle out to the
## right, and a bracket over what it would flip.
func _draw_spatula(r: Rect2, playing: bool) -> void:
	var board := session.room.board
	if not playing or board.is_empty():
		return
	var rr := _selection_range()
	if rr.y < rr.x:
		return
	if hover >= 0 and hover != selected:
		var hy := _slot_pos(hover).y + SLOT_H * 0.5
		draw_line(Vector2(r.position.x + 4, hy), Vector2(r.end.x - 4, hy), Palette.MUTED, 1.0)
	var sy := _slot_pos(selected).y + SLOT_H * 0.5
	var top_y := _slot_pos(board.size() - 1).y - SLOT_H * 0.5
	var pulse := 0.75 + 0.25 * sin(time * 6.0)
	# The blade under the number, the handle out of the column.
	draw_rect(Rect2(r.position.x + 2, sy - 1.5, TANK_W - 4, 3), Color(Palette.GOLD, pulse))
	draw_line(Vector2(r.end.x - 2, sy), Vector2(r.end.x + 22, sy - 6), Palette.GOLD, 2.0)
	draw_rect(Rect2(r.end.x + 20, sy - 10, 14, 6), Palette.GOLD.darkened(0.25))
	_marker(Vector2(r.position.x, sy))
	# What turns over: a bracket from the blade up to the top.
	var bx := r.end.x + 8
	var c := Color(Palette.GOLD, 0.8)
	draw_line(Vector2(bx, top_y + 3), Vector2(bx, sy - 8), c, 2.0)
	draw_line(Vector2(bx, top_y + 3), Vector2(bx - 5, top_y + 3), c, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(bx - 4, sy - 10), Vector2(bx + 4, sy - 10), Vector2(bx, sy - 4)]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(bx - 4, top_y + 9), Vector2(bx + 4, top_y + 9), Vector2(bx, top_y + 3)]), c)


## Quick: a bracket on the right of every segment not yet in place, the
## pivot framed in gold, and what the split would cost.
func _draw_quick_guides(r: Rect2, playing: bool) -> void:
	var board := session.room.board
	var algo := session.room.algorithm as QuickAlgorithm
	for seg in algo.segments(board):
		var y1 := TANK_TOP + seg.x * SLOT_H + 3.0
		var y2 := TANK_TOP + seg.y * SLOT_H - 3.0
		var bx := r.end.x + 6
		var c := Palette.SOFT.darkened(0.2)
		draw_line(Vector2(bx, y1), Vector2(bx, y2), c, 2.0)
		draw_line(Vector2(bx - 4, y1), Vector2(bx, y1), c, 2.0)
		draw_line(Vector2(bx - 4, y2), Vector2(bx, y2), c, 2.0)
	if not playing:
		return
	var rr := _selection_range()
	if rr.y < rr.x:
		return
	var done := algo.placed(board)
	if hover >= 0 and hover != selected and hover < done.size() and not done[hover]:
		var hp := _slot_pos(hover)
		draw_rect(Rect2(hp - Vector2(EL_W, EL_H) * 0.5, Vector2(EL_W, EL_H)).grow(3), Palette.MUTED, false, 1.0)
	if selected < 0 or selected >= done.size() or done[selected]:
		return
	var sp := _slot_pos(selected)
	var pulse := 0.75 + 0.25 * sin(time * 6.0)
	draw_rect(Rect2(sp - Vector2(EL_W, EL_H) * 0.5, Vector2(EL_W, EL_H)).grow(3), Color(Palette.GOLD, pulse), false, 2.0)
	_marker(Vector2(r.position.x, sp.y))
	var lane := r.end.x + 16
	_text(tr("PIVOT"), Vector2(lane, sp.y - 2), S, Palette.GOLD)
	var cost := algo.move_cost(board, {"type": Events.PARTITION, "index": selected})
	_text(tr("COST_N") % cost, Vector2(lane, sp.y + 14), S, Palette.BAD if cost > session.room.budget else Palette.TEXT)


## Merge: a bracket on the right of every run, the selected pair of runs
## framed in gold, and what merging them would cost.
func _draw_merge_guides(r: Rect2, playing: bool) -> void:
	var board := session.room.board
	var algo := session.room.algorithm as MergeAlgorithm
	var c := Palette.SOFT.darkened(0.2)
	for run in algo.runs(board):
		var y1 := TANK_TOP + run.x * SLOT_H + 3.0
		var y2 := TANK_TOP + run.y * SLOT_H - 3.0
		var bx := r.end.x + 6
		draw_line(Vector2(bx, y1), Vector2(bx, y2), c, 2.0)
		draw_line(Vector2(bx - 4, y1), Vector2(bx, y1), c, 2.0)
		draw_line(Vector2(bx - 4, y2), Vector2(bx, y2), c, 2.0)
	if not playing:
		return
	if hover >= 0 and hover != selected:
		var hp := algo.pair_at(board, hover)
		if not hp.is_empty():
			draw_rect(Rect2(r.position.x + 2, TANK_TOP + hp[0].x * SLOT_H + 1, TANK_W - 4, (hp[1].y - hp[0].x) * SLOT_H - 2), Palette.MUTED, false, 1.0)
	var pair := algo.pair_at(board, selected)
	if pair.is_empty():
		return
	var y1 := TANK_TOP + pair[0].x * SLOT_H + 1
	var y2 := TANK_TOP + pair[1].y * SLOT_H - 1
	var pulse := 0.75 + 0.25 * sin(time * 6.0)
	draw_rect(Rect2(r.position.x + 1, y1, TANK_W - 2, y2 - y1), Color(Palette.GOLD, pulse), false, 2.0)
	# Where the two runs meet.
	var my := TANK_TOP + pair[1].x * SLOT_H
	draw_line(Vector2(r.position.x + 6, my), Vector2(r.end.x - 6, my), Color(Palette.GOLD, 0.5 * pulse), 1.0)
	_marker(Vector2(r.position.x, (y1 + y2) * 0.5))
	var lane := r.end.x + 16
	var cy := (y1 + y2) * 0.5
	_text(tr("MERGE_LABEL"), Vector2(lane, cy - 2), S, Palette.GOLD)
	var cost := algo.move_cost(board, {"type": Events.MERGE, "index": selected})
	_text(tr("COST_N") % cost, Vector2(lane, cy + 14), S, Palette.BAD if cost > session.room.budget else Palette.TEXT)


## Heap: the tree's lines (red where a lift is right now, so a heap has no
## red line), the tray of popped numbers at the exit, what to do next, what
## SPACE would do to the selected number, and the memory meter.
func _draw_heap_guides(r: Rect2, playing: bool) -> void:
	var board := session.room.board
	var h := _tree_size()
	var choices := _heap_choices()
	var sel := _heap_selected()
	var half := HEAP_EL.y * 0.5
	var pulse := 0.75 + 0.25 * sin(time * 6.0)
	for i in range(1, h):
		var a := _slot_pos(HeapAlgorithm.parent(i)) + Vector2(0, half)
		var b := _slot_pos(i) - Vector2(0, half)
		var c := Palette.SOFT.darkened(0.35)
		var wdt := 1.0
		if choices.has(i):
			c = Color(Palette.GOLD, pulse) if playing and sel == i else Palette.BAD
			wdt = 2.0
		draw_line(a, b, c, wdt)
	# The tray and the tree apart.
	var sep := HEAP_TREE_Y - 24.0
	draw_line(Vector2(r.position.x + 8, sep), Vector2(r.end.x - 8, sep), Palette.SLOT_LINE, 1.0)
	_draw_memory(r)
	if h == 0:
		return
	var heap_ok := choices == [0]
	var status := tr("HEAP_READY") if heap_ok else tr("HEAP_FIX")
	# Under the tree, over the memory meter, clear of the pop arrow.
	_text(status, Vector2(r.position.x, HEAP_MEMORY_Y - 8), S, Palette.GOLD if heap_ok else Palette.BAD.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if not playing:
		return
	if hover >= 0 and hover != sel and choices.has(hover):
		draw_rect(Rect2(_slot_pos(hover) - HEAP_EL * 0.5, HEAP_EL).grow(3), Palette.MUTED, false, 1.0)
	if sel < 0:
		return
	var sp := _slot_pos(sel)
	draw_rect(Rect2(sp - HEAP_EL * 0.5, HEAP_EL).grow(3), Color(Palette.GOLD, pulse), false, 2.0)
	_marker(Vector2(sp.x - HEAP_EL.x * 0.5 - 3, sp.y))
	if sel == 0 and heap_ok:
		# A pop: the root goes up into the tray.
		var top := Vector2(sp.x, sp.y - half - 3)
		var end := Vector2(sp.x, sep - 4)
		draw_line(top, end, Color(Palette.GOLD, pulse), 2.0)
		draw_colored_polygon(PackedVector2Array([end + Vector2(-4, 5), end + Vector2(4, 5), end]), Color(Palette.GOLD, pulse))


## Heap: one cell per place in memory: taken, free, or lost to the Memory Leak.
func _draw_memory(r: Rect2) -> void:
	var board := session.room.board
	_text(tr("MEMORY"), Vector2(_memory_cell(0).position.x - _memory_label_w() - 8, HEAP_MEMORY_Y + 10), S, Palette.MUTED)
	var warn := board.is_full()
	for i in session.full_capacity:
		var cell := _memory_cell(i)
		if i >= board.capacity:
			draw_rect(cell, Palette.BG.darkened(0.4))
			draw_line(cell.position, cell.end, Palette.BAD, 1.0)
			draw_line(Vector2(cell.position.x, cell.end.y), Vector2(cell.end.x, cell.position.y), Palette.BAD, 1.0)
		elif i < board.size():
			var c := Palette.GOLD
			if warn:
				c = c.lerp(Palette.BAD, 0.5 + 0.3 * sin(time * 8.0))
			draw_rect(cell, c)
		else:
			draw_rect(cell, Palette.PANEL_EDGE, false, 1.0)


func _memory_label_w() -> float:
	return font.get_string_size(tr("MEMORY"), HORIZONTAL_ALIGNMENT_LEFT, -1, S).x


## The meter's cell i; the label and the cells are centred together.
func _memory_cell(i: int) -> Rect2:
	var n := session.full_capacity
	var w := n * 14.0 - 4.0 + _memory_label_w() + 8.0
	var x0 := HEAP_CX - w * 0.5 + _memory_label_w() + 8.0
	return Rect2(x0 + i * 14.0, HEAP_MEMORY_Y, 10, 10)


## Heap: the Memory Leak aims at the last free cell of the meter, and at the
## tree's last leaf when memory is full.
func _draw_leak_aim_heap() -> void:
	var a := 0.6 + 0.4 * sin(time * 10.0)
	var cell := _memory_cell(session.room.board.capacity - 1)
	draw_rect(cell.grow(3), Color(Palette.BAD, a), false, 2.0)
	Icons.draw_boss(self, Rect2(cell.end.x + 6, cell.position.y - 3, 16, 16), a, session.boss)
	var board := session.room.board
	for k in board.size():
		if board.cells[k].uid in session.strike_uids:
			draw_rect(Rect2(_slot_pos(k) - HEAP_EL * 0.5, HEAP_EL).grow(3), Color(Palette.BAD, a), false, 2.0)


## The Memory Leak's lost cells: dark and crossed, at the top of the column.
func _draw_leaked(r: Rect2) -> void:
	if is_heap():
		return  # the memory meter shows them
	var board := session.room.board
	for i in range(board.capacity, session.full_capacity):
		var y := _slot_pos(i).y - SLOT_H * 0.5
		var cell := Rect2(r.position.x + 1, y + 1, r.size.x - 2, SLOT_H - 2)
		draw_rect(cell, Palette.BG.darkened(0.4))
		draw_line(cell.position, cell.end, Palette.PANEL_EDGE, 1.0)
		draw_line(Vector2(cell.position.x, cell.end.y), Vector2(cell.end.x, cell.position.y), Palette.PANEL_EDGE, 1.0)
		Icons.draw_boss(self, Rect2(cell.get_center() - Vector2(8, 8), Vector2(16, 16)), 0.6, RoomSession.BOSS_LEAK)


## The cell the Memory Leak takes after your next move, and the number in it
## when the column is full.
func _draw_leak_aim(r: Rect2) -> void:
	if is_heap():
		_draw_leak_aim_heap()
		return
	var i := session.room.board.capacity - 1
	var y := _slot_pos(i).y - SLOT_H * 0.5
	var grow := 6.0 * (1.0 - Anim.ease_out_back(aim_t / 0.3))
	var a := 0.6 + 0.4 * sin(time * 10.0)
	var box := Rect2(r.position.x - 2 - grow, y - grow, r.size.x + 4 + grow * 2, SLOT_H + grow * 2)
	draw_rect(box, Color(Palette.BAD, a), false, 2.0)
	var sign_pos := Vector2(box.position.x - 26, box.get_center().y - 12)
	Icons.draw_boss(self, Rect2(sign_pos, Vector2(16, 16)), a, session.boss)
	_text("!", Vector2(sign_pos.x + 5, sign_pos.y + 34), M, Color(Palette.BAD, a))
	var board := session.room.board
	for k in board.size():
		if board.cells[k].uid in session.strike_uids:
			var vp := _slot_pos(k)
			draw_rect(Rect2(vp - Vector2(EL_W, EL_H) * 0.5, Vector2(EL_W, EL_H)).grow(2), Color(Palette.BAD, a), false, 2.0)


## What the boss will hit after your next move (a pair to swap, a number to
## scorch): a red pulsing frame and a warning sign. Move it first to dodge.
func _draw_aim(r: Rect2) -> void:
	var board := session.room.board
	var idx: Array[int] = []
	for i in board.size():
		if board.cells[i].uid in session.strike_uids:
			idx.append(i)
	if idx.is_empty():
		return
	var y1 := _slot_pos(idx[0]).y
	var y2 := y1
	for i in idx:
		y1 = minf(y1, _slot_pos(i).y)
		y2 = maxf(y2, _slot_pos(i).y)
	y1 -= SLOT_H * 0.5
	y2 += SLOT_H * 0.5
	var grow := 6.0 * (1.0 - Anim.ease_out_back(aim_t / 0.3))
	var a := 0.6 + 0.4 * sin(time * 10.0)
	var box := Rect2(r.position.x - 2 - grow, y1 - grow, r.size.x + 4 + grow * 2, y2 - y1 + grow * 2)
	draw_rect(box, Color(Palette.BAD, a), false, 2.0)
	var sign_pos := Vector2(box.position.x - 26, box.get_center().y - 12)
	Icons.draw_boss(self, Rect2(sign_pos, Vector2(16, 16)), a, session.boss)
	_text("!", Vector2(sign_pos.x + 5, sign_pos.y + 34), M, Color(Palette.BAD, a))


func _marker(at: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(at.x - 9, at.y - 5), Vector2(at.x - 3, at.y), Vector2(at.x - 9, at.y + 5)]), Palette.GOLD)


func _draw_elements() -> void:
	var board := session.room.board
	if board.is_empty():
		return
	# The element that leaves next: the biggest in Bubble, the smallest in Insertion.
	var leaver := board.max_value() if _bottom_up() else board.min_value()
	var key_index := board.sorted_prefix_length() if is_insertion() else -1
	var ready_now := session.room.ready_count() if is_ship() else 0
	var ship_n_now := ship_count() if is_ship() and session.is_playing() else 0
	for i in board.size():
		var e := board.cells[i]
		var v: Vis = vis.get(e.uid)
		if v == null:
			continue
		var size := _el_size()
		var r := Rect2(v.pos - size * 0.5, size)
		if i == key_index and session.is_playing():
			r.position.x += KEY_PULL  # the key sticks out: it is in your hand
		var burnt := e.has_marker(Element.BURNT)
		var c := Palette.value_color(e.value, session.vmax)
		if burnt:
			c = c.lerp(BURNT_COLOR, 0.65)
		c.a = v.alpha
		_rounded(r, c, 4)
		if i == key_index and session.is_playing():
			draw_rect(r.grow(2), Palette.GOLD, false, 2.0)
		elif is_ship():
			var d := _exit_distance(i)
			if d <= ship_n_now:
				draw_rect(r.grow(2), Color(Palette.GOLD, 0.6 + 0.3 * sin(time * 5.0)), false, 1.0)
			elif d <= ready_now:
				draw_rect(r.grow(2), Color(Palette.GOOD, 0.7), false, 1.0)
		elif e.value == leaver:
			draw_rect(r.grow(2), Color(Palette.GOLD, 0.5 + 0.3 * sin(time * 5.0)), false, 1.0)
		var ink := Palette.TEXT if burnt else Palette.INK
		_text(str(e.value), Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 7), M, Color(ink, v.alpha), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if NumberProps.is_prime(e.value):
			draw_rect(Rect2(r.position.x + 4, r.position.y + 4, 3, 3), Color(Palette.INK, 0.6 * v.alpha))
		if e.has_marker(Element.CURSED):
			draw_rect(r.grow(1), Color(CURSED_COLOR, v.alpha), false, 2.0)
			Icons.draw_boss(self, Rect2(r.end.x - 18, r.position.y + 5, 16, 16), v.alpha)
		if burnt:
			draw_rect(r.grow(1), Color(BURNT_EDGE, v.alpha), false, 1.0)
			Icons.draw_glyph(self, &"flame", Rect2(r.end.x - 18, r.position.y + 5, 16, 16), Color(BURNT_EDGE, v.alpha))


func _draw_ghosts() -> void:
	for g in ghosts:
		var c := Palette.value_color(g.value, session.vmax)
		var s := 1.0
		if g.popped:
			var p := clampf((g.t - RISE_DUR) / POP_DUR, 0.0, 1.0)
			s = 1.0 + 0.6 * p
			c.a = 1.0 - p
			draw_arc(g.pos, 10.0 + 40.0 * p, 0.0, TAU, 24, Color(Palette.GOLD, 1.0 - p), 1.0)
		var size := _el_size() * s
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
	var y := ITEM_TOP
	if session.items.is_empty():
		_text(tr("NO_ITEMS"), Vector2(x + 8, y + 16), S, Palette.MUTED)
	var focused: Item = null
	for item in session.items:
		var flash := float(item_flash.get(item.id, 0.0))
		var is_focus := item.id == focus_item
		if is_focus:
			focused = item
		var row := Rect2(x, y, w, ITEM_ROW - 2)
		_panel(row, Palette.GOLD if flash > 0.0 else (Palette.SOFT.darkened(0.4) if is_focus else Palette.PANEL_EDGE),
				Palette.PANEL.lerp(Palette.GOLD, flash * 0.3))
		var bounce := 2.0 * sin(clampf(flash / 0.6, 0.0, 1.0) * PI)
		Icons.draw(self, item.id, Rect2(x + 1, y + 1 - bounce, 16, 16))
		_text(tr(item.name_key), Vector2(x + 24, y + 14), S, Palette.GOLD if flash > 0.0 else Palette.TEXT)
		y += ITEM_ROW
	if focused != null:
		# Under the last possible row, so it never moves as items are added.
		var top := ITEM_TOP + Run.MAX_SLOTS * ITEM_ROW + 4.0
		var box := Rect2(x, top, w, 336.0 - top)
		_panel(box)
		Icons.draw(self, focused.id, Rect2(box.end.x - 34, box.position.y + 6, 28, 28))
		draw_multiline_string(font, Vector2(x + 8, top + 20), tr(focused.name_key), HORIZONTAL_ALIGNMENT_LEFT, w - 50, M, 1, Palette.GOLD)
		draw_multiline_string(font, Vector2(x + 8, top + 46), tr(focused.desc_key), HORIZONTAL_ALIGNMENT_LEFT, w - 16, S, 3, Palette.SOFT)

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
	_text(banner_text, Vector2(TANK_CX - 120, y), L, Color(banner_color, a), HORIZONTAL_ALIGNMENT_CENTER, 240)
	if banner_sub != "":
		_text(banner_sub, Vector2(TANK_CX - 150 + 1, y + 23), M, Color(Palette.INK, a), HORIZONTAL_ALIGNMENT_CENTER, 300)
		_text(banner_sub, Vector2(TANK_CX - 150, y + 22), M, Color(banner_color, a), HORIZONTAL_ALIGNMENT_CENTER, 300)


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
	var title := tr("ROOM_LOST")
	if won:
		title = tr("BOSS_DEFEATED") if is_boss() else tr("ROOM_CLEARED")
	_text(title, Vector2(r.position.x, r.position.y + 40), L,
			Palette.GOLD if won else Palette.BAD, c, r.size.x)
	var why := ""
	if not won:
		why = tr("OUT_OF_MOVES")
		if session.lives <= 0:
			why = tr("OUT_OF_LIVES")
		elif room.manual_ship and room.ships_left == 0:
			why = tr("OUT_OF_SHIPS")
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
		"HELP_SELECT", "HELP_SWAP", "HELP_LET_IN", "HELP_RULES", "HELP_MENU", "HELP_TOGGLE",
	]
	if is_ship():
		lines.insert(2, "HELP_SHIP")
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
	var r := Rect2(40, 10, 560, 340)
	draw_set_transform_matrix(Anim.around(r.get_center(), Anim.pop_scale(overlay_t)))
	_panel(r, Palette.GOLD)
	var algo := String(session.room.algorithm.id).to_upper()
	_text(tr("ALGO_" + algo).to_upper(), Vector2(r.position.x, r.position.y + 32), M, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

	# Picture on the left
	if is_bubble():
		_draw_rules_picture_bubble(Vector2(r.position.x + 24, r.position.y + 62))
	elif is_pancake():
		_draw_rules_picture_pancake(Vector2(r.position.x + 24, r.position.y + 62))
	elif is_quick():
		_draw_rules_picture_quick(Vector2(r.position.x + 24, r.position.y + 62))
	elif is_merge():
		_draw_rules_picture_merge(Vector2(r.position.x + 24, r.position.y + 62))
	elif is_heap():
		_draw_rules_picture_heap(Vector2(r.position.x + 24, r.position.y + 62))
	else:
		_draw_rules_picture_insertion(Vector2(r.position.x + 24, r.position.y + 62))

	# Rules on the right, one numbered line each
	var x := r.position.x + 196
	var w := r.end.x - 16 - x
	var y := r.position.y + 64
	var keys: Array[String] = []
	# Ship rooms drop the lines about numbers leaving by themselves (and
	# Pancake's line about the exit: the picture and the ship lines say it).
	# Heap keeps its lift and pop lines; its picture shows the tree.
	var numbers := [1, 2, 3, 4]
	if is_ship():
		numbers = [1, 3] if is_bubble() or is_pancake() else ([2, 3] if is_heap() else [1, 2, 3])
	for i in numbers:
		keys.append("RULES_%s_%d" % [algo, i])
	if is_ship():
		keys.append("RULES_SHIP_1")
		keys.append("RULES_SHIP_2")
		if session.ships_max > 0:
			keys.append("RULES_SHIP_3")
	var boss_rules := "RULES_" + String(session.boss).to_upper()
	if session.boss != RoomSession.BOSS_NONE:
		keys.append(boss_rules)
	var gap := 10.0 if keys.size() < 6 else 4.0
	for i in keys.size():
		var color := Palette.BAD.lightened(0.2) if keys[i] == boss_rules else Palette.TEXT
		_text("%d." % (i + 1), Vector2(x, y), S, Palette.GOLD)
		draw_multiline_string(font, Vector2(x + 20, y), _rule_text(keys[i]), HORIZONTAL_ALIGNMENT_LEFT, w - 20, S, 3, color)
		# The real wrapped height, so the next line never overlaps (wraps differ by language).
		y += font.get_multiline_string_size(_rule_text(keys[i]), HORIZONTAL_ALIGNMENT_LEFT, w - 20, S, 3).y + gap
	var blink := 0.65 + 0.35 * sin(time * 3.0)
	_text(tr("RULES_CLOSE"), Vector2(r.position.x, r.end.y - 10), S, Color(Palette.GOLD, blink), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## The row for a text with a count of moves: Polish says "2-4 ruchy" but
## "5 ruchów", so a count of 5 or more (but 22-24 again) reads the _MANY row.
static func _count_key(key: String, n: int) -> String:
	var few := n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 12 or n % 100 > 14)
	return key if few or n == 1 else key + "_MANY"


## A rule line; the shipping rule names the shipment cap.
func _rule_text(key: String) -> String:
	return tr(key) % Run.MAX_SHIP if key == "RULES_SHIP_1" else tr(key)


## The boss card: a red flash, the boss's face, its name and what it does.
func _draw_boss_intro() -> void:
	var t := overlay_t
	draw_rect(Rect2(0, 0, 640, 360), Color(0.04, 0.0, 0.0, 0.93 * Anim.clamp01(t / 0.2)))
	# A red flash at the very start.
	if t < 0.25:
		draw_rect(Rect2(0, 0, 640, 360), Color(Palette.BAD, 0.5 * (1.0 - t / 0.25)))
	var c := HORIZONTAL_ALIGNMENT_CENTER
	# The face grows in and keeps breathing.
	var face := 96.0 * (0.6 + 0.4 * Anim.ease_out_back(t / 0.45)) * (1.0 + 0.03 * sin(time * 3.0))
	Icons.draw_boss(self, Rect2(Vector2(320, 104) - Vector2(face, face) * 0.5, Vector2(face, face)), Anim.clamp01(t / 0.2), session.boss)
	# "BOSS" slams down with a little shake.
	var slam := Anim.clamp01((t - 0.3) / 0.2)
	if slam > 0.0:
		var jitter := Vector2(randf_range(-2, 2), randf_range(-2, 2)) * (1.0 - slam) * 3.0
		draw_set_transform_matrix(Anim.around(Vector2(320, 184), 1.8 - 0.8 * Anim.ease_out_cubic(slam)))
		_text(tr("BOSS_LABEL"), Vector2(0, 196) + jitter, L, Color(Palette.BAD, slam), c, 640)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	var a := Anim.clamp01((t - 0.55) / 0.3)
	var boss := String(session.boss).to_upper()
	_text(tr("BOSS_NAME_" + boss), Vector2(0, 222), M, Color(Palette.GOLD, a), c, 640)
	# One under another by their real wrapped height (wraps differ by language).
	var y := 248.0
	var lines: Array = [
		[tr("BOSS_INTRO_%s_1" % boss), Palette.TEXT],
		[tr(_count_key("BOSS_INTRO_%s_2" % boss, session.strike_every)) % session.strike_every, Palette.TEXT],
		[tr("BOSS_INTRO_SHIELD"), Palette.CHIPS.lightened(0.2)],
	]
	for line in lines:
		draw_multiline_string(font, Vector2(50, y), line[0], c, 540, S, 3, Color(line[1], a))
		y += font.get_multiline_string_size(line[0], c, 540, S, 3).y + 2.0
	var blink := 0.65 + 0.35 * sin(time * 3.0)
	_text(tr("BOSS_FIGHT"), Vector2(0, 348), M, Color(Palette.BAD.lightened(0.2), a * blink), c, 640)


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
	draw_multiline_string(font, Vector2(o.x, o.y + 140), tr("RULES_PIC_BUBBLE"), HORIZONTAL_ALIGNMENT_LEFT, 160, S, 2, Palette.SOFT)


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
	draw_multiline_string(font, Vector2(o.x, o.y + 164), tr("RULES_PIC_INSERTION"), HORIZONTAL_ALIGNMENT_LEFT, 160, S, 2, Palette.SOFT)


## Pancake: a stack on a plate (the exit at the bottom); the spatula goes
## under 9, so 9 and 3 above it turn over and 9 lands on top.
func _draw_rules_picture_pancake(o: Vector2) -> void:
	var cx := o.x + 52
	var values := [3, 9, 1, 5]  # top to bottom
	for i in values.size():
		_mini_box(Vector2(cx, o.y + 16 + i * 24), values[i])
	var plate_y := o.y + 16 + values.size() * 24 - 8
	draw_dashed_line(Vector2(cx - 40, plate_y), Vector2(cx + 40, plate_y), Palette.GOLD.darkened(0.3), 1.0, 4.0)
	_text(tr("EXIT"), Vector2(cx - 40, plate_y + 16), S, Palette.GOLD.darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER, 80)
	# The spatula under 9, its handle to the right.
	var sy := o.y + 16 + 24 + 12
	draw_rect(Rect2(cx - 30, sy - 1, 60, 3), Palette.GOLD)
	draw_line(Vector2(cx + 30, sy), Vector2(cx + 48, sy - 5), Palette.GOLD, 2.0)
	draw_rect(Rect2(cx + 46, sy - 9, 12, 5), Palette.GOLD.darkened(0.25))
	_marker(Vector2(cx - 30, sy))
	# What turns over: 3 and 9.
	var bx := cx + 40
	draw_line(Vector2(bx, o.y + 6), Vector2(bx, sy - 8), Palette.GOLD, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(bx - 4, o.y + 10), Vector2(bx + 4, o.y + 10), Vector2(bx, o.y + 4)]), Palette.GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(bx - 4, sy - 10), Vector2(bx + 4, sy - 10), Vector2(bx, sy - 4)]), Palette.GOLD)
	draw_multiline_string(font, Vector2(o.x, o.y + 164), tr("RULES_PIC_PANCAKE"), HORIZONTAL_ALIGNMENT_LEFT, 160, S, 2, Palette.SOFT)


## Quick: a segment 5 2 4 8 (exit on top) with pivot 4, and after the split
## 2 4 5 8: 2 went above the pivot, 4 is in its place.
func _draw_rules_picture_quick(o: Vector2) -> void:
	var before := [5, 2, 4, 8]
	var after := [2, 4, 5, 8]
	var lx := o.x + 32
	var rx := o.x + 128
	for cx in [lx, rx]:
		draw_dashed_line(Vector2(cx - 30, o.y + 6), Vector2(cx + 30, o.y + 6), Palette.GOLD.darkened(0.3), 1.0, 4.0)
		_text(tr("EXIT"), Vector2(cx - 30, o.y), S, Palette.GOLD.darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER, 60)
	for i in before.size():
		_mini_box(Vector2(lx, o.y + 26 + i * 24), before[i], Palette.GOLD if before[i] == 4 else Color(0, 0, 0, 0))
		_mini_box(Vector2(rx, o.y + 26 + i * 24), after[i], Palette.GOLD if after[i] == 4 else Color(0, 0, 0, 0))
	# The segment's bracket before the split, and an arrow to the result.
	var by := o.y + 14
	draw_line(Vector2(lx + 34, by + 2), Vector2(lx + 34, by + 94), Palette.SOFT.darkened(0.2), 2.0)
	var ay := o.y + 62
	draw_line(Vector2(lx + 40, ay), Vector2(rx - 38, ay), Palette.GOLD, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(rx - 36, ay), Vector2(rx - 43, ay - 4), Vector2(rx - 43, ay + 4)]), Palette.GOLD)
	draw_multiline_string(font, Vector2(o.x, o.y + 164), tr("RULES_PIC_QUICK"), HORIZONTAL_ALIGNMENT_LEFT, 160, S, 2, Palette.SOFT)


## Merge: runs 3 7 and 2 5 (exit on top), merged into 2 3 5 7 for 3 moves.
func _draw_rules_picture_merge(o: Vector2) -> void:
	var before := [3, 7, 2, 5]
	var after := [2, 3, 5, 7]
	var lx := o.x + 32
	var rx := o.x + 128
	for cx in [lx, rx]:
		draw_dashed_line(Vector2(cx - 30, o.y + 6), Vector2(cx + 30, o.y + 6), Palette.GOLD.darkened(0.3), 1.0, 4.0)
		_text(tr("EXIT"), Vector2(cx - 30, o.y), S, Palette.GOLD.darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER, 60)
	for i in before.size():
		_mini_box(Vector2(lx, o.y + 26 + i * 24), before[i])
		_mini_box(Vector2(rx, o.y + 26 + i * 24), after[i])
	# One bracket per run before, one around the merged run after.
	var c := Palette.SOFT.darkened(0.2)
	for run: Vector2 in [Vector2(0, 2), Vector2(2, 4)]:
		draw_line(Vector2(lx + 34, o.y + 17 + run.x * 24), Vector2(lx + 34, o.y + 11 + run.y * 24), c, 2.0)
	draw_line(Vector2(rx + 34, o.y + 17), Vector2(rx + 34, o.y + 107), Palette.GOLD, 2.0)
	var ay := o.y + 62
	draw_line(Vector2(lx + 40, ay), Vector2(rx - 38, ay), Palette.GOLD, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(rx - 36, ay), Vector2(rx - 43, ay - 4), Vector2(rx - 43, ay + 4)]), Palette.GOLD)
	draw_multiline_string(font, Vector2(o.x, o.y + 164), tr("RULES_PIC_MERGE"), HORIZONTAL_ALIGNMENT_LEFT, 160, S, 2, Palette.SOFT)


## Heap: a small heap (9 over 4 and 7, 1 under 4), root on top and no red
## line, so the root goes up into the tray at the exit.
func _draw_rules_picture_heap(o: Vector2) -> void:
	var cx := o.x + 76
	draw_dashed_line(Vector2(cx - 40, o.y + 6), Vector2(cx + 40, o.y + 6), Palette.GOLD.darkened(0.3), 1.0, 4.0)
	_text(tr("EXIT"), Vector2(cx - 40, o.y), S, Palette.GOLD.darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER, 80)
	var root := Vector2(cx, o.y + 56)
	var left := Vector2(cx - 36, o.y + 96)
	var right := Vector2(cx + 36, o.y + 96)
	var leaf := Vector2(cx - 36, o.y + 136)
	var c := Palette.SOFT.darkened(0.2)
	for pair: Array in [[root, left], [root, right], [left, leaf]]:
		draw_line(pair[0], pair[1], c, 2.0)
	_mini_box(root, 9, Palette.GOLD)
	_mini_box(left, 4)
	_mini_box(right, 7)
	_mini_box(leaf, 1)
	_marker(Vector2(root.x - 30, root.y))
	# Up into the tray.
	draw_line(Vector2(cx, o.y + 44), Vector2(cx, o.y + 18), Palette.GOLD, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 4, o.y + 20), Vector2(cx + 4, o.y + 20), Vector2(cx, o.y + 13)]), Palette.GOLD)
	_text(tr("HEAP_POP"), Vector2(cx + 8, o.y + 32), S, Palette.GOLD)
	draw_multiline_string(font, Vector2(o.x, o.y + 164), tr("RULES_PIC_HEAP"), HORIZONTAL_ALIGNMENT_LEFT, 160, S, 2, Palette.SOFT)


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
	return TANK_TOP + session.full_capacity * SLOT_H


func _slot_pos(i: int) -> Vector2:
	if is_heap():
		return _heap_pos(i)
	if _bottom_up():
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


func _on_arrive(_data: Dictionary) -> void:
	Sfx.play(&"arrive")


## A very long shipment, or a very big mult, gets a fanfare.
func _is_fanfare() -> bool:
	return ship_total >= 7 or ship_mult >= 15


## Sounds for lines crossed between frames: a number joining the ready run,
## the last shipment, few moves left, a column one number from full.
func _sound_cues() -> void:
	var room := session.room
	if not session.is_playing():
		return
	var ready := room.ready_count() if is_ship() else 0
	if ready > last_ready:
		Sfx.play(&"ready", Sfx.score_pitch(ready))
	last_ready = ready
	if room.ships_left == 1 and last_ships > 1:
		Sfx.play(&"warning")
	elif room.budget <= 5 and last_budget > 5:
		Sfx.play(&"warning")
	last_ships = room.ships_left
	last_budget = room.budget
	var free := room.board.capacity - room.board.size()
	if free == 1 and last_free > 1:
		Sfx.play(&"danger")
	last_free = free
