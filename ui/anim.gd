class_name Anim
extends RefCounted
## Easing and small helpers shared by the screens. Every animation is a time
## since something started, turned into 0..1 and eased.


static func clamp01(x: float) -> float:
	return clampf(x, 0.0, 1.0)


static func ease_in_out(p: float) -> float:
	p = clamp01(p)
	return p * p * (3.0 - 2.0 * p)


static func ease_out_cubic(p: float) -> float:
	p = clamp01(p)
	return 1.0 - pow(1.0 - p, 3.0)


## Overshoots a little, then settles: for things that pop in.
static func ease_out_back(p: float) -> float:
	p = clamp01(p)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(p - 1.0, 3.0) + c1 * pow(p - 1.0, 2.0)


## Progress of item `i` in a row that starts one after another.
static func stagger(t: float, i: int, step: float, dur: float) -> float:
	return clamp01((t - i * step) / dur)


## A transform that scales by `s` around `center` (for draw_set_transform_matrix).
static func around(center: Vector2, s: float) -> Transform2D:
	return Transform2D(0.0, Vector2(s, s), 0.0, center - center * s)


## Scale for a card or overlay popping in over `dur` seconds.
static func pop_scale(t: float, dur := 0.28) -> float:
	return 0.82 + 0.18 * ease_out_back(t / dur)
