class_name BubbleBot
extends RefCounted
## The Bubble Sort habit as a bot: carry the biggest element up, pair by pair.
## Used by the demo key in the room screen and by sim/ for balance numbers.


## Next move, or {} when there is nothing useful to do.
static func choose(board: Board) -> Dictionary:
	if board.size() < 2:
		return {}
	var best := board.max_value()
	# Highest copy of the maximum: its upper neighbour is strictly smaller,
	# so the swap is always a correct one.
	var i := board.size() - 1
	while i >= 0 and board.value_at(i) != best:
		i -= 1
	if i >= board.size() - 1:
		return {}
	return {"type": Events.SWAP, "index": i}
