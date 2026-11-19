class_name ItemCatalog
extends RefCounted
## First items, to prove the event model. The full list lives in the design doc.


## Every surfacing that is link 3 or later of a chain: +2 mult.
static func bubble_pump() -> Item:
	return Item.new(&"bubble_pump", "Bubble Pump",
			"Zaliczenie z łańcucha ≥ 3: +2 do mnożnika.", [Events.SURFACE, Events.CHAIN]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if ctx.chain >= 3:
				ctx.mult += 2)


## A prime that surfaces adds its own value to the mult.
static func sieve() -> Item:
	return Item.new(&"sieve", "Sito Eratostenesa",
			"Zaliczona liczba pierwsza: + jej wartość do mnożnika.", [Events.SURFACE, NumberProps.PRIME]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			if NumberProps.is_prime(ctx.element.value):
				ctx.mult += ctx.element.value)


## Doubles the mult of every surfacing. Order against other items matters:
## after Sieve it doubles Sieve's bonus too.
static func doubler() -> Item:
	return Item.new(&"doubler", "Podwajacz",
			"Mnożnik każdego zaliczenia ×2.", [Events.SURFACE]) \
		.react(Events.SURFACE, func(data: Dictionary) -> void:
			var ctx: ScoreContext = data["ctx"]
			ctx.mult *= 2)


## The first move of each room is free.
static func warm_cache() -> Item:
	var used := [false]  # boxed, so the lambdas share it
	var item := Item.new(&"warm_cache", "Ciepły cache",
			"Pierwszy ruch w pokoju nic nie kosztuje.", [Events.BEFORE_MOVE])
	item.react(Events.ROOM_START, func(_data: Dictionary) -> void:
		used[0] = false)
	item.react(Events.BEFORE_MOVE, func(data: Dictionary) -> void:
		if not used[0]:
			var ctx: MoveContext = data["ctx"]
			ctx.cost = 0
			used[0] = true)
	return item
