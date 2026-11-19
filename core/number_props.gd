class_name NumberProps
extends RefCounted
## Properties of numbers that items can build on (our "card suits").

const EVEN := &"even"
const ODD := &"odd"
const PRIME := &"prime"
const POW2 := &"pow2"
const FIBONACCI := &"fibonacci"
const SQUARE := &"square"


static func is_prime(n: int) -> bool:
	if n < 2:
		return false
	if n % 2 == 0:
		return n == 2
	var d := 3
	while d * d <= n:
		if n % d == 0:
			return false
		d += 2
	return true


static func is_pow2(n: int) -> bool:
	return n > 0 and (n & (n - 1)) == 0


static func is_square(n: int) -> bool:
	if n < 0:
		return false
	var r := int(sqrt(float(n)))
	for c in [r - 1, r, r + 1]:
		if c >= 0 and c * c == n:
			return true
	return false


## n is Fibonacci iff 5n² + 4 or 5n² − 4 is a perfect square.
static func is_fibonacci(n: int) -> bool:
	if n < 0:
		return false
	return is_square(5 * n * n + 4) or is_square(5 * n * n - 4)


static func props_of(n: int) -> Array[StringName]:
	var out: Array[StringName] = [EVEN if n % 2 == 0 else ODD]
	if is_prime(n):
		out.append(PRIME)
	if is_pow2(n):
		out.append(POW2)
	if is_fibonacci(n):
		out.append(FIBONACCI)
	if is_square(n):
		out.append(SQUARE)
	return out
