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
