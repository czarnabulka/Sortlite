class_name DataGen
extends RefCounted
## Starting data for a room. The distribution is part of the difficulty:
## Insertion loves nearly sorted data, Quick hates it.

const RANDOM := &"random"
const NEARLY := &"nearly"
const REVERSED := &"reversed"
const DUPES := &"dupes"


## Values in 1..vmax, ascending by index means sorted.
static func make_values(kind: StringName, n: int, vmax: int, rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	match kind:
		RANDOM:
			for i in n:
				out.append(rng.randi_range(1, vmax))
		NEARLY:
			out = _distinct_sorted(n, vmax, rng)
			# One or two neighbouring pairs out of place.
			for k in (1 if n < 6 else 2):
				var j := rng.randi_range(0, n - 2)
				var tmp := out[j]
				out[j] = out[j + 1]
				out[j + 1] = tmp
		REVERSED:
			out = _distinct_sorted(n, vmax, rng)
			out.reverse()
		DUPES:
			var hi := maxi(2, n / 2)
			for i in n:
				out.append(rng.randi_range(1, mini(hi, vmax)))
		_:
			push_error("DataGen: unknown kind '%s'" % kind)
	return out


## n distinct values when the range allows it, sorted ascending.
static func _distinct_sorted(n: int, vmax: int, rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	for v in range(1, vmax + 1):
		pool.append(v)
	var out: Array[int] = []
	for i in n:
		if pool.is_empty():
			out.append(rng.randi_range(1, vmax))
		else:
			out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	out.sort()
	return out
