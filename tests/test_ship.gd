extends TestCase
## Ship rooms: ready numbers wait at the exit and leave as a scored hand.


func _ship_room(values: Array, insertion := false, budget := 100, bus: EventBus = null) -> Room:
	var room := insertion_room(values, 1_000_000, budget, -1, bus) if insertion \
			else bubble_room(values, 1_000_000, budget, -1, bus)
	room.manual_ship = true
	room.start()
	return room


func test_hand_patterns_and_mult() -> void:
	var h := Hands.evaluate([6, 5, 4])
	check_eq(h["patterns"], [Hands.STRAIGHT], "4 5 6")
	check_eq(h["mult"], 3 + 2 * 3, "length + straight")
	check_eq(Hands.evaluate([7, 7])["patterns"], [Hands.SAME], "7 7")
	check_eq(Hands.evaluate([7, 7])["mult"], 2 + 2 * 2, "pair mult")
	check_eq(Hands.evaluate([2, 4, 6])["patterns"], [Hands.EVEN], "2 4 6: even, not a straight")
	check_eq(Hands.evaluate([3, 2, 1])["patterns"], [Hands.STRAIGHT, Hands.FIBONACCI], "1 2 3")
	check_eq(Hands.evaluate([3, 2, 1])["mult"], 3 + 6 + 6, "both bonuses stack")
	check_eq(Hands.evaluate([9, 3])["patterns"], [], "two odd numbers are no pattern")
	check_eq(Hands.evaluate([9, 3])["mult"], 2, "just the length")
	check_eq(Hands.evaluate([5])["mult"], 1, "a single number")


func test_ready_numbers_wait_for_a_ship() -> void:
	var room := _ship_room([1, 2, 3])
	check_eq(room.score, 0, "nothing leaves by itself")
	check_eq(room.board.size(), 3, "all still there")
	check_eq(room.ready_count(), 3, "all ready")


func test_shipping_part_of_the_run() -> void:
	var room := _ship_room([1, 2, 3])
	check(room.play({"type": Events.SHIP, "count": 2}), "shipped")
	# 3 and 2 leave together: (30 + 20) × 2.
	check_eq(room.score, 100, "score")
	check_eq(room.board.values(), [1], "1 stays")
	check_eq(room.budget, 99, "a ship costs one move")
	check_eq(room.best_chain, 2, "a shipment counts as a chain")


func test_ship_refused_beyond_the_ready_run_or_in_classic_rooms() -> void:
	var room := _ship_room([3, 1, 2])  # the top 2 is not the biggest
	check_eq(room.ready_count(), 0, "nothing ready while 3 is below")
	check(not room.play({"type": Events.SHIP, "count": 1}), "nothing to ship")
	var classic := bubble_room([1, 2, 5, 3])
	classic.start()
	check(not classic.play({"type": Events.SHIP, "count": 1}), "classic rooms have no ship move")


func test_insertion_ships_the_smallest_from_the_left() -> void:
	var room := _ship_room([1, 2, 3, 9, 5], true)
	check_eq(room.ready_count(), 3, "1 2 3 are ready, 9 is not (5 is smaller)")
	check(room.play({"type": Events.SHIP, "count": 3}), "shipped")
	# (10 + 20 + 30) × (3 + straight 6 + fibonacci 6)
	check_eq(room.score, 60 * 15, "score")
	check_eq(room.board.values(), [9, 5], "rest stays")


func test_hand_event_names_the_patterns() -> void:
	var bus := EventBus.new()
	bus.record_history = true
	var room := _ship_room([4, 5, 6], false, 100, bus)
	room.play({"type": Events.SHIP, "count": 3})
	var hand: Dictionary = {}
	for entry in bus.history:
		if entry["event"] == Events.HAND:
			hand = entry["data"]
	check_eq(hand.get("patterns"), [Hands.STRAIGHT], "patterns")
	check_eq(hand.get("mult"), 9, "mult")


func test_items_still_score_per_number() -> void:
	var bus := EventBus.new()
	ItemCatalog.parity_bit().attach(bus)
	var room := _ship_room([1, 2], false, 100, bus)
	room.play({"type": Events.SHIP, "count": 2})
	# 2: (20 + 20) × 2,  1: 10 × 2
	check_eq(room.score, 80 + 20, "parity bit adds points to the even one")


func test_express_lane_skips_the_ready_run() -> void:
	var bus := EventBus.new()
	ItemCatalog.express_lane().attach(bus)
	# Bottom to top 1 5 2 3 8 9: 8 and 9 are ready; 5 is the biggest below them.
	var room := _ship_room([1, 5, 2, 3, 8, 9], false, 100, bus)
	check_eq(room.ready_count(), 2, "8 9 ready")
	room.play({"type": Events.SWAP, "index": 1})
	check_eq(room.board.values(), [1, 2, 3, 5, 8, 9], "5 carried up to the run")


## A lone number is always "sorted", so refilling an empty ship room with one
## number let E score forever without sorting anything. The refill is a batch
## ordered so that nothing is ready until the player sorts it.
func test_empty_ship_room_refills_with_a_batch_that_needs_sorting() -> void:
	for algorithm in [Algorithms.BUBBLE, Algorithms.INSERTION]:
		for seed_value in 40:
			var s := RoomSession.new(seed_value, RoomSession.ArrivalMode.TURNS, [],
					{"ship": true, "start": 0, "every_moves": 100, "algorithm": algorithm})
			s.start()
			var values := s.room.board.values()
			check_eq(values.size(), RoomSession.BATCH_SIZE, "%s seed %d: a batch of three" % [algorithm, seed_value])
			if values.min() != values.max():  # three equal numbers are sorted anyway
				check_eq(s.room.ready_count(), 0, "%s seed %d: %s ready before sorting" % [algorithm, seed_value, values])


## Emptying the board must not bring numbers in faster than the room's pace.
func test_ship_refill_batch_borrows_the_next_arrivals() -> void:
	var s := RoomSession.new(5, RoomSession.ArrivalMode.TURNS, [],
			{"ship": true, "start": 0, "every_moves": 2})
	s.start()
	check_eq(s.room.board.size(), 3, "batch of three")
	check_eq(s.moves_until_arrival(), 3 * 2, "the next two arrivals came early, so the third is due after 6 moves")
	var classic := RoomSession.new(5, RoomSession.ArrivalMode.TURNS, [], {"start": 0, "every_moves": 2})
	classic.start()
	check_eq(classic.moves_until_arrival(), 2, "classic rooms keep their pace")


func test_pressing_only_ship_cannot_keep_scoring() -> void:
	for algorithm in [Algorithms.BUBBLE, Algorithms.INSERTION]:
		for seed_value in 20:
			var s := RoomSession.new(seed_value, RoomSession.ArrivalMode.TURNS, [],
					{"ship": true, "start": 1, "every_moves": 2, "budget": 40, "target": 1_000_000,
					"algorithm": algorithm})
			s.start()
			var presses := 0
			while s.is_playing() and s.room.ready_count() > 0 and presses < 40:
				s.play({"type": Events.SHIP, "count": s.room.ready_count()})
				presses += 1
			check(presses <= 3, "%s seed %d: E alone shipped %d times in a row" % [algorithm, seed_value, presses])


func test_greedy_ships_at_once_smart_keeps_sorting() -> void:
	var s := RoomSession.new(4, RoomSession.ArrivalMode.TURNS, [], {"ship": true, "start": 0, "every_moves": 100})
	for v in [9, 1, 3, 12]:  # bottom to top: 12 is ready, the rest needs sorting
		s.room.board.insert_at(s.room.board.size(), s.room.board.make(v))
	check_eq(s.room.ready_count(), 1, "12 ready")
	check_eq(Bots.choose_in(s, Bots.GREEDY), {"type": Events.SHIP, "count": 1}, "greedy ships the lone 12")
	check_eq(Bots.choose_in(s, Bots.SMART).get("type"), Events.SWAP, "smart grows the run first")


func test_smart_bot_clears_ship_rooms() -> void:
	var wins := 0
	for seed_value in 20:
		var run := Run.new(seed_value)
		run.skip()
		var s := run.session
		var guard := 0
		while s.is_playing() and guard < 2000:
			guard += 1
			var move := Bots.choose_in(s)
			if move.is_empty() or not s.play(move):
				s.deliver()
		if s.room.state == Room.State.WON:
			wins += 1
	check(wins >= 12, "smart wins most first rooms (%d/20)" % wins)


func test_ship_limit_counts_down_and_refuses_at_zero() -> void:
	var room := _ship_room([1, 2, 3, 4])
	room.ships_left = 2
	check(room.play({"type": Events.SHIP, "count": 1}), "first shipment")
	check_eq(room.ships_left, 1, "one left")
	check(room.play({"type": Events.SHIP, "count": 1}), "second shipment")
	check_eq(room.ships_left, 0, "none left")
	check_eq(room.state, Room.State.LOST, "out of shipments below the target: lost")
	check(not room.play({"type": Events.SHIP, "count": 1}), "no more shipments")


func test_last_shipment_can_still_win() -> void:
	var room := insertion_room([1, 2, 3], 60, 100)
	room.manual_ship = true
	room.ships_left = 1
	room.start()
	check(room.play({"type": Events.SHIP, "count": 3}), "ship all three")
	check_eq(room.state, Room.State.WON, "the last shipment met the target")


func test_no_ship_moves_offered_without_shipments() -> void:
	var room := _ship_room([1, 2, 3])
	room.ships_left = 0
	for m in room.affordable_moves():
		check(m.get("type") != Events.SHIP, "SHIP offered with no shipments left")


func test_every_ship_room_has_a_limit_and_classic_rooms_none() -> void:
	for key in Run.ROOMS:
		var ship := RoomSession.new(1, RoomSession.ArrivalMode.TURNS, [], Run.session_config(Run.ROOMS[key], true))
		check(ship.room.ships_left > 0, "%s: ship room without a limit" % key)
		check_eq(ship.ships_max, ship.room.ships_left, "%s: max for the screen" % key)
		var classic := RoomSession.new(1, RoomSession.ArrivalMode.TURNS, [], Run.session_config(Run.ROOMS[key], false))
		check_eq(classic.room.ships_left, -1, "%s: classic rooms have no limit" % key)
		check_eq(ship.room.max_ship, Run.MAX_SHIP, "%s: shipments are capped" % key)
		check_eq(classic.room.max_ship, -1, "%s: classic rooms have no cap" % key)


func test_a_shipment_holds_at_most_max_ship() -> void:
	var room := _ship_room([1, 2, 3, 4, 5])  # all five ready at the top
	room.max_ship = 3
	check_eq(room.ready_count(), 5, "five ready")
	check_eq(room.shippable(), 3, "three may go")
	check(not room.play({"type": Events.SHIP, "count": 4}), "four is over the cap")
	var counts: Array = room.affordable_moves().filter(func(m: Dictionary) -> bool:
		return m.get("type") == Events.SHIP).map(func(m: Dictionary) -> int: return m["count"])
	check_eq(counts, [1, 2, 3], "ship moves offered up to the cap")
	check(room.play({"type": Events.SHIP, "count": 3}), "three ship")
	check_eq(room.board.values(), [1, 2], "the rest wait for the next shipment")


func test_insertion_elite_ship_room_uses_duplicates() -> void:
	var cfg := Run.session_config(Run.ROOMS[&"elite_insertion"], true)
	check_eq(cfg["kind"], DataGen.DUPES, "reversed data would make the whole column ready at once")
	check_eq(Run.session_config(Run.ROOMS[&"elite_insertion"], false)["kind"], DataGen.REVERSED, "classic keeps reversed")
