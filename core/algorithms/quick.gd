class_name QuickAlgorithm
extends Algorithm
## Quick Sort. The board is a row: index 0 is the exit. A number is in its
## final place when everything before it is smaller or equal and everything
## after it is bigger or equal. The numbers between such places form the
## unsorted segments. The only move picks a pivot in a segment: the segment
## splits around it (smaller before it, the rest after it, both keeping their
## order) and the pivot lands in its final place. It costs one comparison
## per other number in the segment. Nothing here is a wrong move: any pivot
## sorts, the choice is between cheap (a middle value) and quick to the exit
## (the smallest).
## The leftmost number leaves when it is the smallest one on the board.
## Move: {"type": &"partition", "index": p}, p any number not in its place.


func _init() -> void:
	id = &"quick"
	display_name = "Quick"


## True for every number already in its final place.
func placed(board: Board) -> Array[bool]:
	var n := board.size()
	var out: Array[bool] = []
	out.resize(n)
	var suffix_min: Array[int] = []
	suffix_min.resize(n + 1)
	suffix_min[n] = 1 << 30
	for i in range(n - 1, -1, -1):
		suffix_min[i] = mini(suffix_min[i + 1], board.value_at(i))
	var prefix_max := -(1 << 30)
	for i in n:
		var v := board.value_at(i)
		out[i] = prefix_max <= v and v <= suffix_min[i + 1]
		prefix_max = maxi(prefix_max, v)
	return out


## The unsorted segment holding index i, as [start, end), or [-1, -1] when
## the number at i is in its place.
func segment_of(board: Board, i: int) -> Vector2i:
	var done := placed(board)
	if i < 0 or i >= done.size() or done[i]:
		return Vector2i(-1, -1)
	var s := i
	while s > 0 and not done[s - 1]:
		s -= 1
	var e := i + 1
	while e < done.size() and not done[e]:
		e += 1
	return Vector2i(s, e)


## Every unsorted segment, left to right, as [start, end).
func segments(board: Board) -> Array[Vector2i]:
	var done := placed(board)
	var out: Array[Vector2i] = []
	var i := 0
	while i < done.size():
		if done[i]:
			i += 1
			continue
		var s := i
		while i < done.size() and not done[i]:
			i += 1
		out.append(Vector2i(s, i))
	return out


func legal_moves(board: Board) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var done := placed(board)
	for i in done.size():
		if not done[i]:
			out.append({"type": Events.PARTITION, "index": i})
	return out


func is_legal(board: Board, move: Dictionary) -> bool:
	if move.get("type") != Events.PARTITION:
		return false
	var i: int = move.get("index", -1)
	return segment_of(board, i).x >= 0


func move_cost(board: Board, move: Dictionary) -> int:
	var seg := segment_of(board, int(move["index"]))
	return maxi(1, seg.y - seg.x - 1)


func apply(board: Board, move: Dictionary) -> void:
	var p: int = move["index"]
	var seg := segment_of(board, p)
	var pivot := board.cells[p]
	var smaller: Array[Element] = []
	var rest: Array[Element] = []
	for i in range(seg.x, seg.y):
		if i == p:
			continue
		var e := board.cells[i]
		if e.value < pivot.value:
			smaller.append(e)
		else:
			rest.append(e)
	var k := seg.x
	for e in smaller + [pivot] + rest:
		board.cells[k] = e
		k += 1


func surface_index(_board: Board) -> int:
	return 0


func can_surface(board: Board) -> bool:
	return board.value_at(0) == board.min_value()


## Newcomers join on the right.
func arrive_index(board: Board) -> int:
	return board.size()


## Biggest first: the smallest arrives last, furthest from the exit.
func order_batch(values: Array[int]) -> Array[int]:
	var out: Array[int] = values.duplicate()
	out.sort()
	out.reverse()
	return out
