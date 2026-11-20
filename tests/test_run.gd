extends TestCase


## Plays the current room with the perfect bot until it ends.
func _play_room(run: Run) -> void:
	var s := run.session
	var guard := 0
	while s.is_playing() and guard < 2000:
		guard += 1
		var move := Bots.choose_in(s)
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


func test_floors_have_their_algorithms_and_a_boss() -> void:
	for s in 20:
		var run := Run.new(s)
		check_eq(run.plan.size(), 4 * Run.FLOORS.size(), "seed %d: four rooms a floor" % s)
		var first := {}
		for r in run.plan.slice(0, 4):
			first[r["algorithm"]] = true
			check_eq(r["floor"], 1, "seed %d: floor 1" % s)
		check(first.has(Algorithms.BUBBLE) and first.has(Algorithms.INSERTION), "seed %d: floor 1 has both" % s)
		var second: Array = run.plan.slice(4, 8).map(func(r: Dictionary) -> StringName: return r["algorithm"])
		check(second.has(Algorithms.PANCAKE) and second.has(Algorithms.QUICK), "seed %d: floor 2 has Pancake and Quick" % s)
		for i in [3, 7]:
			check_eq(run.plan[i]["kind"], Run.BOSS, "seed %d: boss closes floor %d" % [s, i / 4 + 1])
		check_eq(run.plan[7]["boss"], RoomSession.BOSS_BURNT, "seed %d: the Burnt Stack last" % s)


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


func test_bot_clears_floors_and_items_follow() -> void:
	var floor_1 := 0
	var wins := 0
	for s in 20:
		var run := Run.new(s)
		var guard := 0
		while run.phase != Run.Phase.WON and run.phase != Run.Phase.LOST and guard < 20:
			guard += 1
			if run.phase == Run.Phase.REWARD and not run.take(0):
				run.skip()
			_play_room(run)
		if run.cleared >= 4:
			floor_1 += 1
			check_eq(run.items.size(), mini(run.cleared + 1, Run.MAX_SLOTS), "seed %d: one item per room" % s)
			check(run.bits > 0, "seed %d: earned bits" % s)
		if run.phase == Run.Phase.WON:
			wins += 1
	# The smart bot taking the first offer clears floor 1 in about 2/3 of runs
	# (66 of seeds 0-99); below 12/20 something got much harder.
	check(floor_1 >= 12, "a perfect bot clears floor 1 in most runs (%d/20)" % floor_1)
	check(wins >= 4, "and sometimes the whole run (%d/20)" % wins)


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


func test_offer_skips_items_for_algorithms_no_longer_ahead() -> void:
	for s in 30:
		var run := Run.new(s)
		run.cleared = run.plan.size() - 1  # only the last boss (Pancake) is left
		run._make_offer()
		for item in run.offer:
			check(item.algorithm == &"" or item.algorithm == Algorithms.PANCAKE,
					"seed %d: %s is useless in a Pancake room" % [s, item.id])


func test_full_slots_refuse_a_pick_but_allow_a_skip() -> void:
	var run := Run.new(7)
	for id in ItemCatalog.IDS.slice(0, Run.MAX_SLOTS):
		run.items.append(ItemCatalog.make(id))
	check(run.slots_full(), "full")
	check(not run.take(0), "no room for another item")
	check_eq(run.phase, Run.Phase.REWARD, "still choosing")
	check(run.skip(), "skip still works")
	check_eq(run.phase, Run.Phase.ROOM, "room started")
