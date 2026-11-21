extends TestCase
## Heap Sort rooms. Index 0 is the root at the bottom; the exit is at the top.


func _sift(i: int) -> Dictionary:
	return {"type": Events.SIFT, "index": i}


const POP := {"type": Events.POP}


## A board whose last `popped` numbers are already popped.
func _board(values: Array, popped := 0) -> Board:
	var board := Board.new(8, values)
	for k in popped:
		board.cells[board.size() - 1 - k].markers[Element.POPPED] = true
	return board


func _room(values: Array, popped := 0, bus: EventBus = null) -> Room:
	var room := heap_room(values, 1_000_000, 100, 8, bus)
	for k in popped:
		room.board.cells[room.board.size() - 1 - k].markers[Element.POPPED] = true
	room.manual_ship = true
	return room


func test_tree_is_everything_below_the_popped_run() -> void:
	var algo := HeapAlgorithm.new()
	var board := _board([6, 4, 5, 1, 9, 12], 2)
	check_eq(algo.ready_count(board), 2, "9 and 12 were popped")
	check_eq(algo.tree_size(board), 4, "6 4 5 1 form the tree")
	check(algo.is_heap(board), "6 over 4 and 5, 4 over 1")
	check_eq(HeapAlgorithm.parent(3), 1, "cell 3 hangs under cell 1")
	check_eq(HeapAlgorithm.parent(2), 0, "cell 2 hangs under the root")
	check_eq(algo.ready_count(_board([3, 12])), 0, "nothing popped, nothing ready, however big")


func test_sift_lifts_a_bigger_child() -> void:
	var room := _room([3, 8, 5])
	room.start()
	check(room.play(_sift(1)), "8 over 3")
	check_eq(room.board.values(), [8, 3, 5], "8 is the root")
	check_eq(room.wrong_moves, 0, "the bigger child: right")
	check(room.play(_sift(1)), "3 back over 8")
	check_eq(room.wrong_moves, 1, "lifting a smaller child is wrong")


func test_lifting_the_smaller_sibling_is_wrong() -> void:
	var algo := HeapAlgorithm.new()
	var board := _board([2, 6, 9, 1])
	check(algo.is_wrong(board, _sift(1)), "6 is bigger than 2 but 9 is the bigger child")
	check(not algo.is_wrong(board, _sift(2)), "9 is the right one")


func test_pop_sends_the_root_to_the_ready_run() -> void:
	var room := _room([9, 4, 7, 12], 1)
	room.start()
	check(room.play(POP), "pop 9")
	check_eq(room.board.values(), [7, 4, 9, 12], "7 is the new root, 9 joins the run")
	check_eq(room.ready_count(), 2, "12 and 9 ready")
	check_eq(room.wrong_moves, 0, "the root was the biggest")


func test_popping_a_root_that_is_not_the_biggest_is_wrong_and_wasted() -> void:
	var room := _room([4, 9, 2])
	room.start()
	check(room.play(POP), "pop 4")
	check_eq(room.wrong_moves, 1, "9 was bigger")
	check_eq(room.board.values(), [2, 9, 4], "4 swapped to the last cell")
	check_eq(room.ready_count(), 0, "but not popped")


func test_a_lone_root_can_be_popped() -> void:
	var room := _room([5, 9], 1)
	room.start()
	check(room.play(POP), "pop 5")
	check_eq(room.ready_count(), 2, "all popped")


func test_only_tree_cells_take_moves() -> void:
	var room := _room([5, 3, 9, 11], 1)
	room.start()
	check(not room.play(_sift(0)), "the root has no parent")
	check(not room.play(_sift(3)), "11 is popped, not in the tree")
	check(not room.play({"type": Events.SWAP, "index": 0}), "swap is not a Heap move")


func test_newcomer_joins_the_tree_under_the_popped_run() -> void:
	var algo := HeapAlgorithm.new()
	var board := _board([6, 4, 5, 9, 12], 2)
	board.insert_at(algo.arrive_index(board), board.make(7))
	check_eq(board.values(), [6, 4, 5, 7, 9, 12], "7 hangs under 4, below the popped 9 12")
	board.insert_at(algo.arrive_index(board), board.make(11))
	check_eq(algo.ready_count(board), 2, "a bigger newcomer does not undo a pop")


func test_batch_into_an_empty_column_needs_lifting() -> void:
	var algo := HeapAlgorithm.new()
	var board := Board.new(8)
	for v in algo.order_batch([4, 9, 2]):
		board.insert_at(algo.arrive_index(board), board.make(v))
	check_eq(board.values(), [2, 4, 9], "the smallest at the root")
	check(not algo.is_heap(board), "not a heap yet")
	check_eq(algo.ready_count(board), 0, "nothing ready before a pop")


func test_heap_bot_sorts_every_board() -> void:
	for s in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var values := DataGen.make_values(DataGen.RANDOM if s % 2 == 0 else DataGen.DUPES, 8, 12, rng)
		var room := heap_room(values, 1_000_000, 1000)
		room.start()
		var guard := 0
		while not room.board.is_empty() and guard < 200:
			guard += 1
			var m := Bots.choose(room.algorithm, room.board)
			if m.is_empty() or not room.play(m):
				break
		check(room.board.is_empty(), "seed %d: board cleared" % s)
		check_eq(room.wrong_moves, 0, "seed %d: the bot makes no wrong move" % s)
		check(room.moves_made <= 30, "seed %d: %d moves" % [s, room.moves_made])


func _leak_session(start := 5, capacity := 8) -> RoomSession:
	var s := RoomSession.new(3, RoomSession.ArrivalMode.TURNS, [], {
		"algorithm": Algorithms.HEAP, "boss": RoomSession.BOSS_LEAK, "ship": true, "ships": 12,
		"start": start, "capacity": capacity, "strike_every": 2, "every_moves": 100,
		"target": 1_000_000, "budget": 200})
	s.start()
	return s


func _play_any(s: RoomSession) -> void:
	var m := Bots.choose(s.room.algorithm, s.room.board)
	if m.is_empty():
		m = {"type": Events.SHIP, "count": 1}
	check(s.play(m), "a move to pass time")


func test_memory_leak_takes_the_top_cell() -> void:
	var s := _leak_session()
	_play_any(s)
	check(s.is_aiming(), "warns one move ahead")
	check_eq(s.strike_mode, RoomSession.STRIKE_LEAK, "aims at a cell")
	check_eq(s.strike_index, 7, "the top cell")
	check(s.strike_uids.is_empty(), "a free cell: no number at risk")
	_play_any(s)
	check_eq(s.room.board.capacity, 7, "one cell gone")
	check_eq(s.leaked(), 1, "counted")
	check_eq(s.lives, 3, "nothing lost")


func test_memory_leak_in_a_full_column_loses_a_tree_leaf() -> void:
	var s := _leak_session(6, 6)
	_play_any(s)
	check_eq(s.strike_uids.size(), 1, "full: a number is at risk")
	var ready_before := s.room.ready_count()
	var victim := s.strike_uids[0]
	_play_any(s)
	var uids: Array[int] = []
	for e in s.room.board.cells:
		uids.append(e.uid)
	check(s.room.board.capacity == 5, "one cell gone")
	check(s.lives == 2 or not uids.has(victim), "a number lost costs a life")
	check(s.room.ready_count() >= ready_before, "the ready run is never the one lost")


func test_memory_leak_stops_at_the_minimum() -> void:
	var s := _leak_session(5)
	s.room.board.capacity = RoomSession.LEAK_MIN_CAPACITY + 1
	_play_any(s)
	_play_any(s)
	check_eq(s.room.board.capacity, RoomSession.LEAK_MIN_CAPACITY, "down to the minimum")
	_play_any(s)
	check_eq(s.strike_mode, RoomSession.STRIKE_THROW, "no cell to take: throws a number")


func test_long_shipment_frees_a_leaked_cell() -> void:
	var s := _leak_session()
	s.room.board.capacity = 6
	var bus_saw := [false]
	s.bus.on(Events.MEMORY_FREED, func(_d: Dictionary) -> void: bus_saw[0] = true)
	s.bus.emit(Events.HAND, {"room": s.room, "count": 2, "values": [1, 2], "mult": 2, "patterns": []})
	check_eq(s.room.board.capacity, 6, "two numbers free nothing")
	s.bus.emit(Events.HAND, {"room": s.room, "count": 3, "values": [1, 2, 3], "mult": 3, "patterns": []})
	check_eq(s.room.board.capacity, 7, "three free a cell")
	check(bus_saw[0], "the screen hears it")


func test_memory_leak_with_every_number_popped_takes_the_last_to_ship() -> void:
	var s := _leak_session(4, 4)
	var b := s.room.board
	for e in b.cells:
		e.markers[Element.POPPED] = true
	check_eq(s.leak_victim(), 0, "no tree: the popped number that ships last")
