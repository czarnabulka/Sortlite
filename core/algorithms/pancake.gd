class_name PancakeAlgorithm
extends Algorithm
## Pancake Sort. The board is a stack: index 0 is the bottom (the plate, where
## the exit is), the last index is the top. The only move slides the spatula
## under a number and flips it over together with everything above it.
## The bottom number leaves when it is the biggest one on the board.
## Move: {"type": &"flip", "index": i} reverses cells i..top.

## The Burnt Stack boss: every number has a burnt side and a flip turns each
## flipped number over (the burnt pancake problem). Flipping the top number
## alone is then a move too: it turns just that one over.
var burnt_sides := false


func _init() -> void:
	id = &"pancake"
	display_name = "Pancake"


## The lowest index the spatula can go under: flipping the top number alone
## changes nothing unless numbers have sides.
func _top_flip(board: Board) -> int:
	return board.size() - (1 if burnt_sides else 2)


func legal_moves(board: Board) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(_top_flip(board) + 1):
		out.append({"type": Events.FLIP, "index": i})
	return out


func is_legal(board: Board, move: Dictionary) -> bool:
	if move.get("type") != Events.FLIP:
		return false
	var i: int = move.get("index", -1)
	return i >= 0 and i <= _top_flip(board)


## Pancake Sort never flips the bottom that is already in its final place:
## that undoes work. Turning over a clean top number alone is wrong too.
func is_wrong(board: Board, move: Dictionary) -> bool:
	var i: int = move["index"]
	if i < ready_count(board):
		return true
	return i == board.size() - 1 and not board.cells[i].has_marker(Element.BURNT)


func apply(board: Board, move: Dictionary) -> void:
	var i: int = move["index"]
	var j := board.size() - 1
	if burnt_sides:
		for k in range(i, j + 1):
			board.cells[k].turn_over()
	while i < j:
		board.swap(i, j)
		i += 1
		j -= 1


func surface_index(_board: Board) -> int:
	return 0


func can_surface(board: Board) -> bool:
	return board.value_at(0) == board.max_value()


## Newcomers are dropped on top of the stack.
func arrive_index(board: Board) -> int:
	return board.size()


## Middle, biggest, smallest from the bottom: the order of three that needs
## the most flips (three), so a refill is not sorted by a single flip.
func order_batch(values: Array[int]) -> Array[int]:
	var s: Array[int] = values.duplicate()
	s.sort()
	if s.size() < 3:
		return s
	var out: Array[int] = [s[1], s.back()]
	for k in range(2, s.size() - 1):
		out.append(s[k])
	out.append(s[0])
	return out
