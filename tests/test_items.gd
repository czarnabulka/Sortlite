extends TestCase


func _room_with(items: Array, values: Array = [1, 3, 2]) -> Room:
	var bus := EventBus.new()
	for item: Item in items:
		item.attach(bus)
	return bubble_room(values, 1_000_000, 5, -1, bus)


func test_sieve_adds_prime_values_to_mult() -> void:
	var room := _room_with([ItemCatalog.sieve()])
	room.start()
	room.play({"type": Events.SWAP, "index": 1})
	# 3: 30×(1+3)  2: 20×(2+2)  1: 10×3
	check_eq(room.score, 120 + 80 + 30, "score")


## Slot order is effect order, as with jokers.
func test_item_order_changes_the_result() -> void:
	var a := _room_with([ItemCatalog.sieve(), ItemCatalog.doubler()])
	a.start()
	a.play({"type": Events.SWAP, "index": 1})
	# (mult + prime) × 2:  30×8 + 20×8 + 10×6
	check_eq(a.score, 240 + 160 + 60, "sieve then doubler")

	var b := _room_with([ItemCatalog.doubler(), ItemCatalog.sieve()])
	b.start()
	b.play({"type": Events.SWAP, "index": 1})
	# mult × 2 + prime:  30×5 + 20×6 + 10×6
	check_eq(b.score, 150 + 120 + 60, "doubler then sieve")


func test_bubble_pump_needs_long_chains() -> void:
	var room := _room_with([ItemCatalog.bubble_pump()], [1, 2, 3, 4])
	room.start()
	# 40×1 + 30×2 + 20×(3+2) + 10×(4+2)
	check_eq(room.score, 260, "score")


func test_warm_cache_makes_first_move_free() -> void:
	var room := _room_with([ItemCatalog.warm_cache()], [3, 1, 2, 0])
	room.start()
	room.play({"type": Events.SWAP, "index": 0})
	check_eq(room.budget, 5, "first move free")
	room.play({"type": Events.SWAP, "index": 1})
	check_eq(room.budget, 4, "second move costs 1")


func test_detached_item_stops_acting() -> void:
	var sieve := ItemCatalog.sieve()
	var room := _room_with([sieve])
	sieve.detach()
	room.start()
	room.play({"type": Events.SWAP, "index": 1})
	check_eq(room.score, 100, "plain score")


func test_number_props() -> void:
	var primes: Array[int] = []
	var fibs: Array[int] = []
	for n in range(0, 22):
		if NumberProps.is_prime(n):
			primes.append(n)
		if NumberProps.is_fibonacci(n):
			fibs.append(n)
	check_eq(primes, [2, 3, 5, 7, 11, 13, 17, 19], "primes")
	check_eq(fibs, [0, 1, 2, 3, 5, 8, 13, 21], "fibonacci")
	var two := NumberProps.props_of(2)
	for p in [NumberProps.EVEN, NumberProps.PRIME, NumberProps.POW2, NumberProps.FIBONACCI]:
		check(two.has(p), "2 is %s" % p)
	check(NumberProps.props_of(9).has(NumberProps.SQUARE), "9 is a square")
	check(not NumberProps.is_pow2(12), "12 is not a power of two")


func test_parity_power_and_fibonacci() -> void:
	# [1, 3, 2]: one swap, then 3, 2, 1 surface as links 1, 2, 3.
	var room := _room_with([ItemCatalog.parity_bit()])
	room.start()
	room.play({"type": Events.SWAP, "index": 1})
	# 30×1 + (20+20)×2 + 10×3
	check_eq(room.score, 30 + 80 + 30, "parity bit")

	room = _room_with([ItemCatalog.power_tower()])
	room.start()
	room.play({"type": Events.SWAP, "index": 1})
	# 3 is not a power of two; 2 and 1 are: 30×1 + 40×2 + 20×3
	check_eq(room.score, 30 + 80 + 60, "power tower")

	room = _room_with([ItemCatalog.fibonacci_spiral()])
	room.start()
	room.play({"type": Events.SWAP, "index": 1})
	# all of 3, 2, 1 are Fibonacci: 30×4 + 20×5 + 10×6
	check_eq(room.score, 120 + 100 + 60, "fibonacci spiral")


func test_chain_reactor_gives_a_move_back() -> void:
	var room := _room_with([ItemCatalog.chain_reactor()], [1, 2, 4, 3])
	room.start()
	room.play({"type": Events.SWAP, "index": 2})
	check_eq(room.best_chain, 4, "chain of 4")
	check_eq(room.budget, 5, "spent 1, got 1 back")


func test_fuse_absorbs_one_overflow_per_room() -> void:
	var item := ItemCatalog.fuse()
	var bus := EventBus.new()
	item.attach(bus)
	var room := bubble_room([3, 1, 2], 1_000_000, 100, 3, bus, true)
	room.start()
	check_eq(room.arrive_batch([5]), 0, "first overflow absorbed")
	check_eq(room.arrive_batch([5]), 1, "second one counts")


func test_binary_search_caps_insert_cost() -> void:
	var item := ItemCatalog.binary_search()
	var bus := EventBus.new()
	item.attach(bus)
	var room := insertion_room([4, 6, 7, 9, 2], 1_000_000, 100, -1, bus)
	room.start()
	room.play({"type": Events.INSERT, "to": 0})
	check_eq(room.budget, 98, "4 shifts cost only 2")


func test_every_catalog_item_builds() -> void:
	for id in ItemCatalog.IDS:
		var item := ItemCatalog.make(id)
		check(item != null and item.id == id, "item %s" % id)
