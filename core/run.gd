class_name Run
extends RefCounted
## One run: a floor of rooms, items that carry over, lives, and bits.
## Before every room the player picks 1 of 3 items (or skips for bits).
## Everything is drawn from one seeded generator, so a seed replays a run.

enum Phase { REWARD, ROOM, WON, LOST }

const FIGHT := &"fight"
const ELITE := &"elite"
const BOSS := &"boss"

const MAX_SLOTS := 5
const OFFER_SIZE := 3
const START_LIVES := 3
const REROLL_COST := 2
const HEAL_COST := 5
const SKIP_BITS := 3
## Bits for a cleared room, plus one per BITS_PER_MOVES unused moves.
const ROOM_BITS := {FIGHT: 3, ELITE: 5, BOSS: 0}
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


## Every room type of floor 1. Classic targets are about half of what the
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
}


## Floor 1: two fights (one per algorithm, random order), an elite on
## reversed data, and the Adversary boss, whose newcomers are the worst ones.
static func floor_plan(r: RandomNumberGenerator) -> Array[Dictionary]:
	var fights: Array[StringName] = [&"fight_bubble", &"fight_insertion"]
	if r.randf() < 0.5:
		fights.reverse()
	var elite: StringName = [&"elite_bubble", &"elite_insertion"][r.randi_range(0, 1)]
	var out: Array[Dictionary] = []
	for key in [fights[0], fights[1], elite, &"boss_adversary"]:
		var room: Dictionary = ROOMS[key].duplicate()
		room["id"] = key
		out.append(room)
	return out


func current_room() -> Dictionary:
	return plan[mini(cleared, plan.size() - 1)]


# --- reward phase ------------------------------------------------------------

func slots_full() -> bool:
	return items.size() >= MAX_SLOTS


func take(index: int) -> bool:
	if phase != Phase.REWARD or index < 0 or index >= offer.size() or slots_full():
		return false
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
