class_name PancakeBot
extends RefCounted
## The Pancake Sort habit as a bot: flip the biggest number to the top, then
## flip it down onto the sorted bottom. With burnt sides it first turns a
## clean top number over, so the flip down lands it clean side up.


## Next move, or {} when there is nothing useful to do. The bottom `ready`
## elements are already in place (a ship room keeps them until shipped).
static func choose(algorithm: PancakeAlgorithm, board: Board, ready := 0) -> Dictionary:
	var n := board.size()
	if n - ready < 2:
		# One number left: with sides, turn it clean side up if it is burnt.
		if algorithm.burnt_sides and n - ready == 1 and board.cells[n - 1].has_marker(Element.BURNT):
			return _flip(n - 1)
		return {}
	var best := board.value_at(ready)
	for i in range(ready, n):
		best = maxi(best, board.value_at(i))
	# Highest copy of the biggest unsorted number.
	var m := n - 1
	while board.value_at(m) != best:
		m -= 1
	if m < n - 1:
		return _flip(m)
	if algorithm.burnt_sides and not board.cells[m].has_marker(Element.BURNT):
		return _flip(m)
	return _flip(ready)


static func _flip(i: int) -> Dictionary:
	return {"type": Events.FLIP, "index": i}
