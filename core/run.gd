class_name Run
extends RefCounted
## One run: floors of rooms, items that carry over, lives, and bits.
## Before every room the player picks 1 of 3 items (or skips for bits).
## Everything is drawn from one seeded generator, so a seed replays a run.

enum Phase { REWARD, ROOM, WON, LOST }

const FIGHT := &"fight"
const ELITE := &"elite"
const BOSS := &"boss"

const MAX_SLOTS := 6
const OFFER_SIZE := 3
const START_LIVES := 3
const REROLL_COST := 2
const HEAL_COST := 5
const SKIP_BITS := 3
## Bits for a cleared room, plus one per BITS_PER_MOVES unused moves.
const ROOM_BITS := {FIGHT: 3, ELITE: 5, BOSS: 6}
const BITS_PER_MOVES := 5

var seed_value: int
var rng := RandomNumberGenerator.new()
var mode: RoomSession.ArrivalMode
## Ship rooms (you send sorted runs out yourself, scored as hands) or classic
## rooms (sorted numbers leave by themselves). `-- --classic` picks classic.
var ship: bool
var plan: Array[Dictionary] = []
var cleared := 0
var phase := Phase.REWARD
var lives := START_LIVES
var max_lives := START_LIVES
var bits := 0
var items: Array[Item] = []
var offer: Array[Item] = []
var session: RoomSession
var scores: Array[int] = []


func _init(p_seed: int, p_mode := RoomSession.ArrivalMode.TURNS, p_ship := true) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	mode = p_mode
	ship = p_ship
	plan = floor_plan(rng)
	_make_offer()


## Every room type. Classic targets are about half of what the
## perfect bot scores with no items, because people are slower and make wrong
## moves. "ship_cfg" overrides a ship room: its target sits between what a
## greedy shipper and a smart one score (sim/sim_rooms.gd plays exactly these).
const ROOMS := {
	&"fight_bubble": {"kind": FIGHT, "algorithm": Algorithms.BUBBLE, "target": 1500, "budget": 40,
			"ship_cfg": {"every_moves": 4, "target": 4000, "ships": 7}},
	&"fight_insertion": {"kind": FIGHT, "algorithm": Algorithms.INSERTION, "target": 2800, "budget": 40,
			"ship_cfg": {"every_moves": 2, "target": 5000, "ships": 5}},
	&"elite_bubble": {"kind": ELITE, "algorithm": Algorithms.BUBBLE, "kind_data": DataGen.REVERSED,
			"start": 5, "every_moves": 4, "target": 1800, "budget": 45,
			"ship_cfg": {"every_moves": 5, "target": 3200, "ships": 7}},
	# Reversed data makes the whole column ready at once in Insertion, so
	# shipping at once would always be best: ship rooms use duplicates instead.
	&"elite_insertion": {"kind": ELITE, "algorithm": Algorithms.INSERTION, "kind_data": DataGen.REVERSED,
			"start": 7, "every_moves": 4, "target": 3000, "budget": 45,
			"ship_cfg": {"kind_data": DataGen.DUPES, "target": 6000, "ships": 6}},
	&"boss_adversary": {"kind": BOSS, "algorithm": Algorithms.BUBBLE, "feed": RoomSession.FEED_ADVERSARY,
			"boss": RoomSession.BOSS_ADVERSARY, "strike_every": 4, "start": 5, "every_moves": 4,
			"target": 2400, "budget": 60,
			"ship_cfg": {"every_moves": 5, "strike_every": 5, "target": 4500, "ships": 12}},
	# Floor 2. Pancake moves are strong (two flips bring any number down), so
	# its rooms have fewer moves and faster arrivals. Ship targets are tuned
	# for the 5-6 items a player holds by now (`sim/sim_rooms.gd -- --items 5`),
	# not for an empty hand: with floor 1's targets a good build cleared most
	# rooms with one shipment.
	&"fight_pancake": {"kind": FIGHT, "algorithm": Algorithms.PANCAKE, "target": 1900, "budget": 32,
			"every_moves": 2, "ship_cfg": {"every_moves": 3, "target": 9000, "ships": 7}},
	# Quick: a pivot costs one comparison per other number in its segment.
	# Splits hand out long sorted runs by themselves, so with more shipments
	# shipping at once was nearly as good as waiting: Quick rooms get 4.
	&"fight_quick": {"kind": FIGHT, "algorithm": Algorithms.QUICK, "target": 4000, "budget": 40,
			"ship_cfg": {"every_moves": 3, "target": 8500, "ships": 4}},
	&"elite_pancake": {"kind": ELITE, "algorithm": Algorithms.PANCAKE, "start": 6, "target": 2300, "budget": 40,
			"every_moves": 2, "ship_cfg": {"every_moves": 3, "target": 8000, "ships": 7}},
	# Many equal numbers: a pivot sends its equals to one side, so the
	# segments stay long unless the pivots are chosen well.
	&"elite_quick": {"kind": ELITE, "algorithm": Algorithms.QUICK, "kind_data": DataGen.DUPES, "start": 7,
			"target": 3800, "budget": 44, "ship_cfg": {"every_moves": 3, "target": 9000, "ships": 4}},
	# The Burnt Stack: a Pancake room where numbers have a burnt side.
	&"boss_burnt": {"kind": BOSS, "algorithm": Algorithms.PANCAKE, "boss": RoomSession.BOSS_BURNT,
			"strike_every": 4, "start": 5, "every_moves": 4, "target": 1800, "budget": 56,
			"ship_cfg": {"target": 10500, "ships": 12}},
}

## The floors of a run, in order. A fight entry lists the rooms it is drawn
## from; the two fights come in random order, then the elite, then the boss.
const FLOORS := [
	{"fights": [[&"fight_bubble"], [&"fight_insertion"]],
			"elites": [&"elite_bubble", &"elite_insertion"], "boss": &"boss_adversary"},
	{"fights": [[&"fight_pancake"], [&"fight_quick"]],
			"elites": [&"elite_pancake", &"elite_quick"], "boss": &"boss_burnt"},
]


## Floor 1: a Bubble and an Insertion fight, an elite on harder data, and the
## Adversary, whose newcomers are the worst ones. Floor 2: a Pancake and a
## Quick fight, an elite of one of them, and the Burnt Stack.
## Every room carries its "floor" (1, 2, ...).
static func floor_plan(r: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in FLOORS.size():
		var floor_def: Dictionary = FLOORS[f]
		var fights: Array[StringName] = []
		for choice: Array in floor_def["fights"]:
			fights.append(choice[r.randi_range(0, choice.size() - 1)] if choice.size() > 1 else choice[0])
		if r.randf() < 0.5:
			fights.reverse()
		var elites: Array = floor_def["elites"]
		var elite: StringName = elites[r.randi_range(0, elites.size() - 1)] if elites.size() > 1 else elites[0]
		for key in [fights[0], fights[1], elite, floor_def["boss"]]:
			var room: Dictionary = ROOMS[key].duplicate()
			room["id"] = key
			room["floor"] = f + 1
			out.append(room)
	return out


func current_room() -> Dictionary:
	return plan[mini(cleared, plan.size() - 1)]


## The floor of the current room (1, 2, ...).
func floor_no() -> int:
	return int(current_room()["floor"])


## Plan indices of the current floor's rooms, in order.
func floor_rooms() -> Array[int]:
	var out: Array[int] = []
	for i in plan.size():
		if int(plan[i]["floor"]) == floor_no():
			out.append(i)
	return out


## True when the next room is the first one of a floor after the first.
func floor_starts() -> bool:
	return cleared > 0 and cleared < plan.size() and floor_rooms()[0] == cleared


# --- reward phase ------------------------------------------------------------

func slots_full() -> bool:
	return items.size() >= MAX_SLOTS


## Takes offer card `index`. With every slot full, `replace` names the slot
## the new item goes into: the old item there is dropped, and the slot order
## (the order items act in) stays as it was.
func take(index: int, replace := -1) -> bool:
	if phase != Phase.REWARD or index < 0 or index >= offer.size():
		return false
	if slots_full():
		if replace < 0 or replace >= items.size():
			return false
		items[replace] = offer[index]
	else:
		items.append(offer[index])
	_start_room()
	return true


func skip() -> bool:
	if phase != Phase.REWARD:
		return false
	bits += SKIP_BITS
	_start_room()
	return true


func reroll() -> bool:
	if phase != Phase.REWARD or bits < REROLL_COST:
		return false
	bits -= REROLL_COST
	_make_offer()
	return true


func heal() -> bool:
	if phase != Phase.REWARD or bits < HEAL_COST or lives >= max_lives:
		return false
	bits -= HEAL_COST
	lives += 1
	return true


# --- room phase ----------------------------------------------------------------

## Call when the current session is no longer playing.
func finish_room() -> void:
	if phase != Phase.ROOM or session == null or session.is_playing():
		return
	var room := session.room
	session.close()
	scores.append(room.score)
	lives = session.lives
	if room.state != Room.State.WON:
		phase = Phase.LOST
		return
	var kind: StringName = current_room()["kind"]
	bits += int(ROOM_BITS.get(kind, 0)) + room.budget / BITS_PER_MOVES
	cleared += 1
	if cleared >= plan.size():
		phase = Phase.WON
	else:
		phase = Phase.REWARD
		_make_offer()


func _start_room() -> void:
	var config := session_config(current_room(), ship)
	config["lives"] = lives
	config["max_lives"] = max_lives
	session = RoomSession.new(rng.randi(), mode, items, config)
	phase = Phase.ROOM
	session.start()


## RoomSession config for one entry of ROOMS (shared with sim/sim_rooms.gd).
## A ship room first applies the entry's "ship_cfg" overrides.
static func session_config(entry: Dictionary, p_ship := false) -> Dictionary:
	var r := entry.duplicate()
	if p_ship:
		r.merge(entry.get("ship_cfg", {}), true)
	return {
		"ship": p_ship,
		"algorithm": r["algorithm"],
		"target": r["target"],
		"budget": r["budget"],
		"kind": r.get("kind_data", DataGen.RANDOM),
		"feed": r.get("feed", RoomSession.FEED_RANDOM),
		"start": r.get("start", 5),
		"every_moves": r.get("every_moves", 3),
		"boss": r.get("boss", RoomSession.BOSS_NONE),
		"strike_every": r.get("strike_every", 5),
		"ships": r.get("ships", -1),
	}


func _make_offer() -> void:
	offer.clear()
	var owned := {}
	for item in items:
		owned[item.id] = true
	# An item for one algorithm is offered only while a room of it is ahead.
	var ahead := {}
	for i in range(cleared, plan.size()):
		ahead[plan[i]["algorithm"]] = true
	var pool: Array[StringName] = []
	for id in ItemCatalog.IDS:
		var only: StringName = ItemCatalog.make(id).algorithm
		if not owned.has(id) and (only == &"" or ahead.has(only)):
			pool.append(id)
	for i in mini(OFFER_SIZE, pool.size()):
		var id: StringName = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		offer.append(ItemCatalog.make(id))
