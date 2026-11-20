class_name QuickBot
extends RefCounted
## The Quick Sort habit as a bot: split the unsorted segment nearest the exit
## around its middle value (the cheapest pivot over the whole board).


## Next move, or {} when everything is in its place.
static func choose(algorithm: QuickAlgorithm, board: Board) -> Dictionary:
	var segs := algorithm.segments(board)
	if segs.is_empty():
		return {}
	var seg: Vector2i = segs[0]
	var values: Array[int] = []
	for i in range(seg.x, seg.y):
		values.append(board.value_at(i))
	values.sort()
	var middle := values[(values.size() - 1) / 2]
	for i in range(seg.x, seg.y):
		if board.value_at(i) == middle:
			return {"type": Events.PARTITION, "index": i}
	return {}
