class_name ItemCatalog
extends RefCounted
## All items. Names and descriptions live in i18n/strings.csv as
## ITEM_<ID>_NAME / _DESC. A handler that changes a score writes the item id
## into ctx.notes (the screen flashes it when that score pops); any other
## effect emits Events.ITEM_TRIGGERED.

## Marker Median of Three leaves on a well-chosen pivot.
const MEDIAN := &"median"

const IDS: Array[StringName] = [
	&"sieve", &"bubble_pump", &"doubler", &"warm_cache", &"parity_bit",
	&"fibonacci_spiral", &"power_tower", &"chain_reactor", &"fuse", &"binary_search",
	&"express_lane", &"spatula", &"median_of_three",
]


static func make(id: StringName) -> Item:
	match id:
		&"sieve": return sieve()
		&"bubble_pump": return bubble_pump()
		&"doubler": return doubler()
		&"warm_cache": return warm_cache()
		&"parity_bit": return parity_bit()
		&"fibonacci_spiral": return fibonacci_spiral()
		&"power_tower": return power_tower()
		&"chain_reactor": return chain_reactor()
		&"fuse": return fuse()
		&"binary_search": return binary_search()
		&"express_lane": return express_lane()
		&"spatula": return spatula()
		&"median_of_three": return median_of_three()
	push_error("ItemCatalog: unknown id '%s'" % id)
	return null


## `label` is a translation key the screen shows over the item (optional).
static func _ping(data: Dictionary, id: StringName, label := "") -> void:
	var room: Room = data["room"]
	room.bus.emit(Events.ITEM_TRIGGERED, {"room": room, "id": id, "label": label})


## Every surfacing that is link 3 or later of a chain: +2 mult.
static func bubble_pump() -> Item:
	return Item.new(&"bubble_pump", [Events.SURFACE, Events.CHAIN]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if ctx.chain >= 3:
				ctx.apply(&"bubble_pump", ScoreContext.MULT, 2))


## A prime that scores adds half its value (rounded up) to its mult. (Its
## whole value made Sieve + Doubler win rooms with one shipment.)
static func sieve() -> Item:
	return Item.new(&"sieve", [Events.SURFACE, NumberProps.PRIME]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if NumberProps.is_prime(ctx.element.value):
				ctx.apply(&"sieve", ScoreContext.MULT, ceili(ctx.element.value / 2.0)))


## Every second number of a shipment or chain (the 2nd, 4th, ...) gets mult
## ×2. Order against other items matters: after Sieve it doubles Sieve's
## bonus too. (Every number made it the best item by far: a hand's mult is
## already large before any item.)
static func doubler() -> Item:
	return Item.new(&"doubler", [Events.SURFACE]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if ctx.chain % 2 == 0:
				ctx.apply(&"doubler", ScoreContext.XMULT, 2))


## An even number that surfaces: +20 points.
static func parity_bit() -> Item:
	return Item.new(&"parity_bit", [Events.SURFACE, NumberProps.EVEN]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if ctx.element.value % 2 == 0:
				ctx.apply(&"parity_bit", ScoreContext.POINTS, 20))


## A Fibonacci number that surfaces: +3 mult.
static func fibonacci_spiral() -> Item:
	return Item.new(&"fibonacci_spiral", [Events.SURFACE, NumberProps.FIBONACCI]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if NumberProps.is_fibonacci(ctx.element.value):
				ctx.apply(&"fibonacci_spiral", ScoreContext.MULT, 3))


## A power of two that surfaces: its points ×2.
static func power_tower() -> Item:
	return Item.new(&"power_tower", [Events.SURFACE, NumberProps.POW2]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if NumberProps.is_pow2(ctx.element.value):
				ctx.apply(&"power_tower", ScoreContext.XPOINTS, 2))


## A chain of 4 or more gives 1 move back.
static func chain_reactor() -> Item:
	return Item.new(&"chain_reactor", [Events.CHAIN]) \
		.react(Events.CHAIN, func(data: Dictionary) -> void:
			if int(data["length"]) >= 4:
				var room: Room = data["room"]
				room.budget += 1
				_ping(data, &"chain_reactor", "FX_MOVE_BACK"))


## The first overflow in each room costs no life.
static func fuse() -> Item:
	var blown := [false]  # boxed, so the lambdas share it
	var item := Item.new(&"fuse", [Events.OVERFLOW])
	item.react(Events.ROOM_START, func(_data: Dictionary) -> void:
		blown[0] = false)
	item.react(Events.OVERFLOW, func(data: Dictionary) -> void:
		if not blown[0] and not data["absorbed"]:
			data["absorbed"] = true
			blown[0] = true
			_ping(data, &"fuse", "FX_SAVED"))
	return item


## In Insertion rooms an insert never costs more than 2.
static func binary_search() -> Item:
	return Item.new(&"binary_search", [Events.BEFORE_MOVE, Events.INSERT]) \
		.only_for(Algorithms.INSERTION) \
		.react(Events.BEFORE_MOVE, func(data: Dictionary) -> void:
			var ctx: MoveContext = data["ctx"]
			if ctx.move.get("type") == Events.INSERT and ctx.cost > 2:
				ctx.cost = 2
				ctx.note(&"binary_search", "FX_CHEAPER"))


## The first move of each room is free.
static func warm_cache() -> Item:
	var used := [false]  # boxed, so the lambdas share it
	var item := Item.new(&"warm_cache", [Events.BEFORE_MOVE])
	item.react(Events.ROOM_START, func(_data: Dictionary) -> void:
		used[0] = false)
	item.react(Events.BEFORE_MOVE, func(data: Dictionary) -> void:
		if not used[0]:
			var ctx: MoveContext = data["ctx"]
			ctx.cost = 0
			ctx.note(&"warm_cache", "FX_FREE")
			used[0] = true)
	return item


## Bubble only: a correct swap that lifts the biggest number not yet in place
## keeps carrying it up for free, up to 3 more places. (Unlimited made the
## boss trivial.)
static func express_lane() -> Item:
	return Item.new(&"express_lane", [Events.SWAP]) \
		.only_for(Algorithms.BUBBLE) \
		.react(Events.SWAP, func(data: Dictionary) -> void:
			if data["wrong"]:
				return
			var room: Room = data["room"]
			var board := room.board
			var j: int = int(data["move"]["index"]) + 1
			# Above `free` the numbers are already in place (a ship room keeps them).
			var free := board.size() - room.ready_count()
			if j >= free:
				return
			for i in free:
				if board.value_at(i) > board.value_at(j):
					return
			var carried := 0
			while carried < 3 and j < board.size() - 1 and board.value_at(j) > board.value_at(j + 1):
				board.swap(j, j + 1)
				j += 1
				carried += 1
			if carried > 0:
				_ping(data, &"express_lane", "FX_EXPRESS"))


## Pancake only: every second flip that brings the biggest unsorted number
## down onto the sorted bottom is free. (Every one of them halved Pancake's
## cost: the strongest single item by far.)
static func spatula() -> Item:
	var count := [0]  # boxed, so the lambdas share it
	var item := Item.new(&"spatula", [Events.BEFORE_MOVE, Events.FLIP]).only_for(Algorithms.PANCAKE)
	item.react(Events.ROOM_START, func(_data: Dictionary) -> void:
		count[0] = 0)
	item.react(Events.BEFORE_MOVE, func(data: Dictionary) -> void:
		var ctx: MoveContext = data["ctx"]
		if ctx.move.get("type") != Events.FLIP or ctx.cost <= 0:
			return
		var room: Room = data["room"]
		var board := room.board
		var ready := room.ready_count()
		if int(ctx.move["index"]) != ready or ready >= board.size():
			return
		var top := board.value_at(board.size() - 1)
		for i in range(ready, board.size()):
			if board.value_at(i) > top:
				return
		count[0] += 1
		if count[0] % 2 == 0:
			ctx.cost = 0
			ctx.note(&"spatula", "FX_FREE"))
	return item


## Quick only: a pivot that was its segment's middle value (a balanced
## split, the real Quick Sort's median-of-three trick) scores mult ×2 when it
## leaves. (Cheaper splits did nothing: Quick rooms run out of shipments,
## not moves.)
static func median_of_three() -> Item:
	var item := Item.new(&"median_of_three", [Events.BEFORE_MOVE, Events.SURFACE]).only_for(Algorithms.QUICK)
	item.react(Events.BEFORE_MOVE, func(data: Dictionary) -> void:
		var ctx: MoveContext = data["ctx"]
		if ctx.move.get("type") != Events.PARTITION:
			return
		var room: Room = data["room"]
		var algo := room.algorithm as QuickAlgorithm
		var p: int = ctx.move["index"]
		var seg := algo.segment_of(room.board, p)
		var values: Array[int] = []
		for i in range(seg.x, seg.y):
			values.append(room.board.value_at(i))
		values.sort()
		var e := room.board.cells[p]
		if seg.y - seg.x >= 3 and e.value == values[(values.size() - 1) / 2]:
			e.markers[MEDIAN] = true)
	item.react(Events.SURFACE, func(data: Dictionary) -> void:
		var ctx: ScoreContext = data["ctx"]
		if ctx.element.has_marker(MEDIAN):
			ctx.apply(&"median_of_three", ScoreContext.XMULT, 2))
	return item
