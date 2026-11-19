extends SceneTree
## Balance numbers for one Bubble room: the bot plays many seeds until the
## move budget runs out, and we look at the score it reaches.
##   godot --headless --path . -s res://sim/sim_rooms.gd
## TIME mode assumes the player makes one move per `SECONDS_PER_MOVE`.

const SEEDS := 400
const SECONDS_PER_MOVE := 1.2


func _initialize() -> void:
	for mode in [RoomSession.ArrivalMode.TURNS, RoomSession.ArrivalMode.TIME]:
		for with_items in [false, true]:
			_report(mode, with_items)
	quit()


func _report(mode: RoomSession.ArrivalMode, with_items: bool) -> void:
	var scores: Array[int] = []
	var overflow_losses := 0
	var chains: Array[int] = []
	for s in SEEDS:
		var items: Array[Item] = []
		if with_items:
			items = [ItemCatalog.sieve(), ItemCatalog.bubble_pump()]
		var session := RoomSession.new(s, mode, items, {"target": 1_000_000_000})
		session.start()
		var guard := 0
		while session.is_playing() and guard < 1000:
			guard += 1
			if mode == RoomSession.ArrivalMode.TIME:
				session.update(SECONDS_PER_MOVE)
				if not session.is_playing():
					break
			var move := BubbleBot.choose(session.room.board)
			if move.is_empty():
				session.deliver()
			elif not session.play(move):
				break
		scores.append(session.room.score)
		chains.append(session.room.best_chain)
		if session.lives <= 0:
			overflow_losses += 1
	scores.sort()
	chains.sort()
	print("%-5s items=%-5s  score p10=%5d p25=%5d p50=%5d p75=%5d p90=%5d  best chain p50=%d  lost by overflow %d/%d" % [
		"TURNS" if mode == RoomSession.ArrivalMode.TURNS else "TIME", str(with_items),
		_p(scores, 0.10), _p(scores, 0.25), _p(scores, 0.50), _p(scores, 0.75), _p(scores, 0.90),
		_p(chains, 0.5), overflow_losses, SEEDS])


func _p(sorted_values: Array[int], q: float) -> int:
	return sorted_values[clampi(int(q * (sorted_values.size() - 1)), 0, sorted_values.size() - 1)]
