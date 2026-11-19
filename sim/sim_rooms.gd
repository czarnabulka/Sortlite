extends SceneTree
## Balance numbers: the perfect bot plays every room type of Run.ROOMS on
## many seeds until the move budget runs out (no target), with 0 and with 2
## random items, and we compare its score with the room's target.
##   godot --headless --path . -s res://sim/sim_rooms.gd

const SEEDS := 300


func _initialize() -> void:
	for key: StringName in Run.ROOMS:
		for n_items in [0, 2]:
			_report(key, Run.ROOMS[key], n_items)
	quit()


func _report(key: StringName, room_cfg: Dictionary, n_items: int) -> void:
	var scores: Array[int] = []
	var lost_lives := 0
	var beat_target := 0
	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 7919
		var items: Array[Item] = []
		var pool := ItemCatalog.IDS.duplicate()
		for i in n_items:
			items.append(ItemCatalog.make(pool.pop_at(rng.randi_range(0, pool.size() - 1))))
		var cfg := {
			"algorithm": room_cfg["algorithm"],
			"budget": room_cfg["budget"],
			"kind": room_cfg.get("kind_data", DataGen.RANDOM),
			"feed": room_cfg.get("feed", RoomSession.FEED_RANDOM),
			"start": room_cfg.get("start", 5),
			"every_moves": room_cfg.get("every_moves", 3),
			"target": 1_000_000_000,
		}
		var session := RoomSession.new(s, RoomSession.ArrivalMode.TURNS, items, cfg)
		session.start()
		var guard := 0
		while session.is_playing() and guard < 2000:
			guard += 1
			var move := Bots.choose_for(session.room)
			if move.is_empty() or not session.play(move):
				session.deliver()
		scores.append(session.room.score)
		lost_lives += session.max_lives - maxi(session.lives, 0)
		if session.room.score >= int(room_cfg["target"]):
			beat_target += 1
	scores.sort()
	print("%-16s items=%d  p10=%6d p50=%6d p75=%6d  target %5d beaten %3d%%  lives lost %.2f" % [
		key, n_items, _p(scores, 0.10), _p(scores, 0.50), _p(scores, 0.75),
		room_cfg["target"], 100 * beat_target / SEEDS, float(lost_lives) / SEEDS])


func _p(sorted_values: Array[int], q: float) -> int:
	return sorted_values[clampi(int(q * (sorted_values.size() - 1)), 0, sorted_values.size() - 1)]
