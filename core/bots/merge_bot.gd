class_name MergeBot
extends RefCounted
## The Merge Sort habit as a bot: merge the two neighbouring runs that are
## shortest together (balanced merges are the cheap ones), nearest the exit
## on a tie.


## Next move, or {} when the row is one sorted run.
static func choose(algorithm: MergeAlgorithm, board: Board) -> Dictionary:
	var rs := algorithm.runs(board)
	var best := -1
	var best_len := 1 << 30
	for k in range(rs.size() - 1):
		var length := rs[k + 1].y - rs[k].x
		if length < best_len:
			best = k
			best_len = length
	if best < 0:
		return {}
	return {"type": Events.MERGE, "index": rs[best].x}
