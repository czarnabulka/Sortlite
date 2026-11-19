extends TestCase


## Plays the current room with the perfect bot until it ends.
func _play_room(run: Run) -> void:
	var s := run.session
	var guard := 0
	while s.is_playing() and guard < 2000:
		guard += 1
		var move := Bots.choose_for(s.room)
		if move.is_empty():
			s.deliver()
		elif not s.play(move):
			s.deliver()
	run.finish_room()


func test_run_starts_with_an_offer() -> void:
	var run := Run.new(1)
	check_eq(run.phase, Run.Phase.REWARD, "first a pick")
	check_eq(run.offer.size(), Run.OFFER_SIZE, "three items")
	var ids := {}
	for item in run.offer:
		ids[item.id] = true
	check_eq(ids.size(), Run.OFFER_SIZE, "no duplicates")


func test_floor_has_both_algorithms_and_a_boss() -> void:
	for s in 20:
		var run := Run.new(s)
		var algos := {}
		for r in run.plan:
			algos[r["algorithm"]] = true
		check_eq(algos.size(), 2, "seed %d: both algorithms" % s)
		check_eq(run.plan.back()["kind"], Run.BOSS, "seed %d: boss last" % s)


func test_taking_an_item_starts_the_room_with_it() -> void:
	var run := Run.new(2)
	var picked := run.offer[0]
	check(run.take(0), "took")
	check_eq(run.phase, Run.Phase.ROOM, "room started")
	check(run.session.items.has(picked), "item in the room")
	check(run.session.bus.handler_count(Events.ROOM_START) >= 0, "bus exists")


func test_skip_gives_bits() -> void:
	var run := Run.new(3)
	run.skip()
	check_eq(run.bits, Run.SKIP_BITS, "bits")
	check_eq(run.items.size(), 0, "no item")


func test_reroll_and_heal_cost_bits() -> void:
	var run := Run.new(4)
	check(not run.reroll(), "no bits, no reroll")
	run.bits = 10
	check(run.reroll(), "reroll")
	check_eq(run.bits, 10 - Run.REROLL_COST, "paid")
	check(not run.heal(), "full lives, no heal")
	run.lives = 2
	check(run.heal(), "heal")
	check_eq(run.lives, 3, "life back")


func test_bot_clears_the_floor_and_items_follow() -> void:
	var wins := 0
	for s in 20:
		var run := Run.new(s)
		var guard := 0
		while run.phase != Run.Phase.WON and run.phase != Run.Phase.LOST and guard < 10:
			guard += 1
			if run.phase == Run.Phase.REWARD:
				run.take(0)
			_play_room(run)
		if run.phase == Run.Phase.WON:
			wins += 1
			check_eq(run.items.size(), run.plan.size(), "seed %d: one item per room" % s)
			check(run.bits > 0, "seed %d: earned bits" % s)
	check(wins >= 15, "a perfect bot wins most floors (%d/20)" % wins)


func test_lost_room_ends_the_run() -> void:
	var run := Run.new(5)
	run.take(0)
	run.session.room.fail()
	run.finish_room()
	check_eq(run.phase, Run.Phase.LOST, "lost")


func test_items_leave_the_old_bus() -> void:
	var run := Run.new(6)
	run.take(0)
	var old_bus := run.session.bus
	var surface_handlers := old_bus.handler_count(Events.SURFACE) + old_bus.handler_count(Events.BEFORE_MOVE) \
			+ old_bus.handler_count(Events.CHAIN) + old_bus.handler_count(Events.OVERFLOW)
	check(surface_handlers >= 1, "item attached")
	_play_room(run)
	var after := old_bus.handler_count(Events.SURFACE) + old_bus.handler_count(Events.BEFORE_MOVE) \
			+ old_bus.handler_count(Events.CHAIN) + old_bus.handler_count(Events.OVERFLOW)
	check_eq(after, 0, "detached when the room closed")
