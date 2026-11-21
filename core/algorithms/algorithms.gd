class_name Algorithms
extends RefCounted
## Algorithm ids and the factory that makes them.

const BUBBLE := &"bubble"
const INSERTION := &"insertion"
const PANCAKE := &"pancake"
const QUICK := &"quick"
const MERGE := &"merge"
const HEAP := &"heap"
const ALL: Array[StringName] = [BUBBLE, INSERTION, PANCAKE, QUICK, MERGE, HEAP]


static func make(id: StringName) -> Algorithm:
	match id:
		BUBBLE:
			return BubbleAlgorithm.new()
		INSERTION:
			return InsertionAlgorithm.new()
		PANCAKE:
			return PancakeAlgorithm.new()
		QUICK:
			return QuickAlgorithm.new()
		MERGE:
			return MergeAlgorithm.new()
		HEAP:
			return HeapAlgorithm.new()
	push_error("Algorithms: unknown id '%s'" % id)
	return BubbleAlgorithm.new()
