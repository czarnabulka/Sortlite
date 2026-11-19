class_name Algorithms
extends RefCounted
## Algorithm ids and the factory that makes them.

const BUBBLE := &"bubble"
const INSERTION := &"insertion"
const ALL: Array[StringName] = [BUBBLE, INSERTION]


static func make(id: StringName) -> Algorithm:
	match id:
		BUBBLE:
			return BubbleAlgorithm.new()
		INSERTION:
			return InsertionAlgorithm.new()
	push_error("Algorithms: unknown id '%s'" % id)
	return BubbleAlgorithm.new()
