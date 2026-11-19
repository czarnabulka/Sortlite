extends TestCase


func test_correct_swap_surfaces_whole_column_as_chain() -> void:
	var room := bubble_room([1, 3, 2])
	room.start()
	check_eq(room.board.values(), [1, 3, 2], "nothing surfaces at start")
	check(room.play({"type": Events.SWAP, "index": 1}), "swap accepted")
	check_eq(room.wrong_moves, 0, "3 > 2 is a correct swap")
	# 3, 2, 1 surface as links 1, 2, 3: 30×1 + 20×2 + 10×3
	check_eq(room.score, 100, "score")
	check_eq(room.best_chain, 3, "chain length")
	check(room.board.is_empty(), "board empty")


func test_swap_that_breaks_order_is_wrong() -> void:
	var room := bubble_room([3, 1, 2])
	room.start()
	room.play({"type": Events.SWAP, "index": 1})
	check_eq(room.wrong_moves, 1, "1 <= 2 swapped")
	check_eq(room.board.values(), [3, 2, 1], "swap still happens")


func test_swapping_equals_is_wrong() -> void:
	var algo := BubbleAlgorithm.new()
	var board := Board.new(3, [2, 2, 1])
	check(algo.is_wrong(board, {"type": Events.SWAP, "index": 0}), "equal values are never swapped")


func test_sorted_start_surfaces_at_once() -> void:
	var room := bubble_room([1, 2, 5])
	room.start()
	check_eq(room.score, 50 + 40 + 30, "50×1 + 20×2 + 10×3")


func test_illegal_moves_are_refused() -> void:
	var room := bubble_room([3, 1, 2])
	room.start()
	check(not room.play({"type": Events.SWAP, "index": 2}), "no pair above the top")
	check(not room.play({"type": Events.INSERT, "to": 0}), "insert is not a Bubble move")
	check_eq(room.budget, 100, "refused moves cost nothing")
	check_eq(room.moves_made, 0, "no moves counted")


func test_newcomer_enters_at_bottom() -> void:
	var room := bubble_room([3, 1, 2], 1_000_000, 100, 4, null, true)
	room.start()
	check(room.arrive(1), "room had space")
	check_eq(room.board.values(), [1, 3, 1, 2], "bottom is index 0")


func test_overflow_when_full() -> void:
	var bus := EventBus.new()
	bus.record_history = true
	var room := bubble_room([3, 1, 2], 1_000_000, 100, 3, bus, true)
	room.start()
	check(not room.arrive(5), "board was full")
	check_eq(room.overflows, 1, "overflow counted")
	check(bus.events_seen().has(Events.OVERFLOW), "overflow event")


## A bot that plays real Bubble Sort clears any board with exactly as many
## swaps as the board has inversions, and never makes a wrong swap.
func test_bubble_sort_bot_needs_exactly_inversions() -> void:
	for s in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var values := DataGen.make_values(DataGen.RANDOM, 8, 12, rng)
		var room := bubble_room(values, 1_000_000, 1000)
		var inversions := room.board.inversions()
		room.start()
		while not room.board.is_empty():
			var j := _first_out_of_order(room.board)
			if j < 0 or not room.play({"type": Events.SWAP, "index": j}):
				break
		check(room.board.is_empty(), "seed %d: board cleared" % s)
		check_eq(room.moves_made, inversions, "seed %d: swaps" % s)
		check_eq(room.wrong_moves, 0, "seed %d: wrong swaps" % s)


func _first_out_of_order(board: Board) -> int:
	for j in range(board.size() - 1):
		if board.value_at(j) > board.value_at(j + 1):
			return j
	return -1
