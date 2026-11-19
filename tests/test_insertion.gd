extends TestCase


func test_correct_insert_costs_shifts_and_chains() -> void:
	var room := insertion_room([4, 7, 2, 9])
	room.start()
	check_eq(room.board.values(), [4, 7, 2, 9], "4 is not the minimum, nothing leaves")
	check(room.play({"type": Events.INSERT, "to": 0}), "insert accepted")
	check_eq(room.wrong_moves, 0, "2 belongs at the front")
	check_eq(room.budget, 98, "shifted over 4 and 7")
	# 2, 4, 7, 9 leave as links 1..4: 20×1 + 40×2 + 70×3 + 90×4
	check_eq(room.score, 670, "score")
	check(room.board.is_empty(), "board empty")


func test_wrong_place_is_wrong() -> void:
	var room := insertion_room([4, 7, 2, 9])
	room.start()
	room.play({"type": Events.INSERT, "to": 1})
	check_eq(room.wrong_moves, 1, "2 does not go after 4")
	check_eq(room.board.values(), [4, 2, 7, 9], "insert still happens")


func test_insert_is_stable() -> void:
	var algo := InsertionAlgorithm.new()
	var board := Board.new(3, [3, 5, 3])
	check(not algo.is_wrong(board, {"type": Events.INSERT, "to": 1}), "after the equal 3 is right")
	check(algo.is_wrong(board, {"type": Events.INSERT, "to": 0}), "before the equal 3 breaks stability")


func test_only_key_moves_are_legal() -> void:
	var algo := InsertionAlgorithm.new()
	var board := Board.new(4, [4, 7, 2, 9])
	check_eq(algo.legal_moves(board).size(), 2, "key 2 can go to slot 0 or 1")
	var sorted := Board.new(3, [1, 2, 3])
	check(algo.legal_moves(sorted).is_empty(), "sorted board has no key")


func test_newcomer_joins_on_the_right() -> void:
	var room := insertion_room([4, 7, 2], 1_000_000, 100, 4, null, true)
	room.start()
	room.arrive(1)
	check_eq(room.board.values(), [4, 7, 2, 1], "right end")


## Insertion Sort shifts each element over every bigger one before it,
## so a perfect bot spends exactly the inversions of the board.
func test_insertion_bot_spends_exactly_inversions() -> void:
	for s in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var values := DataGen.make_values(DataGen.RANDOM, 8, 12, rng)
		var room := insertion_room(values, 1_000_000, 1000)
		var inversions := room.board.inversions()
		room.start()
		var algo := room.algorithm as InsertionAlgorithm
		while not room.board.is_empty():
			var move := _right_move(algo, room.board)
			if move.is_empty() or not room.play(move):
				break
		check(room.board.is_empty(), "seed %d: board cleared" % s)
		check_eq(1000 - room.budget, inversions, "seed %d: budget spent" % s)
		check_eq(room.wrong_moves, 0, "seed %d: wrong inserts" % s)


func _right_move(algo: InsertionAlgorithm, board: Board) -> Dictionary:
	for m in algo.legal_moves(board):
		if not algo.is_wrong(board, m):
			return m
	return {}
