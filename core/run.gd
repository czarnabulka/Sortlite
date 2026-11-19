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


func _init(p_seed: int, p_mode := RoomSession.ArrivalMode.TURNS) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	mode = p_mode
	plan = floor_plan(rng)
	_make_offer()


## Every room type of floor 1. Targets are about half of what the perfect
## bot scores with no items (sim/sim_rooms.gd plays exactly these), because
## people are slower and make wrong moves.
const ROOMS := {
	&"fight_bubble": {"kind": FIGHT, "algorithm": Algorithms.BUBBLE, "target": 1500, "budget": 40},
	&"fight_insertion": {"kind": FIGHT, "algorithm": Algorithms.INSERTION, "target": 2800, "budget": 40},
	&"elite_bubble": {"kind": ELITE, "algorithm": Algorithms.BUBBLE, "kind_data": DataGen.REVERSED,
			"start": 5, "every_moves": 4, "target": 1800, "budget": 45},
	&"elite_insertion": {"kind": ELITE, "algorithm": Algorithms.INSERTION, "kind_data": DataGen.REVERSED,
			"start": 7, "every_moves": 4, "target": 3000, "budget": 45},
	&"boss_adversary": {"kind": BOSS, "algorithm": Algorithms.BUBBLE, "feed": RoomSession.FEED_ADVERSARY,
			"boss": RoomSession.BOSS_ADVERSARY, "strike_every": 4, "start": 5, "every_moves": 4,
			"target": 2400, "budget": 60},

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

func take(index: int) -> bool:
	if phase != Phase.REWARD or index < 0 or index >= offer.size() or items.size() >= MAX_SLOTS:
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
	var r := current_room()
	var config := {
		"algorithm": r["algorithm"],
		"target": r["target"],
		"budget": r["budget"],
		"kind": r.get("kind_data", DataGen.RANDOM),
		"feed": r.get("feed", RoomSession.FEED_RANDOM),
		"start": r.get("start", 5),
		"every_moves": r.get("every_moves", 3),
		"boss": r.get("boss", RoomSession.BOSS_NONE),
		"strike_every": r.get("strike_every", 5),
		"lives": lives,
		"max_lives": max_lives,
	}
	session = RoomSession.new(rng.randi(), mode, items, config)
	phase = Phase.ROOM
	session.start()


func _make_offer() -> void:
	offer.clear()
	var owned := {}
	for item in items:
		owned[item.id] = true
	var pool: Array[StringName] = []
	for id in ItemCatalog.IDS:
		if not owned.has(id):
			pool.append(id)
	for i in mini(OFFER_SIZE, pool.size()):
		var id: StringName = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		offer.append(ItemCatalog.make(id))
