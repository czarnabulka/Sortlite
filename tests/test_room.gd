extends TestCase


func test_reaching_target_wins() -> void:
	var room := bubble_room([1, 3, 2], 100)
	room.start()
	room.play({"type": Events.SWAP, "index": 1})
	check_eq(room.state, Room.State.WON, "100 points reach 100")
	check(not room.play({"type": Events.SWAP, "index": 0}), "no moves after the room ends")


func test_running_out_of_budget_loses() -> void:
	var room := bubble_room([3, 1, 2], 1000, 1)
	room.start()
	room.play({"type": Events.SWAP, "index": 0})
	check_eq(room.budget, 0, "budget spent")
	check_eq(room.state, Room.State.LOST, "out of moves below target")


func test_move_dearer_than_budget_is_refused() -> void:
	var room := insertion_room([4, 7, 2, 9], 1000, 1)
	room.start()
	check(not room.play({"type": Events.INSERT, "to": 0}), "costs 2, budget 1")
	check(room.play({"type": Events.INSERT, "to": 1}), "costs 1")


func test_events_fire_in_order() -> void:
	var bus := EventBus.new()
	bus.record_history = true
	var room := bubble_room([1, 3, 2], 1_000_000, 100, -1, bus)
	room.start()
	room.play({"type": Events.SWAP, "index": 1})
	var expected: Array[StringName] = [
		Events.ROOM_START,
		Events.BEFORE_MOVE, Events.MOVE, Events.SWAP,
		Events.SURFACE, Events.SCORED, Events.SURFACE, Events.SCORED, Events.SURFACE, Events.SCORED,
		Events.CHAIN,
		Events.ROOM_END,
	]
	check_eq(bus.events_seen(), expected, "event order")


func test_bus_depth_limit_stops_loops() -> void:
	var bus := EventBus.new()
	var calls := [0]
	var loop := func(_d: Dictionary) -> void:
		calls[0] += 1
		bus.emit(&"ping")
	bus.on(&"ping", loop)
	bus.emit(&"ping")
	check_eq(calls[0], EventBus.MAX_DEPTH, "loop cut at max depth")
	check_eq(bus.dropped, 1, "one event dropped")
	bus.off(&"ping", loop)  # the handler holds the bus: a cycle until removed


func test_same_seed_same_data() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 1234
	b.seed = 1234
	for kind in [DataGen.RANDOM, DataGen.NEARLY, DataGen.REVERSED, DataGen.DUPES]:
		check_eq(DataGen.make_values(kind, 9, 12, a), DataGen.make_values(kind, 9, 12, b), str(kind))


func test_data_shapes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rev := Board.new(8, DataGen.make_values(DataGen.REVERSED, 8, 12, rng))
	check_eq(rev.inversions(), 28, "reversed distinct: n(n-1)/2")
	for i in 20:
		var nearly := Board.new(8, DataGen.make_values(DataGen.NEARLY, 8, 12, rng))
		check(nearly.inversions() <= 2, "nearly sorted has at most 2 inversions")
	for i in 20:
		for v in DataGen.make_values(DataGen.DUPES, 8, 12, rng):
			check(v >= 1 and v <= 4, "dupes stay in a small range")
