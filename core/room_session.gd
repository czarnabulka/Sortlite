class_name RoomSession
extends RefCounted
## A playable room: Room + arrivals + lives + items. The screen drives this
## and only draws; everything here also runs headless (tests, sim/).
##
## Arrivals can come by time or every N moves. Which one is more fun is an
## open question in the design doc, so both exist and the player can switch.

enum ArrivalMode { TIME, TURNS }

## When at most one element is left, the next arrival is a batch of three,
## ordered by the algorithm so the newcomers still have to be sorted
## (a lone newcomer would always surface for free).
const BATCH_SIZE := 3

## Where newcomers come from: any value, or the worst value for the
## algorithm (the Adversary boss).
const FEED_RANDOM := &"random"
const FEED_ADVERSARY := &"adversary"

## Bosses. Every `strike_every` moves a boss strikes, warning one move ahead:
## - the Adversary swaps the sorted neighbour pair nearest the exit; moving
##   either element first makes it miss.
## - the Burnt Stack (a Pancake room where numbers have a burnt side)
##   scorches the clean number nearest the exit; moving or shipping it first
##   makes it miss. Enraged, it sends burnt newcomers.
## - the Memory Leak (a Heap room) takes the top cell of the column away
##   for good; a number in it is lost and costs a life like an overflow, so
##   keeping a cell free dodges the loss. A shipment of LEAK_RECLAIM_AT or
##   more numbers gives one lost cell back.
## Each throws in an extra number when it has nothing to aim at.
const BOSS_NONE := &""
const BOSS_ADVERSARY := &"adversary"
const BOSS_BURNT := &"burnt"
const BOSS_LEAK := &"leak"
const BOSSES: Array[StringName] = [BOSS_ADVERSARY, BOSS_BURNT, BOSS_LEAK]
const STRIKE_SWAP := &"swap"
const STRIKE_SCORCH := &"scorch"
const STRIKE_LEAK := &"leak"
const STRIKE_THROW := &"throw"
## The Memory Leak never takes the column below this many cells.
const LEAK_MIN_CAPACITY := 4
## A shipment this long frees one leaked cell.
const LEAK_RECLAIM_AT := 3

const DEFAULTS := {
	"algorithm": &"bubble",
	"capacity": 8,
	"start": 5,
	"vmax": 12,
	"kind": DataGen.RANDOM,
	"feed": FEED_RANDOM,
	"target": 2500,
	"budget": 45,
	"lives": 3,
	"max_lives": -1,
	"interval_sec": 6.0,
	"every_moves": 3,
	"boss": BOSS_NONE,
	"strike_every": 5,
	## Score at which the boss is enraged; -1 = half of the target.
	"enrage_at": -1,
	## Ship room: ready numbers wait at the exit for a SHIP move (Room.manual_ship).
	"ship": false,
	## Ship room: shipments per room (Room.ships_left), -1 = no limit.
	"ships": -1,
	## Ship room: the most numbers in one shipment (Room.max_ship), -1 = any.
	"max_ship": -1,
}

var room: Room
var bus: EventBus
var rng := RandomNumberGenerator.new()
var seed_value: int
var items: Array[Item] = []
var mode: ArrivalMode
var vmax: int
var feed: StringName
var lives: int
var max_lives: int
var interval_sec: float
var every_moves: int
var budget_max: int
## Shipments the room started with (-1 = no limit), for the screen.
var ships_max := -1
var boss: StringName
var strike_every: int
## Moves left until the boss strikes; it warns when this reaches 1.
var moves_to_strike := 0
## What the boss will do after the next move ("" = not aiming yet).
var strike_mode: StringName = &""
## The element uids it is aiming at (two for a swap, one for a scorch).
var strike_uids: Array[int] = []
## For a scorch: where the aimed number was; it misses if that changed.
var strike_index := -1
## Second phase: at half of the target the boss gets angry. Newcomers come one
## move sooner and strikes come one move sooner.
var enraged := false
var enrage_at: int
## The column's size before the Memory Leak took any cells.
var full_capacity: int

var timer := 0.0
var moves_since_arrival := 0
var next_value := 0


func _init(p_seed: int, p_mode: ArrivalMode, p_items: Array[Item] = [], config: Dictionary = {}) -> void:
	var cfg := DEFAULTS.duplicate()
	cfg.merge(config, true)
	seed_value = p_seed
	rng.seed = p_seed
	mode = p_mode
	vmax = cfg["vmax"]
	feed = cfg["feed"]
	lives = cfg["lives"]
	max_lives = lives if int(cfg["max_lives"]) < 0 else int(cfg["max_lives"])
	interval_sec = cfg["interval_sec"]
	every_moves = cfg["every_moves"]
	budget_max = cfg["budget"]
	boss = cfg["boss"]
	strike_every = cfg["strike_every"]
	moves_to_strike = strike_every
	enrage_at = int(cfg["enrage_at"]) if int(cfg["enrage_at"]) >= 0 else ceili(int(cfg["target"]) / 2.0)

	bus = EventBus.new()
	bus.on(Events.ARRIVE, _on_arrive)
	bus.on(Events.HAND, _on_hand)
	for item in p_items:
		item.detach()  # items move from room to room with the run
		item.attach(bus)  # slot order = effect order
		items.append(item)

	var values := DataGen.make_values(cfg["kind"], cfg["start"], vmax, rng)
	room = Room.new(Algorithms.make(cfg["algorithm"]), Board.new(cfg["capacity"], values),
			cfg["target"], budget_max, bus, true)
	room.manual_ship = bool(cfg["ship"])
	room.ships_left = cfg["ships"] if room.manual_ship else -1
	room.max_ship = int(cfg["max_ship"]) if room.manual_ship else -1
	# The boss's phase shield: nothing gets past half of its HP before it is
	# enraged, so even the biggest shipment cannot one-shot it.
	if boss != BOSS_NONE:
		room.score_cap = enrage_at
	if boss == BOSS_BURNT and room.algorithm is PancakeAlgorithm:
		(room.algorithm as PancakeAlgorithm).burnt_sides = true
	ships_max = room.ships_left
	full_capacity = room.board.capacity
	next_value = _roll()


func start() -> void:
	room.start()
	_refill_if_empty()


func is_playing() -> bool:
	return room.state == Room.State.PLAYING


## Call every frame with the frame time; only TIME mode uses it.
func update(delta: float) -> void:
	if not is_playing() or mode != ArrivalMode.TIME:
		return
	timer += delta
	if timer >= interval_sec:
		deliver()


func play(move: Dictionary) -> bool:
	var ok := room.play(move)
	if ok and is_playing():
		_boss_tick()
	if ok and is_playing():
		moves_since_arrival += 1
		if mode == ArrivalMode.TURNS and moves_since_arrival >= every_moves:
			deliver()
		else:
			_refill_if_empty()
	return ok


## Lets the next arrival in now (the F key), or when it is due.
func deliver() -> void:
	if not is_playing():
		return
	timer = 0.0
	moves_since_arrival = 0
	var batch: Array[int] = [next_value]
	# Ship rooms need the batch too: a lone newcomer is always ready, so
	# without it E alone would ship one number after another for free.
	if room.board.size() <= 1:
		for i in BATCH_SIZE - 1:
			batch.append(_roll())
		batch = room.algorithm.order_batch(batch)
		# In a ship room the batch borrows the next arrivals: emptying the
		# board must not bring numbers in faster (that made shipping at once best).
		if room.manual_ship:
			moves_since_arrival = -(batch.size() - 1) * every_moves
			timer = -(batch.size() - 1) * interval_sec
	var overflowed := room.arrive_batch(batch)
	next_value = _roll()
	if overflowed > 0:
		lives -= 1
		if lives <= 0:
			room.fail()
	_refill_if_empty()


## Ends the room as won or lost and detaches the items, so they can join the
## next room's bus.
func close() -> void:
	for item in items:
		item.detach()


func set_mode(new_mode: ArrivalMode) -> void:
	mode = new_mode
	timer = 0.0
	moves_since_arrival = 0


## 0..1, how close the next arrival is.
func arrival_progress() -> float:
	if mode == ArrivalMode.TIME:
		return clampf(timer / interval_sec, 0.0, 1.0)
	return clampf(float(moves_since_arrival) / float(every_moves), 0.0, 1.0)


func moves_until_arrival() -> int:
	return maxi(every_moves - moves_since_arrival, 0)


# --- boss -----------------------------------------------------------------------

func _boss_tick() -> void:
	if boss == BOSS_NONE:
		return
	if not enraged and room.score >= enrage_at:
		enraged = true
		room.score_cap = -1
		every_moves = maxi(every_moves - 1, 2)
		strike_every = maxi(strike_every - 1, 3)
		moves_to_strike = mini(moves_to_strike, strike_every)
		bus.emit(Events.BOSS_ENRAGED, {"room": room})
	moves_to_strike -= 1
	if moves_to_strike == 1:
		_aim()
	elif moves_to_strike <= 0:
		_strike()
		moves_to_strike = strike_every


## Warns what the boss will do after the next move: swap the sorted pair
## nearest the exit (Adversary) or scorch the clean number nearest it (Burnt
## Stack); with nothing to aim at, throw in an extra number.
func _aim() -> void:
	strike_uids.clear()
	strike_index = -1
	strike_mode = STRIKE_THROW
	var board := room.board
	var exit_low := room.algorithm.surface_index(board) == 0 if not board.is_empty() else true
	if boss == BOSS_LEAK:
		if board.capacity > LEAK_MIN_CAPACITY:
			strike_mode = STRIKE_LEAK
			strike_index = board.capacity - 1
			var lost := leak_victim()
			if lost >= 0:
				strike_uids = [board.cells[lost].uid]
		bus.emit(Events.BOSS_AIM, {"room": room, "mode": strike_mode, "uids": strike_uids.duplicate()})
		return
	if boss == BOSS_BURNT:
		for k in board.size():
			var i := k if exit_low else board.size() - 1 - k
			if not board.cells[i].has_marker(Element.BURNT):
				strike_mode = STRIKE_SCORCH
				strike_uids = [board.cells[i].uid]
				strike_index = i
				break
		bus.emit(Events.BOSS_AIM, {"room": room, "mode": strike_mode, "uids": strike_uids.duplicate()})
		return
	var best := -1
	for j in range(board.size() - 1):
		if board.value_at(j) < board.value_at(j + 1):
			if best < 0 or (exit_low and j < best) or (not exit_low and j > best):
				best = j
	if best >= 0:
		strike_mode = STRIKE_SWAP
		strike_uids = [board.cells[best].uid, board.cells[best + 1].uid]
	bus.emit(Events.BOSS_AIM, {"room": room, "mode": strike_mode, "uids": strike_uids.duplicate()})


func _strike() -> void:
	var mode := strike_mode
	strike_mode = &""
	if mode == STRIKE_THROW:
		bus.emit(Events.BOSS_STRIKE, {"room": room, "mode": mode, "index": -1})
		var value := _roll()
		if room.arrive_batch([value]) > 0:
			lives -= 1
			if lives <= 0:
				room.fail()
		return
	if mode == STRIKE_SCORCH:
		_scorch()
		return
	if mode == STRIKE_LEAK:
		_leak()
		return
	if mode != STRIKE_SWAP:
		return
	# Swaps the aimed pair if it is still side by side and still sorted.
	var board := room.board
	var ia := -1
	var ib := -1
	for i in board.size():
		if board.cells[i].uid == strike_uids[0]:
			ia = i
		elif board.cells[i].uid == strike_uids[1]:
			ib = i
	strike_uids.clear()
	if ia >= 0 and ib == ia + 1 and board.value_at(ia) < board.value_at(ib):
		board.swap(ia, ib)
		bus.emit(Events.BOSS_STRIKE, {"room": room, "mode": mode, "index": ia})
		room.refresh()
	else:
		bus.emit(Events.BOSS_DODGED, {"room": room})


## Burns the aimed number if it is still where it was and still clean.
func _scorch() -> void:
	var board := room.board
	var uid := strike_uids[0] if not strike_uids.is_empty() else -1
	strike_uids.clear()
	var i := strike_index
	strike_index = -1
	if i >= 0 and i < board.size() and board.cells[i].uid == uid and not board.cells[i].has_marker(Element.BURNT):
		board.cells[i].turn_over()
		bus.emit(Events.BOSS_STRIKE, {"room": room, "mode": STRIKE_SCORCH, "index": i})
		room.refresh()
	else:
		bus.emit(Events.BOSS_DODGED, {"room": room})


## The Memory Leak takes the top cell. A number still in it (the column is
## full) is lost: the tree's last leaf, never the ready run.
func _leak() -> void:
	strike_uids.clear()
	strike_index = -1
	var board := room.board
	var lost := leak_victim()
	board.capacity -= 1
	var value := -1
	if lost >= 0:
		value = board.remove_at(lost).value
	bus.emit(Events.BOSS_STRIKE, {"room": room, "mode": STRIKE_LEAK, "index": lost, "value": value})
	if lost >= 0:
		room.overflows += 1
		var data := {"room": room, "value": value, "absorbed": false}
		bus.emit(Events.OVERFLOW, data)
		if not data["absorbed"]:
			lives -= 1
			if lives <= 0:
				room.fail()
	room.refresh()


## Index of the number the next leak would take, or -1 while a cell is free.
func leak_victim() -> int:
	var board := room.board
	if board.size() < board.capacity or board.is_empty():
		return -1
	return maxi(room.algorithm.arrive_index(board) - 1, 0)


## Cells the Memory Leak has taken so far.
func leaked() -> int:
	return full_capacity - room.board.capacity


func is_aiming() -> bool:
	return strike_mode != &""


func is_aiming_pair() -> bool:
	return strike_mode == STRIKE_SWAP


## Aiming at numbers on the board (a swap or a scorch), not a throw.
func is_aiming_cells() -> bool:
	return strike_mode == STRIKE_SWAP or strike_mode == STRIKE_SCORCH


## Newcomers sent by the Adversary are cursed: they score half. The enraged
## Burnt Stack sends them burnt side up.
func _on_arrive(data: Dictionary) -> void:
	var e: Element = data["element"]
	if feed == FEED_ADVERSARY:
		e.markers[Element.CURSED] = true
	if boss == BOSS_BURNT and enraged:
		e.markers[Element.BURNT] = true


## A long enough shipment frees one leaked cell.
func _on_hand(data: Dictionary) -> void:
	if boss == BOSS_LEAK and int(data["count"]) >= LEAK_RECLAIM_AT and leaked() > 0:
		room.board.capacity += 1
		bus.emit(Events.MEMORY_FREED, {"room": room})


## An empty board has no moves, so nothing could ever happen in TURNS mode.
func _refill_if_empty() -> void:
	if is_playing() and room.board.is_empty():
		deliver()


func _roll() -> int:
	if feed == FEED_ADVERSARY:
		return room.algorithm.adversary_value(room.board, rng, vmax)
	return rng.randi_range(1, vmax)
