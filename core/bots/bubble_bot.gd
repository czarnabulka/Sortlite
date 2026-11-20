class_name BubbleBot
extends RefCounted
## The Bubble Sort habit as a bot: carry the biggest element up, pair by pair.
## Used by the demo key in the room screen and by sim/ for balance numbers.


## Next move, or {} when there is nothing useful to do. The top `ready`
## elements are already in place (a ship room keeps them until shipped).
static func choose(board: Board, ready := 0) -> Dictionary:
	var free := board.size() - ready
	if free < 2:
		return {}
	var best := board.value_at(0)
	for i in free:
		best = maxi(best, board.value_at(i))
	# Highest copy of the maximum below the ready part: its upper neighbour is
	# strictly smaller, so the swap is always a correct one.
	var i := free - 1
	while i >= 0 and board.value_at(i) != best:
		i -= 1
	if i >= free - 1:
		return {}
	return {"type": Events.SWAP, "index": i}
