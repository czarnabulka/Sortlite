class_name TestCase
extends RefCounted
## Minimal test base. Methods whose names start with "test_" are run by
## tests/run_tests.gd; a test fails when any check in it fails.

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func bubble_room(values: Array, target := 1_000_000, budget := 100, capacity := -1,
		bus: EventBus = null, has_arrivals := false) -> Room:
	var cap := capacity if capacity > 0 else maxi(values.size(), 1)
	return Room.new(BubbleAlgorithm.new(), Board.new(cap, values), target, budget, bus, has_arrivals)


func pancake_room(values: Array, target := 1_000_000, budget := 100, capacity := -1,
		bus: EventBus = null, has_arrivals := false) -> Room:
	var cap := capacity if capacity > 0 else maxi(values.size(), 1)
	return Room.new(PancakeAlgorithm.new(), Board.new(cap, values), target, budget, bus, has_arrivals)


func quick_room(values: Array, target := 1_000_000, budget := 100, capacity := -1,
		bus: EventBus = null, has_arrivals := false) -> Room:
	var cap := capacity if capacity > 0 else maxi(values.size(), 1)
	return Room.new(QuickAlgorithm.new(), Board.new(cap, values), target, budget, bus, has_arrivals)


func insertion_room(values: Array, target := 1_000_000, budget := 100, capacity := -1,
		bus: EventBus = null, has_arrivals := false) -> Room:
	var cap := capacity if capacity > 0 else maxi(values.size(), 1)
	return Room.new(InsertionAlgorithm.new(), Board.new(cap, values), target, budget, bus, has_arrivals)
