class_name ItemCatalog
extends RefCounted
## All items. Names and descriptions live in i18n/strings.csv as
## ITEM_<ID>_NAME / _DESC. A handler that changes a score writes the item id
## into ctx.notes (the screen flashes it when that score pops); any other
## effect emits Events.ITEM_TRIGGERED.

const IDS: Array[StringName] = [
	&"sieve", &"bubble_pump", &"doubler", &"warm_cache", &"parity_bit",
	&"fibonacci_spiral", &"power_tower", &"chain_reactor", &"fuse", &"binary_search",
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
	push_error("ItemCatalog: unknown id '%s'" % id)
	return null


static func _ping(data: Dictionary, id: StringName) -> void:
	var room: Room = data["room"]
	room.bus.emit(Events.ITEM_TRIGGERED, {"room": room, "id": id})


## Every surfacing that is link 3 or later of a chain: +2 mult.
static func bubble_pump() -> Item:
	return Item.new(&"bubble_pump", [Events.SURFACE, Events.CHAIN]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if ctx.chain >= 3:
				ctx.mult += 2
				ctx.notes.append(&"bubble_pump"))


## A prime that surfaces adds its own value to the mult.
static func sieve() -> Item:
	return Item.new(&"sieve", [Events.SURFACE, NumberProps.PRIME]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if NumberProps.is_prime(ctx.element.value):
				ctx.mult += ctx.element.value
				ctx.notes.append(&"sieve"))


## Doubles the mult of every surfacing. Order against other items matters:
## after Sieve it doubles Sieve's bonus too.
static func doubler() -> Item:
	return Item.new(&"doubler", [Events.SURFACE]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			ctx.mult *= 2
			ctx.notes.append(&"doubler"))


## An even number that surfaces: +20 points.
static func parity_bit() -> Item:
	return Item.new(&"parity_bit", [Events.SURFACE, NumberProps.EVEN]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if ctx.element.value % 2 == 0:
				ctx.points += 20
				ctx.notes.append(&"parity_bit"))


## A Fibonacci number that surfaces: +3 mult.
static func fibonacci_spiral() -> Item:
	return Item.new(&"fibonacci_spiral", [Events.SURFACE, NumberProps.FIBONACCI]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if NumberProps.is_fibonacci(ctx.element.value):
				ctx.mult += 3
				ctx.notes.append(&"fibonacci_spiral"))


## A power of two that surfaces: its points ×2.
static func power_tower() -> Item:
	return Item.new(&"power_tower", [Events.SURFACE, NumberProps.POW2]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if NumberProps.is_pow2(ctx.element.value):
				ctx.points *= 2
				ctx.notes.append(&"power_tower"))


## A chain of 4 or more gives 1 move back.
static func chain_reactor() -> Item:
	return Item.new(&"chain_reactor", [Events.CHAIN]) \
		.react(Events.CHAIN, func(data: Dictionary) -> void:
			if int(data["length"]) >= 4:
				var room: Room = data["room"]
				room.budget += 1
				_ping(data, &"chain_reactor"))


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
			_ping(data, &"fuse"))
	return item


## In Insertion rooms an insert never costs more than 2.
static func binary_search() -> Item:
	return Item.new(&"binary_search", [Events.BEFORE_MOVE, Events.INSERT]) \
		.react(Events.BEFORE_MOVE, func(data: Dictionary) -> void:
			var ctx: MoveContext = data["ctx"]
			if ctx.move.get("type") == Events.INSERT and ctx.cost > 2:
				ctx.cost = 2
				ctx.notes.append(&"binary_search")
				_ping(data, &"binary_search"))


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
			ctx.notes.append(&"warm_cache")
			used[0] = true
			_ping(data, &"warm_cache"))
	return item
