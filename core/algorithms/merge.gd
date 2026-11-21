class_name MergeAlgorithm
extends Algorithm
## Merge Sort, bottom up (natural merge sort). The board is a row: index 0 is
## the exit. Past the numbers already in their final place at the exit, the
## row falls into runs: stretches that already go up (equal neighbours
## included). The only move merges a run with the next one into a single
## sorted run; it costs one comparison per number in the two runs, less one.
## Merging two short runs is cheap, feeding one long run a number at a time
## is not: the cost rewards balanced merges, as in the real algorithm.
## The leftmost number leaves when it is the smallest one on the board.
## Move: {"type": &"merge", "index": s}, s the first cell of the left run.


func _init() -> void:
	id = &"merge"
	display_name = "Merge"


## How many numbers at the exit are in their final place: each one is the
## smallest of everything after it (the run that would leave).
func placed_prefix(board: Board) -> int:
	var n := board.size()
	if n == 0:
		return 0
	var suffix_min: Array[int] = []
	suffix_min.resize(n + 1)
	suffix_min[n] = 1 << 30
	for i in range(n - 1, -1, -1):
		suffix_min[i] = mini(suffix_min[i + 1], board.value_at(i))
	var k := 0
	while k < n and board.value_at(k) == suffix_min[k]:
		k += 1
	return k


## The runs after the placed prefix, left to right, as [start, end).
func runs(board: Board) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var i := placed_prefix(board)
	var n := board.size()
	while i < n:
		var s := i
		i += 1
		while i < n and board.value_at(i - 1) <= board.value_at(i):
			i += 1
		out.append(Vector2i(s, i))
	return out


## The run starting at cell `s` and the one after it, or [] when `s` is not
## the start of a run that has a next one.
func pair_at(board: Board, s: int) -> Array[Vector2i]:
	var rs := runs(board)
	for k in range(rs.size() - 1):
		if rs[k].x == s:
			return [rs[k], rs[k + 1]]
	return []


func legal_moves(board: Board) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rs := runs(board)
	for k in range(rs.size() - 1):
		out.append({"type": Events.MERGE, "index": rs[k].x})
	return out


func is_legal(board: Board, move: Dictionary) -> bool:
	if move.get("type") != Events.MERGE:
		return false
	return not pair_at(board, int(move.get("index", -1))).is_empty()


func move_cost(board: Board, move: Dictionary) -> int:
	var pair := pair_at(board, int(move["index"]))
	return maxi(1, pair[1].y - pair[0].x - 1)


## How many times the merged row switches from one run to the other: what a
## merge costs when it can gallop through a stretch from one run.
func switches(board: Board, move: Dictionary) -> int:
	var order := _merged(board, pair_at(board, int(move["index"])))
	var count := 0
	for k in range(1, order.size()):
		if order[k][0] != order[k - 1][0]:
			count += 1
	return count


func apply(board: Board, move: Dictionary) -> void:
	var pair := pair_at(board, int(move["index"]))
	var order := _merged(board, pair)
	var k := pair[0].x
	for entry: Array in order:
		board.cells[k] = entry[1]
		k += 1


## The two runs merged, stable (the left run first on ties), as
## [[0 or 1 for the run it came from, element], ...].
func _merged(board: Board, pair: Array[Vector2i]) -> Array:
	var a := pair[0]
	var b := pair[1]
	var out := []
	var i := a.x
	var j := b.x
	while i < a.y or j < b.y:
		if j >= b.y or (i < a.y and board.value_at(i) <= board.value_at(j)):
			out.append([0, board.cells[i]])
			i += 1
		else:
			out.append([1, board.cells[j]])
			j += 1
	return out


func surface_index(_board: Board) -> int:
	return 0


func can_surface(board: Board) -> bool:
	return board.value_at(0) == board.min_value()


## Newcomers join on the right: a run of their own, or the end of the last run.
func arrive_index(board: Board) -> int:
	return board.size()


## Biggest first: three runs of one, and the smallest furthest from the exit.
func order_batch(values: Array[int]) -> Array[int]:
	var out: Array[int] = values.duplicate()
	out.sort()
	out.reverse()
	return out
