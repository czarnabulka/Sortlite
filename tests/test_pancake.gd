extends TestCase
## Pancake Sort rooms and the Burnt Stack boss. Index 0 is the bottom (the exit).


func _flip(i: int) -> Dictionary:
	return {"type": Events.FLIP, "index": i}


func test_flip_reverses_the_top_part() -> void:
	var room := pancake_room([1, 3, 2, 5])
	room.start()
	check(room.play(_flip(1)), "flip accepted")
	check_eq(room.board.values(), [1, 5, 2, 3], "3 2 5 turned over")
	check_eq(room.wrong_moves, 0, "a flip above the sorted bottom is fine")


func test_biggest_at_the_bottom_leaves() -> void:
	var room := pancake_room([2, 1, 5])
	room.start()
	check(room.play(_flip(0)), "flip the whole stack")
	# 5 1 2: 5 leaves, then 1 2 stays (1 at the bottom is not the biggest)
	check_eq(room.board.values(), [1, 2], "only 5 left")
	check_eq(room.score, 50, "5 × 10")


func test_illegal_moves_are_refused() -> void:
	var room := pancake_room([1, 3, 2])
	room.start()
	check(not room.play(_flip(2)), "turning the top one alone is no move without sides")
	check(not room.play({"type": Events.SWAP, "index": 0}), "swap is not a Pancake move")
	check_eq(room.moves_made, 0, "nothing counted")


func test_flip_into_the_sorted_bottom_is_wrong() -> void:
	var room := pancake_room([9, 3, 7])
	room.manual_ship = true
	room.start()
	check_eq(room.ready_count(), 1, "9 waits at the exit")
	check(room.play(_flip(0)), "still allowed")
	check_eq(room.wrong_moves, 1, "it broke the sorted bottom")


func test_newcomers_land_on_top() -> void:
	var room := pancake_room([1, 3], 1_000_000, 100, 4, null, true)
	room.start()
	check(room.arrive(2), "room had space")
	check_eq(room.board.values(), [1, 3, 2], "on top")


## A refill of three needs three flips, not one.
func test_refill_batch_needs_three_flips() -> void:
	var algo := PancakeAlgorithm.new()
	var batch: Array[int] = [9, 1, 4]
	check_eq(algo.order_batch(batch), [4, 9, 1], "middle, biggest, smallest from the bottom")
	var room := pancake_room([4, 9, 1])
	room.start()
	while not room.board.is_empty():
		if not room.play(Bots.choose(room.algorithm, room.board)):
			break
	check_eq(room.moves_made, 3, "three flips")


## The bot clears any board with at most two flips per number, never wrong.
func test_pancake_bot_needs_at_most_two_flips_per_number() -> void:
	for s in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var values := DataGen.make_values(DataGen.RANDOM, 8, 12, rng)
		var room := pancake_room(values, 1_000_000, 1000)
		room.start()
		var guard := 0
		while not room.board.is_empty() and guard < 100:
			guard += 1
			var m := Bots.choose(room.algorithm, room.board)
			if m.is_empty() or not room.play(m):
				break
		check(room.board.is_empty(), "seed %d: board cleared" % s)
		check(room.moves_made <= 2 * values.size(), "seed %d: %d flips" % [s, room.moves_made])
		check_eq(room.wrong_moves, 0, "seed %d: wrong flips" % s)


func test_burnt_sides_turn_over_with_a_flip() -> void:
	var room := pancake_room([1, 3, 2, 5])
	(room.algorithm as PancakeAlgorithm).burnt_sides = true
	room.start()
	room.play(_flip(2))
	check(not room.board.cells[1].has_marker(Element.BURNT), "below the spatula: untouched")
	check(room.board.cells[2].has_marker(Element.BURNT), "flipped: burnt side up")
	check(room.board.cells[3].has_marker(Element.BURNT), "flipped: burnt side up")
	check(room.play(_flip(3)), "with sides the top one alone can be turned over")
	check(not room.board.cells[3].has_marker(Element.BURNT), "turned back clean")
	check_eq(room.wrong_moves, 0, "turning a burnt one is right")
	check(room.play(_flip(3)), "turning a clean one alone is allowed")
	check_eq(room.wrong_moves, 1, "but wrong")


func test_burnt_side_up_scores_half() -> void:
	var room := pancake_room([8])
	room.board.cells[0].markers[Element.BURNT] = true
	room.start()
	check_eq(room.score, 40, "80 halved")


## With sides, the bot turns a clean top number over before flipping it
## down, so it lands clean side up.
func test_burnt_bot_lands_the_biggest_clean() -> void:
	var room := pancake_room([1, 9])
	room.manual_ship = true
	(room.algorithm as PancakeAlgorithm).burnt_sides = true
	room.start()
	check_eq(Bots.choose(room.algorithm, room.board), _flip(1), "turn 9 over first")
	room.play(_flip(1))
	check_eq(Bots.choose(room.algorithm, room.board), _flip(0), "then flip it down")
	room.play(_flip(0))
	check_eq(room.board.values(), [9, 1], "9 at the bottom")
	check(not room.board.cells[0].has_marker(Element.BURNT), "clean side up")


func _burnt_session(values: Array) -> RoomSession:
	var s := RoomSession.new(1, RoomSession.ArrivalMode.TURNS, [], {
		"algorithm": Algorithms.PANCAKE, "boss": RoomSession.BOSS_BURNT, "ship": true, "ships": 12,
		"strike_every": 2, "every_moves": 100, "target": 100_000, "budget": 50})
	s.room.board = Board.new(8, values)
	s.start()
	return s


func test_burnt_stack_scorches_the_clean_number_nearest_the_exit() -> void:
	var s := _burnt_session([9, 2, 5])
	check((s.room.algorithm as PancakeAlgorithm).burnt_sides, "the boss gives numbers sides")
	check(s.play(_flip(1)), "flip")  # 9 5 2, burnt 5 and 2
	check_eq(s.strike_mode, RoomSession.STRIKE_SCORCH, "aiming")
	check_eq(s.strike_uids, [s.room.board.cells[0].uid], "at 9, the clean one at the exit")
	check(s.play(_flip(2)), "a move that leaves 9 where it is")
	check(s.room.board.cells[0].has_marker(Element.BURNT), "9 scorched")


func test_shipping_the_aimed_number_dodges() -> void:
	var s := _burnt_session([9, 2, 5])
	s.bus.record_history = true
	s.play(_flip(1))
	check(s.play({"type": Events.SHIP, "count": 1}), "ship 9")
	check(s.bus.events_seen().has(Events.BOSS_DODGED), "dodged")
	check_eq(s.room.score, 90, "9 scored clean")


func test_enraged_burnt_stack_sends_burnt_numbers() -> void:
	var s := _burnt_session([9, 2, 5])
	s.enraged = true
	s.deliver()
	check(s.room.board.cells.back().has_marker(Element.BURNT), "newcomer burnt side up")
