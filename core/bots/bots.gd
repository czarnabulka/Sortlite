class_name Bots
extends RefCounted
## A perfect player for each algorithm (demo key, sim/, tests).


## The right move for the board, ignoring the budget.
static func choose(algorithm: Algorithm, board: Board) -> Dictionary:
	match algorithm.id:
		Algorithms.BUBBLE:
			return BubbleBot.choose(board)
		Algorithms.INSERTION:
			# The one right place for the key.
			for m in algorithm.legal_moves(board):
				if not algorithm.is_wrong(board, m):
					return m
	return {}


## What a sensible player does in a room: the right move if it can pay for it,
## otherwise the cheapest move it can still pay for, otherwise {} (wait).
static func choose_for(room: Room) -> Dictionary:
	var best := choose(room.algorithm, room.board)
	if not best.is_empty() and room.algorithm.move_cost(room.board, best) <= room.budget:
		return best
	var cheapest := {}
	var cheapest_cost := 1 << 30
	for m in room.affordable_moves():
		var c := room.algorithm.move_cost(room.board, m)
		if c < cheapest_cost:
			cheapest = m
			cheapest_cost = c
	return cheapest
