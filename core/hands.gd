class_name Hands
extends RefCounted
## What a shipped run is worth, like a poker hand. The multiplier starts at
## the run's length and every pattern the whole run has adds to it, so the
## player chooses between shipping now (safe, small) and waiting for a longer
## or prettier run (risky: the board fills up and arrivals keep coming).
##
## Names are translation keys HAND_<PATTERN> in i18n/strings.csv.

const STRAIGHT := &"straight"  ## 3+ consecutive values: 4 5 6
const SAME := &"same"  ## 2+ equal values: 7 7
const EVEN := &"even"  ## 3+, all even
const ODD := &"odd"  ## 3+, all odd
const PRIME := &"prime"  ## 3+, all prime
const FIBONACCI := &"fibonacci"  ## 3+, all Fibonacci numbers
const POW2 := &"pow2"  ## 3+, all powers of two
const SQUARE := &"square"  ## 3+, all perfect squares

## Mult added per shipped element when the run has the pattern.
const BONUS_PER_ELEMENT := {
	STRAIGHT: 2, SAME: 2, EVEN: 1, ODD: 1, PRIME: 2, FIBONACCI: 2, POW2: 2, SQUARE: 2,
}


## {"mult": int, "patterns": Array[StringName]} for the values of one shipment.
static func evaluate(values: Array[int]) -> Dictionary:
	var n := values.size()
	var found: Array[StringName] = []
	if n >= 2 and _all(values, func(v: int) -> bool: return v == values[0]):
		found.append(SAME)
	elif n >= 3 and _consecutive(values):
		found.append(STRAIGHT)
	if n >= 3:
		if _all(values, func(v: int) -> bool: return NumberProps.is_prime(v)):
			found.append(PRIME)
		if _all(values, func(v: int) -> bool: return NumberProps.is_fibonacci(v)):
			found.append(FIBONACCI)
		if _all(values, func(v: int) -> bool: return NumberProps.is_pow2(v)):
			found.append(POW2)
		if _all(values, func(v: int) -> bool: return NumberProps.is_square(v)):
			found.append(SQUARE)
		if _all(values, func(v: int) -> bool: return v % 2 == 0):
			found.append(EVEN)
		elif _all(values, func(v: int) -> bool: return v % 2 != 0):
			found.append(ODD)
	var mult := n
	for p in found:
		mult += int(BONUS_PER_ELEMENT[p]) * n
	return {"mult": mult, "patterns": found}


## Score of shipping these elements before items: Σ points × hand mult.
static func base_score(elements: Array[Element]) -> int:
	var values: Array[int] = []
	var points := 0
	for e in elements:
		values.append(e.value)
		points += Room.element_points(e)
	return points * int(evaluate(values)["mult"])


static func _all(values: Array[int], pred: Callable) -> bool:
	for v in values:
		if not pred.call(v):
			return false
	return true


## Distinct values that, sorted, step by exactly 1.
static func _consecutive(values: Array[int]) -> bool:
	var s := values.duplicate()
	s.sort()
	for i in range(1, s.size()):
		if s[i] != s[i - 1] + 1:
			return false
	return true
