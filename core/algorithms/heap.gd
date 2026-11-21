class_name HeapAlgorithm
extends Algorithm
## Heap Sort, in place. The board is a column: index 0 is the bottom, the last
## index is the top, where the exit is. The numbers below the ready run at the
## exit form a binary tree stored in the array: the parent of cell i is cell
## (i - 1) / 2, so cell 0 is the root. In a max-heap every parent is at least
## as big as its children, and the root is the biggest number of the tree.
## Two moves, 1 each:
## - sift: a number trades places with its parent. Right when the child is
##   bigger than its parent and not smaller than its sibling.
## - pop: the root trades places with the last cell of the tree. When the root
##   was the tree's biggest it is popped: it joins the ready run at the exit
##   for good. Popping any other root is a wrong move and a wasted one.
## Newcomers join the tree under the ready run, so one bigger than the popped
## numbers does not undo them (as it would in Bubble): a heap only promises
## that each pop takes the biggest number of the tree at the time.
## Moves: {"type": &"sift", "index": i} (1 <= i < tree size), {"type": &"pop"}.


func _init() -> void:
	id = &"heap"
	display_name = "Heap"


static func parent(i: int) -> int:
	return (i - 1) / 2


## The popped numbers at the top: the ready run.
func ready_count(board: Board) -> int:
	var n := 0
	while n < board.size() and board.cells[board.size() - 1 - n].has_marker(Element.POPPED):
		n += 1
	return n


## How many cells, from the bottom, belong to the tree (the rest is ready).
func tree_size(board: Board) -> int:
	return board.size() - ready_count(board)


## True when every parent in the tree is at least as big as its children.
func is_heap(board: Board) -> bool:
	for i in range(1, tree_size(board)):
		if board.value_at(i) > board.value_at(parent(i)):
			return false
	return true


func legal_moves(board: Board) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var h := tree_size(board)
	if h >= 1:
		out.append({"type": Events.POP})
	for i in range(1, h):
		out.append({"type": Events.SIFT, "index": i})
	return out


func is_legal(board: Board, move: Dictionary) -> bool:
	var h := tree_size(board)
	match move.get("type"):
		Events.POP:
			return h >= 1
		Events.SIFT:
			var i: int = move.get("index", -1)
			return i >= 1 and i < h
	return false


func is_wrong(board: Board, move: Dictionary) -> bool:
	var h := tree_size(board)
	if move["type"] == Events.POP:
		return not _root_is_biggest(board)
	var i: int = move["index"]
	var v := board.value_at(i)
	if v <= board.value_at(parent(i)):
		return true
	var sibling := i + 1 if i % 2 == 1 else i - 1
	return sibling >= 1 and sibling < h and board.value_at(sibling) > v


func _root_is_biggest(board: Board) -> bool:
	for i in range(1, tree_size(board)):
		if board.value_at(i) > board.value_at(0):
			return false
	return true


func apply(board: Board, move: Dictionary) -> void:
	if move["type"] == Events.POP:
		if _root_is_biggest(board):
			board.cells[0].markers[Element.POPPED] = true
		board.swap(0, tree_size(board) - 1)
	else:
		var i: int = move["index"]
		board.swap(i, parent(i))


func surface_index(board: Board) -> int:
	return board.size() - 1


func can_surface(board: Board) -> bool:
	return board.cells[board.size() - 1].has_marker(Element.POPPED)


## Newcomers become the tree's next leaf, just under the ready run.
func arrive_index(board: Board) -> int:
	return tree_size(board)


## Smallest first: the smallest lands at the root, so the tree needs lifting.
func order_batch(values: Array[int]) -> Array[int]:
	var s: Array[int] = values.duplicate()
	s.sort()
	return s
