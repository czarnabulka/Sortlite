class_name Board
extends RefCounted
## An array of elements with a capacity. It knows nothing about rules: the
## algorithm decides which moves are allowed and where the exit is.

var capacity: int
var cells: Array[Element] = []

var _next_uid := 1


func _init(p_capacity: int, start_values: Array = []) -> void:
	capacity = p_capacity
	for v in start_values:
		cells.append(make(int(v)))


func make(v: int) -> Element:
	var e := Element.new(v, _next_uid)
	_next_uid += 1
	return e


func size() -> int:
	return cells.size()


func is_empty() -> bool:
	return cells.is_empty()


func is_full() -> bool:
	return cells.size() >= capacity


func value_at(i: int) -> int:
	return cells[i].value


func values() -> Array[int]:
	var out: Array[int] = []
	for e in cells:
		out.append(e.value)
	return out


func max_value() -> int:
	var best := cells[0].value
	for e in cells:
		best = maxi(best, e.value)
	return best


func min_value() -> int:
	var best := cells[0].value
	for e in cells:
		best = mini(best, e.value)
	return best


func swap(i: int, j: int) -> void:
	var tmp := cells[i]
	cells[i] = cells[j]
	cells[j] = tmp


## Takes the element at `from` out and puts it back at `to`.
func move_element(from: int, to: int) -> void:
	var e: Element = cells.pop_at(from)
	cells.insert(to, e)


func insert_at(i: int, e: Element) -> void:
	cells.insert(i, e)


func remove_at(i: int) -> Element:
	return cells.pop_at(i)


## Pairs (i < j) with cells[i] > cells[j]: how far the board is from ascending order.
func inversions() -> int:
	var count := 0
	for i in cells.size():
		for j in range(i + 1, cells.size()):
			if cells[i].value > cells[j].value:
				count += 1
	return count


## Length of the longest non-decreasing run starting at index 0.
func sorted_prefix_length() -> int:
	if cells.is_empty():
		return 0
	var k := 1
	while k < cells.size() and cells[k - 1].value <= cells[k].value:
		k += 1
	return k


func _to_string() -> String:
	return str(values())
