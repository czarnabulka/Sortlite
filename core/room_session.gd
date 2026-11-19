class_name RoomSession
extends RefCounted
## A playable room: Room + arrivals + lives + items. The screen drives this
## and only draws; everything here also runs headless (tests, sim/).
##
## Arrivals can come by time or every N moves. Which one is more fun is an
## open question in the design doc, so both exist and the player can switch.

enum ArrivalMode { TIME, TURNS }

## When at most one element is left, the next arrival is a batch of three,
## smallest first, so the biggest ends at the bottom and has to be carried up
## (a lone newcomer would always surface for free). From Bubble Sort Quest.
const BATCH_SIZE := 3

const DEFAULTS := {
	"capacity": 8,
	"start": 5,
	"vmax": 12,
	"kind": DataGen.RANDOM,
	"target": 2500,
	"budget": 45,
	"lives": 3,
	"interval_sec": 6.0,
	"every_moves": 3,
}

var room: Room
var bus: EventBus
var rng := RandomNumberGenerator.new()
var seed_value: int
var items: Array[Item] = []
var mode: ArrivalMode
var vmax: int
var lives: int
var max_lives: int
var interval_sec: float
var every_moves: int
var budget_max: int

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
	lives = cfg["lives"]
	max_lives = lives
	interval_sec = cfg["interval_sec"]
	every_moves = cfg["every_moves"]
	budget_max = cfg["budget"]

	bus = EventBus.new()
	for item in p_items:
		item.attach(bus)  # slot order = effect order
		items.append(item)

	var values := DataGen.make_values(cfg["kind"], cfg["start"], vmax, rng)
	room = Room.new(BubbleAlgorithm.new(), Board.new(cfg["capacity"], values),
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
		batch.sort()  # smallest enters first: the biggest ends at the bottom
	next_value = _roll()
	var overflowed := room.arrive_batch(batch)
	if overflowed > 0:
		lives -= 1
		if lives <= 0:
			room.fail()
	_refill_if_empty()


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


## An empty board has no moves, so nothing could ever happen in TURNS mode.
func _refill_if_empty() -> void:
	if is_playing() and room.board.is_empty():
		deliver()


func _roll() -> int:
	return rng.randi_range(1, vmax)
