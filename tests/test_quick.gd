extends TestCase
## Quick Sort rooms. Index 0 is the exit.


func _split(i: int) -> Dictionary:
	return {"type": Events.PARTITION, "index": i}


func test_pivot_splits_its_segment_and_lands_in_place() -> void:
	var room := quick_room([5, 8, 2, 9, 4])
	room.manual_ship = true
	room.start()
	check(room.play(_split(4)), "pivot 4")
	# smaller than 4 before it, the rest after, both keeping their order
	check_eq(room.board.values(), [2, 4, 5, 8, 9], "split around 4")
	check_eq(room.budget, 100 - 4, "one comparison per other number")


func test_segments_are_the_numbers_not_in_place() -> void:
	var algo := QuickAlgorithm.new()
	var board := Board.new(6, [1, 3, 2, 4, 6, 5])
	check_eq(algo.placed(board), [true, false, false, true, false, false], "1 and 4 are in place")
	check_eq(algo.segments(board), [Vector2i(1, 3), Vector2i(4, 6)], "two segments")
	check_eq(algo.move_cost(board, _split(5)), 1, "a segment of two costs 1")


func test_numbers_in_place_are_not_pivots() -> void:
	var room := quick_room([1, 3, 2])
	room.manual_ship = true
	room.start()
	check(not room.play(_split(0)), "1 is already in place")
	check(not room.play({"type": Events.INSERT, "to": 0}), "insert is not a Quick move")
	check(room.play(_split(1)), "3 is a pivot")
	check_eq(room.wrong_moves, 0, "no pivot is wrong")


func test_smallest_at_the_exit_leaves() -> void:
	var room := quick_room([2, 1, 3])
	room.start()
	check(room.play(_split(1)), "pivot 1")
	check(room.board.is_empty(), "1 2 3 all leave")


func test_newcomer_smaller_than_a_placed_number_unplaces_it() -> void:
	var algo := QuickAlgorithm.new()
	var board := Board.new(5, [3, 4, 9])
	check_eq(algo.placed(board), [true, true, true], "sorted")
	board.insert_at(algo.arrive_index(board), board.make(1))
	check_eq(algo.segments(board), [Vector2i(0, 4)], "1 on the right breaks them all")


func test_quick_bot_sorts_every_board() -> void:
	for s in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var values := DataGen.make_values(DataGen.RANDOM if s % 2 == 0 else DataGen.DUPES, 8, 12, rng)
		var room := quick_room(values, 1_000_000, 1000)
		room.start()
		var guard := 0
		while not room.board.is_empty() and guard < 100:
			guard += 1
			var m := Bots.choose(room.algorithm, room.board)
			if m.is_empty() or not room.play(m):
				break
		check(room.board.is_empty(), "seed %d: board cleared" % s)
		check(room.moves_made <= values.size(), "seed %d: %d pivots" % [s, room.moves_made])
