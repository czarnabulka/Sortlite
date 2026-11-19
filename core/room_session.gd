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
## (a lone newcomer would always surface for free). From Bubble Sort Quest.
const BATCH_SIZE := 3

## Where newcomers come from: any value, or the worst value for the
## algorithm (the Adversary boss).
const FEED_RANDOM := &"random"
const FEED_ADVERSARY := &"adversary"

## Bosses. The Adversary also strikes: every `strike_every` moves it swaps a
## sorted neighbour pair (the one nearest the exit), warning one move ahead.
## If the player moves either element first, the strike misses.
const BOSS_NONE := &""
const BOSS_ADVERSARY := &"adversary"
const STRIKE_SWAP := &"swap"
const STRIKE_THROW := &"throw"

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
var boss: StringName
var strike_every: int
## Moves left until the boss strikes; it warns when this reaches 1.
var moves_to_strike := 0
## What the boss will do after the next move ("" = not aiming yet).
var strike_mode: StringName = &""
## For a swap: the two element uids it is aiming at.
var strike_uids: Array[int] = []
## Second phase: at half of the target the boss gets angry. Newcomers come one
## move sooner and strikes come one move sooner.
var enraged := false

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

	bus = EventBus.new()
	bus.on(Events.ARRIVE, _on_arrive)
	for item in p_items:
		item.detach()  # items move from room to room with the run
		item.attach(bus)  # slot order = effect order
		items.append(item)

	var values := DataGen.make_values(cfg["kind"], cfg["start"], vmax, rng)
	room = Room.new(Algorithms.make(cfg["algorithm"]), Board.new(cfg["capacity"], values),
			cfg["target"], budget_max, bus, true)
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
	if room.board.size() <= 1:
		for i in BATCH_SIZE - 1:
			batch.append(_roll())
		batch = room.algorithm.order_batch(batch)
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
	if boss != BOSS_ADVERSARY:
		return
	if not enraged and room.score * 2 >= room.target:
		enraged = true
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
## nearest the exit, or, when nothing is sorted, throw in an extra number.
func _aim() -> void:
	strike_uids.clear()
	strike_mode = STRIKE_THROW
	var board := room.board
	var exit_low := room.algorithm.surface_index(board) == 0 if not board.is_empty() else true
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


func is_aiming() -> bool:
	return strike_mode != &""


func is_aiming_pair() -> bool:
	return strike_mode == STRIKE_SWAP


## Newcomers sent by the Adversary are cursed: they score half.
func _on_arrive(data: Dictionary) -> void:
	if feed == FEED_ADVERSARY:
		var e: Element = data["element"]
		e.markers[Element.CURSED] = true


## An empty board has no moves, so nothing could ever happen in TURNS mode.
func _refill_if_empty() -> void:
	if is_playing() and room.board.is_empty():
		deliver()


func _roll() -> int:
	if feed == FEED_ADVERSARY:
		return room.algorithm.adversary_value(room.board, rng, vmax)
	return rng.randi_range(1, vmax)
