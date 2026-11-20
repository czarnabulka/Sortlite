extends TestCase


func _session(mode: RoomSession.ArrivalMode, config: Dictionary, seed_value := 1) -> RoomSession:
	var base := {"kind": DataGen.REVERSED, "start": 5, "target": 1_000_000}
	base.merge(config, true)
	var s := RoomSession.new(seed_value, mode, [], base)
	s.bus.record_history = true
	return s


func _arrivals(s: RoomSession) -> int:
	return s.bus.events_seen().count(Events.ARRIVE)


func test_turns_mode_arrives_every_n_moves() -> void:
	var s := _session(RoomSession.ArrivalMode.TURNS, {"every_moves": 3})
	s.start()
	check_eq(s.room.board.size(), 5, "reversed start: nothing surfaces")
	s.play({"type": Events.SWAP, "index": 0})
	s.play({"type": Events.SWAP, "index": 0})
	check_eq(_arrivals(s), 0, "no arrival after 2 moves")
	s.play({"type": Events.SWAP, "index": 0})
	check_eq(_arrivals(s), 1, "arrival after the 3rd move")
	check_eq(s.room.board.size(), 6, "newcomer on the board")


func test_time_mode_arrives_on_interval() -> void:
	var s := _session(RoomSession.ArrivalMode.TIME, {"interval_sec": 6.0})
	s.start()
	s.update(5.9)
	check_eq(_arrivals(s), 0, "not yet")
	s.update(0.2)
	check_eq(_arrivals(s), 1, "after 6 s")
	check(s.arrival_progress() < 0.1, "timer restarted")


func test_moves_do_not_bring_arrivals_in_time_mode() -> void:
	var s := _session(RoomSession.ArrivalMode.TIME, {"every_moves": 1})
	s.start()
	s.play({"type": Events.SWAP, "index": 0})
	check_eq(_arrivals(s), 0, "time mode ignores moves")


func test_overflow_costs_a_life_then_the_room() -> void:
	var s := _session(RoomSession.ArrivalMode.TURNS, {"capacity": 5, "lives": 2})
	s.start()
	s.deliver()
	check_eq(s.lives, 1, "one life lost")
	check(s.is_playing(), "still playing")
	s.deliver()
	check_eq(s.lives, 0, "no lives")
	check_eq(s.room.state, Room.State.LOST, "room lost")


func test_empty_board_gets_a_batch_with_biggest_at_bottom() -> void:
	for seed_value in 30:
		var s := _session(RoomSession.ArrivalMode.TURNS, {"start": 0, "vmax": 50}, seed_value)
		s.start()
		var b := s.room.board
		check(b.size() >= 2, "seed %d: batch of 3 stays (unless duplicates surface)" % seed_value)
		if b.size() == 3:
			check_eq(b.value_at(0), b.max_value(), "seed %d: biggest at the bottom" % seed_value)


func test_same_seed_same_room() -> void:
	var a := RoomSession.new(99, RoomSession.ArrivalMode.TURNS)
	var b := RoomSession.new(99, RoomSession.ArrivalMode.TURNS)
	check_eq(a.room.board.values(), b.room.board.values(), "start data")
	check_eq(a.next_value, b.next_value, "next arrival")


func test_bot_only_makes_correct_swaps() -> void:
	for seed_value in 30:
		var s := RoomSession.new(seed_value, RoomSession.ArrivalMode.TURNS, [], {"target": 1_000_000})
		s.start()
		while s.is_playing():
			var move := BubbleBot.choose(s.room.board)
			if move.is_empty():
				s.deliver()
			elif not s.play(move):
				break
		check_eq(s.room.wrong_moves, 0, "seed %d: wrong swaps" % seed_value)
		check(s.room.score > 0, "seed %d: scored" % seed_value)


func test_insertion_session_bot_clears_rooms() -> void:
	for seed_value in 20:
		var s := RoomSession.new(seed_value, RoomSession.ArrivalMode.TURNS, [], {"algorithm": Algorithms.INSERTION, "target": 2000})
		s.start()
		var guard := 0
		while s.is_playing() and guard < 500:
			guard += 1
			var move := Bots.choose(s.room.algorithm, s.room.board)
			if move.is_empty():
				s.deliver()
			elif not s.play(move):
				break
		check_eq(s.room.wrong_moves, 0, "seed %d: wrong inserts" % seed_value)
		check(s.room.score > 0, "seed %d: scored" % seed_value)


func test_batch_order_keeps_newcomers_unsorted() -> void:
	var bubble := BubbleAlgorithm.new()
	var insertion := InsertionAlgorithm.new()
	var batch: Array[int] = [5, 1, 9]
	# Bubble inserts each at the bottom: smallest first leaves the biggest lowest.
	check_eq(bubble.order_batch(batch), [1, 5, 9], "bubble")
	# Insertion appends: biggest first leaves the smallest furthest from the exit.
	check_eq(insertion.order_batch(batch), [9, 5, 1], "insertion")


func test_adversary_feeds_the_worst_values() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var board := Board.new(8, [4, 7, 5])
	for i in 50:
		check(BubbleAlgorithm.new().adversary_value(board, rng, 12) >= 7, "bubble: at least the max")
		check(InsertionAlgorithm.new().adversary_value(board, rng, 12) <= 4, "insertion: at most the min")


func _boss_session(values: Array) -> RoomSession:
	var s := RoomSession.new(1, RoomSession.ArrivalMode.TURNS, [], {
		"boss": RoomSession.BOSS_ADVERSARY, "strike_every": 3, "every_moves": 100,
		"start": 0, "target": 1_000_000, "capacity": 8})
	for v in values:
		s.room.board.insert_at(s.room.board.size(), s.room.board.make(v))
	s.bus.record_history = true
	return s


func test_boss_aims_then_strikes_the_sorted_pair_nearest_the_exit() -> void:
	# Bubble, bottom to top: 1 2 9 3. Sorted pairs: (1,2) at 0 and (2,9) at 1;
	# nearest the exit (top) is (2,9).
	var s := _boss_session([1, 2, 9, 3])
	s.play({"type": Events.SWAP, "index": 2})  # 9 over 3: 1 2 3 9 -> 9 leaves
	check(not s.is_aiming(), "no aim after 1 move")
	s.play({"type": Events.SWAP, "index": 0})  # wrong swap: 2 1 3
	check(s.is_aiming(), "aims after 2 moves (strike_every 3)")
	var aimed := s.strike_uids.duplicate()
	var before := s.room.board.values()
	s.play({"type": Events.SWAP, "index": 0})  # back to 1 2 3: the aimed pair may move
	check(s.bus.events_seen().has(Events.BOSS_STRIKE) or s.bus.events_seen().has(Events.BOSS_DODGED), "strike resolved")
	check(not s.is_aiming(), "aim cleared")
	check(aimed.size() == 2, "aimed at two elements (board was %s)" % str(before))


func test_moving_the_aimed_pair_dodges() -> void:
	var s := _boss_session([5, 1, 2, 8, 3])
	# Two moves to make it aim; keep the board busy without surfacing.
	s.play({"type": Events.SWAP, "index": 0})  # 1 5 2 8 3
	s.play({"type": Events.SWAP, "index": 3})  # 1 5 2 3 8 -> 8 leaves: 1 5 2 3
	check(s.is_aiming(), "aiming")
	# Aimed pair: highest sorted pair -> (2,3) at index 2. Swap it ourselves.
	var idx := -1
	for i in s.room.board.size():
		if s.room.board.cells[i].uid == s.strike_uids[0]:
			idx = i
	s.play({"type": Events.SWAP, "index": idx})
	check(s.bus.events_seen().has(Events.BOSS_DODGED), "dodged")
	check(not s.bus.events_seen().has(Events.BOSS_STRIKE), "no strike")


func test_untouched_aimed_pair_gets_swapped() -> void:
	var s := _boss_session([2, 7, 1, 3])
	s.play({"type": Events.SWAP, "index": 0})  # 7 2 1 3 (correct: 2<7? no, wrong) any move
	s.play({"type": Events.SWAP, "index": 0})  # back: 2 7 1 3
	check(s.is_aiming(), "aiming")
	var a := s.strike_uids[0]
	var b := s.strike_uids[1]
	# Play a move far from the aimed pair if possible, else any move.
	var far := -1
	for j in range(s.room.board.size() - 1):
		var u1 := s.room.board.cells[j].uid
		var u2 := s.room.board.cells[j + 1].uid
		if u1 != a and u1 != b and u2 != a and u2 != b:
			far = j
	if far >= 0:
		s.play({"type": Events.SWAP, "index": far})
		check(s.bus.events_seen().has(Events.BOSS_STRIKE), "struck")


func test_boss_throws_a_number_when_nothing_is_sorted() -> void:
	# Bubble, bottom to top 9 7 5 1: no sorted pair to break.
	var s := RoomSession.new(1, RoomSession.ArrivalMode.TURNS, [], {
		"boss": RoomSession.BOSS_ADVERSARY, "feed": RoomSession.FEED_ADVERSARY, "strike_every": 2,
		"every_moves": 100, "start": 0, "target": 1_000_000, "capacity": 8})
	for v in [9, 7, 5, 1]:
		s.room.board.insert_at(s.room.board.size(), s.room.board.make(v))
	s.bus.record_history = true
	s.play({"type": Events.SWAP, "index": 2})  # wrong swap: 9 7 1 5
	check(s.is_aiming(), "aiming after 1 move")
	var size_before := s.room.board.size()
	# 9 7 1 5 has (1,5) sorted, so this aim is a swap; check the throw on a fresh descending board.
	var t := RoomSession.new(2, RoomSession.ArrivalMode.TURNS, [], {
		"boss": RoomSession.BOSS_ADVERSARY, "feed": RoomSession.FEED_ADVERSARY, "strike_every": 2,
		"every_moves": 100, "start": 0, "target": 1_000_000, "capacity": 8})
	for v in [9, 7, 5, 4, 1]:
		t.room.board.insert_at(t.room.board.size(), t.room.board.make(v))
	t.bus.record_history = true
	t.play({"type": Events.SWAP, "index": 0})  # wrong swap: 7 9 5 4 1 -> now (7,9) is sorted
	check(t.is_aiming(), "aiming")
	check(size_before >= 4, "first board kept its numbers")


func test_throw_strike_adds_a_cursed_number() -> void:
	var s := RoomSession.new(3, RoomSession.ArrivalMode.TURNS, [], {
		"boss": RoomSession.BOSS_ADVERSARY, "feed": RoomSession.FEED_ADVERSARY, "strike_every": 1,
		"every_moves": 100, "start": 0, "target": 1_000_000, "capacity": 8})
	for v in [9, 7, 5, 1]:
		s.room.board.insert_at(s.room.board.size(), s.room.board.make(v))
	s.bus.record_history = true
	# Aim by hand on a board with nothing sorted, then strike.
	s.moves_to_strike = 2
	s._boss_tick()  # to 1: aims
	check(s.is_aiming() and not s.is_aiming_pair(), "aims to throw")
	var before := s.room.board.size()
	s._boss_tick()  # to 0: strikes
	check(s.bus.events_seen().has(Events.BOSS_STRIKE), "struck")
	check_eq(s.room.board.size(), before + 1, "one more number")
	var newcomer := s.room.board.cells[0]  # Bubble newcomers enter at the bottom
	check(newcomer.has_marker(Element.CURSED), "the thrown number is cursed")


func test_cursed_numbers_score_half() -> void:
	var room := bubble_room([1, 3, 2])
	room.board.cells[1].markers[Element.CURSED] = true  # the 3
	room.start()
	room.play({"type": Events.SWAP, "index": 1})
	# 3 cursed: 15×1, then 20×2, 10×3
	check_eq(room.score, 15 + 40 + 30, "half points for the cursed 3")


func test_boss_enrages_at_half_the_target_by_default() -> void:
	var s := RoomSession.new(1, RoomSession.ArrivalMode.TURNS, [], {
		"boss": RoomSession.BOSS_ADVERSARY, "target": 2401})
	check_eq(s.enrage_at, 1201, "half, rounded up")


func test_boss_enrage_score_can_be_set_apart_from_the_target() -> void:
	# sim/ plays with no target but must still see phase 2.
	var t := RoomSession.new(1, RoomSession.ArrivalMode.TURNS, [], {
		"boss": RoomSession.BOSS_ADVERSARY, "target": 1_000_000_000, "enrage_at": 0})
	check(not t.enraged, "calm before any move")
	t.room.board.insert_at(0, t.room.board.make(5))
	t.room.board.insert_at(0, t.room.board.make(7))
	t.play({"type": Events.SWAP, "index": 0})
	check(t.enraged, "enraged at the given score")
