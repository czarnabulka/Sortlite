extends TestCase
## Merge Sort rooms. Index 0 is the exit.


func _merge(s: int) -> Dictionary:
	return {"type": Events.MERGE, "index": s}


func test_runs_start_after_the_numbers_in_place() -> void:
	var algo := MergeAlgorithm.new()
	var board := Board.new(8, [1, 2, 7, 9, 3, 8, 4, 4])
	check_eq(algo.placed_prefix(board), 2, "1 and 2 are in place")
	check_eq(algo.runs(board), [Vector2i(2, 4), Vector2i(4, 6), Vector2i(6, 8)], "7 9 | 3 8 | 4 4")
	check_eq(algo.legal_moves(board).size(), 2, "two pairs of neighbouring runs")


func test_merge_joins_two_runs_and_costs_their_length_less_one() -> void:
	var room := merge_room([7, 9, 3, 8, 5])
	room.manual_ship = true
	room.start()
	check(room.play(_merge(0)), "merge 7 9 with 3 8")
	check_eq(room.board.values(), [3, 7, 8, 9, 5], "one sorted run, then 5")
	check_eq(room.budget, 100 - 3, "four numbers, three comparisons")
	check_eq(room.wrong_moves, 0, "no merge is wrong")


func test_merge_is_stable() -> void:
	var board := Board.new(5, [8, 5, 6, 5, 7])
	var first := board.cells[1]
	var algo := MergeAlgorithm.new()
	algo.apply(board, _merge(1))
	check_eq(board.values(), [8, 5, 5, 6, 7], "5 6 and 5 7 merged")
	check(board.cells[1] == first, "the left run's 5 stays first")


func test_only_a_run_start_with_a_next_run_is_a_move() -> void:
	var room := merge_room([4, 8, 2, 6])
	room.start()
	check(not room.play(_merge(1)), "8 is not the start of a run")
	check(not room.play(_merge(2)), "the last run has no next run")
	check(not room.play({"type": Events.SWAP, "index": 0}), "swap is not a Merge move")


func test_smallest_at_the_exit_leaves() -> void:
	var room := merge_room([3, 1, 2])
	room.start()
	check(room.play(_merge(0)), "merge 3 with 1 2")
	check(room.board.is_empty(), "1 2 3 all leave")


func test_switches_count_the_changes_between_runs() -> void:
	var algo := MergeAlgorithm.new()
	check_eq(algo.switches(Board.new(5, [5, 9, 1, 2, 3]), _merge(0)), 1, "1 2 3 then 5 9")
	check_eq(algo.switches(Board.new(4, [2, 8, 1, 5]), _merge(0)), 3, "1 2 5 8 alternates")


func test_batch_into_an_empty_row_needs_merging() -> void:
	var algo := MergeAlgorithm.new()
	var board := Board.new(8)
	for v in algo.order_batch([4, 9, 2]):
		board.insert_at(algo.arrive_index(board), board.make(v))
	check_eq(board.values(), [9, 4, 2], "three runs of one")
	check_eq(algo.ready_count(board), 0, "nothing ready")


func test_merge_bot_sorts_every_board() -> void:
	for s in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var values := DataGen.make_values(DataGen.RANDOM if s % 2 == 0 else DataGen.DUPES, 8, 12, rng)
		var room := merge_room(values, 1_000_000, 1000)
		room.start()
		var guard := 0
		while not room.board.is_empty() and guard < 100:
			guard += 1
			var m := Bots.choose(room.algorithm, room.board)
			if m.is_empty() or not room.play(m):
				break
		check(room.board.is_empty(), "seed %d: board cleared" % s)
		check(room.moves_made < values.size(), "seed %d: %d merges" % [s, room.moves_made])
