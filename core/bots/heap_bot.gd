class_name HeapBot
extends RefCounted
## The Heap Sort habit as a bot: while some parent is smaller than a child,
## lift the bigger child of the highest such parent; once the tree is a heap,
## pop the root.


## Next move, or {} when the whole column is ready.
static func choose(algorithm: HeapAlgorithm, board: Board) -> Dictionary:
	var h := algorithm.tree_size(board)
	if h < 1:
		return {}
	for p in h:
		var c := 2 * p + 1
		if c >= h:
			break
		if c + 1 < h and board.value_at(c + 1) > board.value_at(c):
			c += 1
		if board.value_at(c) > board.value_at(p):
			return {"type": Events.SIFT, "index": c}
	return {"type": Events.POP}
