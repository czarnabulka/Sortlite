class_name Bots
extends RefCounted
## Players for every algorithm (demo key, sim/, tests).
##
## Sorting is always perfect. In ship rooms the bots differ in when they ship:
## GREEDY ships whatever is ready at once (what a player who only sorts does),
## SMART lets runs grow and ships the best part of them when it has to. The gap
## between the two is how much the ship decision matters (sim/sim_rooms.gd).

const GREEDY := &"greedy"
const SMART := &"smart"
## SMART ships a plain run (no pattern) once it is this long.
const SMART_BANK_AT := 4


## The right sorting move for the board, ignoring the budget. `ready` elements
## at the exit are already in place and are left alone.
static func choose(algorithm: Algorithm, board: Board, ready := 0) -> Dictionary:
	match algorithm.id:
		Algorithms.BUBBLE:
			return BubbleBot.choose(board, ready)
		Algorithms.INSERTION:
			# The one right place for the key.
			for m in algorithm.legal_moves(board):
				if not algorithm.is_wrong(board, m):
					return m
	return {}


## What a sensible player does in a room: the right move if it can pay for it,
## otherwise the cheapest move it can still pay for, otherwise {} (wait).
static func choose_for(room: Room) -> Dictionary:
	var best := choose(room.algorithm, room.board, room.ready_count())
	if not best.is_empty() and room.algorithm.move_cost(room.board, best) <= room.budget:
		return best
	var cheapest := {}
	var cheapest_cost := 1 << 30
	for m in room.affordable_moves():
		if m.get("type") == Events.SHIP:
			continue
		var c := room.algorithm.move_cost(room.board, m)
		if c < cheapest_cost:
			cheapest = m
			cheapest_cost = c
	return cheapest


## The next move in a session, or {} to wait for (or let in) the next arrival.
static func choose_in(session: RoomSession, policy := SMART) -> Dictionary:
	var room := session.room
	if not room.manual_ship:
		return choose_for(room)
	var ready := room.ready_count()
	if policy == GREEDY:
		return {"type": Events.SHIP, "count": ready} if ready > 0 else choose_for(room)
	return _smart(session, ready)


static func _smart(session: RoomSession, ready: int) -> Dictionary:
	var room := session.room
	var sort := choose_for(room)
	if ready == 0:
		return sort
	var best := _best_shipment(room, ready)
	var ship := {"type": Events.SHIP, "count": best["count"]}
	var board := room.board
	var free := board.capacity - board.size()
	# Ship when it wins the room, when it is the last move we can pay for,
	# before an arrival would overflow, when the boss is about to break the run,
	# or when there is nothing left to sort and no room to wait.
	if room.score + int(best["score"]) >= room.target:
		return ship
	if room.budget <= 1:
		return ship
	if free <= 1:
		return ship
	if session.is_aiming_pair() and _aimed_in_run(session, ready):
		return ship
	if sort.is_empty():
		return ship if free == 0 else {}
	# Bank a run with a pattern before it breaks, or a long one anyway.
	if not (best["patterns"] as Array).is_empty() or int(best["count"]) >= SMART_BANK_AT:
		return ship
	return sort


## The prefix of the ready run (from the exit) that scores most on its own.
static func _best_shipment(room: Room, ready: int) -> Dictionary:
	var best := {"count": ready, "score": -1, "patterns": []}
	var leaving := room.ship_preview(ready)
	for n in range(1, ready + 1):
		var part: Array[Element] = leaving.slice(0, n)
		var score := Hands.base_score(part)
		if score >= int(best["score"]):
			var values: Array[int] = []
			for e in part:
				values.append(e.value)
			best = {"count": n, "score": score, "patterns": Hands.evaluate(values)["patterns"]}
	return best


static func _aimed_in_run(session: RoomSession, ready: int) -> bool:
	for e in session.room.ship_preview(ready):
		if e.uid in session.strike_uids:
			return true
	return false
