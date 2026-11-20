extends SceneTree
## Balance numbers: bots play every room type of Run.ROOMS on many seeds
## until the move budget runs out (no target), with 0 and with 2 random
## items, and we compare their scores with the room's target.
##   godot --headless --path . -s res://sim/sim_rooms.gd
##
## Three players per room:
##   classic  the perfect bot in a classic room (numbers leave by themselves)
##   greedy   a ship room, shipping whatever is ready at once
##   smart    a ship room, letting runs grow and shipping the best part
## In a ship room, greedy should usually miss the target and smart should
## usually make it: that gap is what the ship decision is worth.

## Options after `--`: `--seeds 100` (default 300), `--only fight_bubble`
## (or a prefix with `*`: `--only "*quick"`), `--ship` (skip the classic rows),
## `--items 0,2` (how many random items, one row each; default 0,2),
## `--cap 6` (at most that many numbers per shipment instead of
## Run.MAX_SHIP; `--cap -1` = no cap). Items are
## drawn from those that work in the room's algorithm. By floor 2 a player
## holds 4-5 items: `--items 4,5`. `--build sieve,doubler` plays a fixed
## build instead (in that slot order), to see what a chosen build does.
##
## "one-shot" is the share of rooms where a single shipment scored the whole
## target: a room that one hand can clear has no ship decision left.
var seeds := 300
var build: Array[StringName] = []
## The shipment cap to play with; -2 = the room's own (Run.MAX_SHIP).
var cap := -2


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--seeds")
	if i >= 0 and i + 1 < args.size():
		seeds = int(args[i + 1])
	var only := ""
	i = args.find("--only")
	if i >= 0 and i + 1 < args.size():
		only = args[i + 1]
	var counts: Array[int] = [0, 2]
	i = args.find("--items")
	if i >= 0 and i + 1 < args.size():
		counts.clear()
		for n in args[i + 1].split(",", false):
			counts.append(int(n))
	i = args.find("--cap")
	if i >= 0 and i + 1 < args.size():
		cap = int(args[i + 1])
	i = args.find("--build")
	if i >= 0 and i + 1 < args.size():
		for id in args[i + 1].split(",", false):
			build.append(StringName(id))
		counts = [build.size()]
	for key: StringName in Run.ROOMS:
		if only != "" and not String(key).match(only):
			continue
		for n_items in counts:
			if not args.has("--ship"):
				_report(key, Run.ROOMS[key], n_items, false, Bots.SMART)
			_report(key, Run.ROOMS[key], n_items, true, Bots.GREEDY)
			_report(key, Run.ROOMS[key], n_items, true, Bots.SMART)
	quit()


func _report(key: StringName, room_cfg: Dictionary, n_items: int, ship: bool, policy: StringName) -> void:
	var scores: Array[int] = []
	var lost_lives := 0
	var beat_target := 0
	var one_shot := 0
	var cfg0 := Run.session_config(room_cfg, ship)
	var target := int(cfg0["target"])
	for s in seeds:
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 7919
		var items: Array[Item] = []
		var pool: Array[StringName] = []
		for id in ItemCatalog.IDS:
			var only: StringName = ItemCatalog.make(id).algorithm
			if only == &"" or only == room_cfg["algorithm"]:
				pool.append(id)
		for i in mini(n_items, pool.size()):
			items.append(ItemCatalog.make(pool.pop_at(rng.randi_range(0, pool.size() - 1))))
		if not build.is_empty():
			items.clear()
			for id in build:
				items.append(ItemCatalog.make(id))
		# No target, so the bot plays until the budget runs out; the boss still
		# gets enraged where the real target would make it.
		var cfg := cfg0.duplicate()
		cfg["enrage_at"] = ceili(target / 2.0)
		cfg["target"] = 1_000_000_000
		if cap != -2:
			cfg["max_ship"] = cap
		var session := RoomSession.new(s, RoomSession.ArrivalMode.TURNS, items, cfg)
		session.start()
		var guard := 0
		var lives_at_target := -1
		var best_hand := 0
		while session.is_playing() and guard < 2000:
			guard += 1
			var move := Bots.choose_in(session, policy)
			var before := session.room.score
			if move.is_empty() or not session.play(move):
				session.deliver()
			elif move.get("type") == Events.SHIP:
				best_hand = maxi(best_hand, session.room.score - before)
			if lives_at_target < 0 and session.room.score >= target:
				lives_at_target = session.lives
		scores.append(session.room.score)
		# Lives lost on the way to the target (the real room ends there).
		lost_lives += session.max_lives - maxi(lives_at_target if lives_at_target >= 0 else session.lives, 0)
		if session.room.score >= target:
			beat_target += 1
		if best_hand >= target:
			one_shot += 1
	scores.sort()
	var who := ("ship-" + String(policy)) if ship else "classic"
	print("%-16s %-12s items=%d  p10=%6d p25=%6d p50=%6d p75=%6d  target %5d beaten %3d%%  one-shot %3d%%  lives lost %.2f" % [
		key, who, n_items, _p(scores, 0.10), _p(scores, 0.25), _p(scores, 0.50), _p(scores, 0.75),
		target, int(100.0 * beat_target / seeds), int(100.0 * one_shot / seeds), float(lost_lives) / seeds])


func _p(sorted_values: Array[int], q: float) -> int:
	return sorted_values[clampi(int(q * (sorted_values.size() - 1)), 0, sorted_values.size() - 1)]
