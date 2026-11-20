class_name Room
extends RefCounted
## One room: a board, the algorithm whose moves are allowed, a move budget
## and a score target. Arrivals are pushed in from outside (by time or by
## turns; that choice is still open), so the room only reacts to them.

enum State { PLAYING, WON, LOST }

const BASE_POINTS := 10
## The chain part of the multiplier stops growing here (as in Bubble Sort Quest).
const CHAIN_CAP := 8

var board: Board
var algorithm: Algorithm
var bus: EventBus
var target: int
var budget: int
## With arrivals coming, running out of moves on a sorted board is not a loss.
var has_arrivals: bool
## Ship rooms: ready elements wait at the exit until the player ships them
## (a SHIP move), and the shipment scores as a hand (core/hands.gd). In
## classic rooms they leave by themselves as soon as they may.
var manual_ship := false
## Ship rooms: how many shipments are left (-1 = no limit). Like hands in a
## round of poker: shipping every number on its own uses them up, so the
## player has to wait for runs worth a shipment. At 0 the room is lost
## unless the target is already met.
var ships_left := -1
## The score cannot go past this (-1 = no cap). A boss's phase shield: one
## big shipment cannot skip a phase, the points over it are lost.
var score_cap := -1
## Points the cap stopped since the last BOSS_SHIELD event.
var _blocked := 0

var state := State.PLAYING
var score := 0
var moves_made := 0
var wrong_moves := 0
var surfaced := 0
var overflows := 0
var best_chain := 0


func _init(p_algorithm: Algorithm, p_board: Board, p_target: int, p_budget: int,
		p_bus: EventBus = null, p_has_arrivals := false) -> void:
	algorithm = p_algorithm
	board = p_board
	target = p_target
	budget = p_budget
	bus = p_bus if p_bus != null else EventBus.new()
	has_arrivals = p_has_arrivals


func start() -> void:
	bus.emit(Events.ROOM_START, {"room": self})
	_resolve()
	_check_end()


## Applies a player move. Returns false when the move is refused
## (room over, illegal move, or not enough budget); nothing changes then.
func play(move: Dictionary) -> bool:
	if state != State.PLAYING:
		return false
	var shipping: bool = move.get("type") == Events.SHIP
	if shipping:
		var n: int = move.get("count", 0)
		if not manual_ship or n < 1 or n > ready_count() or ships_left == 0:
			return false
	elif not algorithm.is_legal(board, move):
		return false
	var ctx := MoveContext.new(move, 1 if shipping else algorithm.move_cost(board, move),
			false if shipping else algorithm.is_wrong(board, move))
	bus.emit(Events.BEFORE_MOVE, {"room": self, "ctx": ctx})
	ctx.cost = maxi(ctx.cost, 0)
	if ctx.cost > budget:
		return false
	budget -= ctx.cost
	for ping in ctx.pings:
		bus.emit(Events.ITEM_TRIGGERED, {"room": self, "id": ping["id"], "label": ping["label"]})
	if shipping:
		_ship(int(move["count"]))
	else:
		algorithm.apply(board, move)
	moves_made += 1
	var data := {"room": self, "move": move, "cost": ctx.cost, "wrong": ctx.wrong}
	bus.emit(Events.MOVE, data)
	bus.emit(StringName(move.get("type", "")), data)
	if ctx.wrong:
		wrong_moves += 1
		bus.emit(Events.WRONG_MOVE, data)
	_resolve()
	_check_end()
	return true


## A new element enters. Returns false on overflow (the board was full);
## the session decides what an overflow costs (a life, by the design doc).
func arrive(value: int) -> bool:
	return arrive_batch([value]) == 0


## Several elements enter one after another, and only then does anything
## surface (so a batch into an empty board does not score for free).
## Returns how many did not fit and were not absorbed by an item.
func arrive_batch(values: Array[int]) -> int:
	if state != State.PLAYING:
		return values.size()
	var overflowed := 0
	for value in values:
		if board.is_full():
			overflows += 1
			# A handler may set data["absorbed"] = true (the Fuse item).
			var data := {"room": self, "value": value, "absorbed": false}
			bus.emit(Events.OVERFLOW, data)
			if not data["absorbed"]:
				overflowed += 1
			continue
		var e := board.make(value)
		board.insert_at(algorithm.arrive_index(board), e)
		bus.emit(Events.ARRIVE, {"room": self, "element": e})
	_resolve()
	_check_end()
	return overflowed


## Something outside a move changed the board (a boss strike): let elements
## surface and check whether the room is over.
func refresh() -> void:
	if state != State.PLAYING:
		return
	_resolve()
	_check_end()


## Ends the room as lost (out of lives, or the player gives up).
func fail() -> void:
	if state == State.PLAYING:
		_finish(State.LOST)


func affordable_moves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in algorithm.legal_moves(board):
		if algorithm.move_cost(board, m) <= budget:
			out.append(m)
	if manual_ship and budget >= 1 and ships_left != 0:
		for n in range(1, ready_count() + 1):
			out.append({"type": Events.SHIP, "count": n})
	return out


## How many elements at the exit are in their final place (ship rooms keep
## them there until shipped; classic rooms have 0 between moves).
func ready_count() -> int:
	return algorithm.ready_count(board)


## Points an element brings before any multiplier.
static func element_points(e: Element) -> int:
	var base := e.value * BASE_POINTS
	if e.has_marker(Element.CURSED):
		base = int(base / 2.0)
	return base


## The `count` elements nearest the exit, in the order they leave.
func ship_preview(count: int) -> Array[Element]:
	var copy := Board.new(board.capacity)
	copy.cells = board.cells.duplicate()
	var out: Array[Element] = []
	for i in mini(count, ready_count()):
		out.append(copy.remove_at(algorithm.surface_index(copy)))
	return out


## Surfaces every element that may leave, one after another. Each one in the
## same sequence is the next link of a chain.
func _resolve() -> void:
	if manual_ship:
		return
	var chain := 0
	while not board.is_empty() and algorithm.can_surface(board):
		chain += 1
		_score(board.remove_at(algorithm.surface_index(board)), chain, mini(chain, CHAIN_CAP))
	best_chain = maxi(best_chain, chain)
	if chain >= 2:
		bus.emit(Events.CHAIN, {"room": self, "length": chain})
	_report_blocked()


## Sends the `count` ready elements nearest the exit out as one hand: each
## scores its points × the hand's mult (plus items). Also counts as a chain.
func _ship(count: int) -> void:
	var leaving := ship_preview(count)
	var values: Array[int] = []
	for e in leaving:
		values.append(e.value)
	var hand := Hands.evaluate(values)
	if ships_left > 0:
		ships_left -= 1
	bus.emit(Events.HAND, {"room": self, "count": count, "values": values,
			"mult": hand["mult"], "patterns": hand["patterns"]})
	for i in leaving.size():
		board.remove_at(algorithm.surface_index(board))
		_score(leaving[i], i + 1, int(hand["mult"]))
	best_chain = maxi(best_chain, count)
	if count >= 2:
		bus.emit(Events.CHAIN, {"room": self, "length": count})
	_report_blocked()


func _report_blocked() -> void:
	if _blocked > 0:
		bus.emit(Events.BOSS_SHIELD, {"room": self, "blocked": _blocked})
		_blocked = 0


func _score(e: Element, chain: int, mult: int) -> void:
	var ctx := ScoreContext.new(e, chain, element_points(e), mult)
	bus.emit(Events.SURFACE, {"room": self, "ctx": ctx})
	var gained := ctx.total()
	if score_cap >= 0 and score + gained > score_cap:
		var kept := maxi(score_cap - score, 0)
		_blocked += gained - kept
		gained = kept
	score += gained
	surfaced += 1
	bus.emit(Events.SCORED, {"room": self, "ctx": ctx, "gained": gained})


func _check_end() -> void:
	if state != State.PLAYING:
		return
	if score >= target:
		_finish(State.WON)
	elif budget <= 0 or (manual_ship and ships_left == 0):
		_finish(State.LOST)
	elif affordable_moves().is_empty():
		# Moves exist but none is affordable: waiting for arrivals would only
		# overflow the board, so the room is over. A board with no moves at all
		# (sorted, waiting for newcomers) may keep going when arrivals come.
		if not has_arrivals or not algorithm.legal_moves(board).is_empty():
			_finish(State.LOST)


func _finish(new_state: State) -> void:
	state = new_state
	bus.emit(Events.ROOM_END, {"room": self, "won": new_state == State.WON})
