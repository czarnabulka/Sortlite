extends Node2D
## The whole run on screen: the item pick (with the floor map), each room
## (a RoomView child), and the end of the run. Drawn at 640×360.
## Screens change through a short fade, and everything on a screen enters
## with a small staggered animation, timed from `screen_t`.

const RoomView := preload("res://ui/room_view.gd")

const S := 16
const M := 20
const L := 32
const CARD_W := 180.0
const CARD_H := 132.0
const CARD_Y := 118.0
const DEMO_PICK_SEC := 1.2
const FADE_OUT := 0.16
const FADE_IN := 0.22
const PICK_DUR := 0.34


## Draws a dark veil over everything, for screen changes.
class Fader extends Node2D:
	var alpha := 0.0

	func _draw() -> void:
		if alpha > 0.0:
			draw_rect(Rect2(0, 0, 640, 360), Color(Palette.BG, alpha))


var run: Run
var room_view: RoomView
var fader: Fader
var font: Font
var selected_card := 0
var demo := false
var demo_timer := 0.0
var time := 0.0
var screen_t := 0.0
var card_lift: Array[float] = [0.0, 0.0, 0.0]
var picking := -1
var pick_t := 0.0
var seen_rules: Dictionary = {}  # algorithm id -> true, per run
var full_flash := 0.0

var _fade_state := 0  # 0 none, 1 going dark, 2 coming back
var _fade_t := 0.0
var _fade_then: Callable


func _ready() -> void:
	font = RoomView.load_pixel_font()
	demo = OS.get_cmdline_user_args().has("--demo")
	room_view = RoomView.new()
	room_view.demo = demo
	room_view.help_open = OS.get_cmdline_user_args().has("--controls")
	room_view.continue_pressed.connect(func() -> void: _fade_to(_on_room_continue))
	room_view.mode_changed.connect(func(m: RoomSession.ArrivalMode) -> void:
		run.mode = m
		Settings.save_arrival_mode(m))
	add_child(room_view)
	fader = Fader.new()
	fader.z_index = 100
	add_child(fader)
	# `-- --seed 123` replays a run.
	var args := OS.get_cmdline_user_args()
	var i := args.find("--seed")
	new_run(int(args[i + 1]) if i >= 0 and i + 1 < args.size() else randi() % 100000)
	# `-- --skip 3` jumps to that room (3 = the boss), for testing.
	var k := args.find("--skip")
	if k >= 0 and k + 1 < args.size():
		run.cleared = clampi(int(args[k + 1]), 0, run.plan.size() - 1)
		_show_phase()


func new_run(seed_value: int) -> void:
	run = Run.new(seed_value, Settings.load_arrival_mode(), not OS.get_cmdline_user_args().has("--classic"))
	seen_rules.clear()
	selected_card = 0
	_show_phase()


func _show_phase() -> void:
	screen_t = 0.0
	picking = -1
	card_lift = [0.0, 0.0, 0.0]
	room_view.visible = run.phase == Run.Phase.ROOM
	if run.phase == Run.Phase.ROOM:
		var algo: StringName = run.current_room()["algorithm"]
		var first_time := not seen_rules.has(algo)
		seen_rules[algo] = true
		room_view.set_session(run.session, run.cleared + 1, run.plan.size(), run.current_room()["kind"], run.bits, first_time)
	queue_redraw()


func _on_room_continue() -> void:
	run.finish_room()
	selected_card = 0
	_show_phase()


## Dims the screen, runs `then` (which changes the screen), and lightens again.
func _fade_to(then: Callable) -> void:
	if _fade_state != 0:
		return
	_fade_then = then
	_fade_state = 1
	_fade_t = 0.0


func _busy() -> bool:
	return _fade_state != 0 or picking >= 0


# --- input -------------------------------------------------------------------

func handle_input(event: InputEvent, local: Vector2) -> void:
	if _busy():
		return
	if run.phase == Run.Phase.ROOM:
		room_view.handle_input(event, local)
		return
	if run.phase == Run.Phase.WON or run.phase == Run.Phase.LOST:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			_fade_to(func() -> void: new_run(randi() % 100000))
		return
	# Reward phase
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				selected_card = maxi(selected_card - 1, 0)
			KEY_RIGHT, KEY_D:
				selected_card = mini(selected_card + 1, run.offer.size() - 1)
			KEY_SPACE, KEY_ENTER:
				_pick(selected_card)
			KEY_S:
				_fade_to(func() -> void:
					run.skip()
					_show_phase())
			KEY_R:
				if run.reroll():
					selected_card = 0
					screen_t = 0.15  # cards deal in again, map stays
			KEY_E:
				run.heal()
	elif event is InputEventMouseMotion:
		var hover := _card_at(local)
		if hover >= 0:
			selected_card = hover
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _card_at(local)
		if i >= 0:
			_pick(i)


func _pick(i: int) -> void:
	if i < 0 or i >= run.offer.size():
		return
	if run.slots_full():
		full_flash = 1.0  # the "slots full" line flashes; S skips instead
		return
	selected_card = i
	picking = i
	pick_t = 0.0


func _card_rect(i: int) -> Rect2:
	var total := run.offer.size() * CARD_W + (run.offer.size() - 1) * 20.0
	var x0 := (640.0 - total) * 0.5
	return Rect2(x0 + i * (CARD_W + 20.0), CARD_Y, CARD_W, CARD_H)


func _card_at(p: Vector2) -> int:
	for i in run.offer.size():
		if _card_rect(i).has_point(p):
			return i
	return -1


# --- update ------------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	screen_t += delta

	if _fade_state == 1:
		_fade_t += delta
		fader.alpha = Anim.ease_in_out(_fade_t / FADE_OUT)
		if _fade_t >= FADE_OUT:
			_fade_then.call()
			_fade_state = 2
			_fade_t = 0.0
	elif _fade_state == 2:
		_fade_t += delta
		fader.alpha = 1.0 - Anim.ease_in_out(_fade_t / FADE_IN)
		if _fade_t >= FADE_IN:
			_fade_state = 0
			fader.alpha = 0.0
	fader.queue_redraw()

	if picking >= 0:
		pick_t += delta
		if pick_t >= PICK_DUR and _fade_state == 0:
			var i := picking
			_fade_to(func() -> void:
				run.take(i)
				_show_phase())

	full_flash = maxf(full_flash - delta * 2.0, 0.0)
	for i in card_lift.size():
		var target := 6.0 if i == selected_card and run.phase == Run.Phase.REWARD else 0.0
		card_lift[i] = lerpf(card_lift[i], target, 1.0 - exp(-14.0 * delta))

	if demo and not _busy():
		demo_timer += delta
		if demo_timer >= DEMO_PICK_SEC:
			demo_timer = 0.0
			if run.phase == Run.Phase.REWARD:
				if run.slots_full():
					_fade_to(func() -> void:
						run.skip()
						_show_phase())
				else:
					_pick(0)
			elif run.phase == Run.Phase.ROOM and room_view.is_over() and room_view.end_t > 1.0:
				_fade_to(_on_room_continue)
	if run.phase != Run.Phase.ROOM:
		queue_redraw()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if run.phase == Run.Phase.ROOM:
		return
	draw_rect(Rect2(0, 0, 640, 360), Palette.BG)
	var head := Anim.ease_out_cubic(screen_t / 0.3)
	_text("ROGUESORT", Vector2(16, 24), M, _a(Palette.GOLD, head))
	_text("seed %d" % run.seed_value, Vector2(16, 24), S, _a(Palette.MUTED, head), HORIZONTAL_ALIGNMENT_RIGHT, 608)
	_draw_map(46)
	match run.phase:
		Run.Phase.REWARD:
			_draw_reward()
		Run.Phase.WON, Run.Phase.LOST:
			_draw_end()


## The floor: one box per room, done ones dimmed, the next one outlined.
## Boxes drop in one after another.
func _draw_map(y: float) -> void:
	var n := run.plan.size()
	var w := 128.0
	var gap := 22.0
	var x0 := (640.0 - (n * w + (n - 1) * gap)) * 0.5
	for i in n:
		var p := Anim.stagger(screen_t, i, 0.06, 0.3)
		var a := p
		var room: Dictionary = run.plan[i]
		var r := Rect2(x0 + i * (w + gap), y - 16.0 * (1.0 - Anim.ease_out_cubic(p)), w, 42)
		if i > 0:
			draw_line(Vector2(r.position.x - gap, r.get_center().y), Vector2(r.position.x, r.get_center().y), _a(Palette.PANEL_EDGE, a), 1.0)
		var done := i < run.cleared
		var next := i == run.cleared and run.phase == Run.Phase.REWARD
		var lost_here := i == run.cleared and run.phase == Run.Phase.LOST
		var edge := Palette.GOLD if next else (Palette.BAD if lost_here else Palette.PANEL_EDGE)
		if next:
			edge = edge.lerp(Palette.PANEL_EDGE, 0.35 + 0.35 * sin(time * 4.0))
		_panel(r, _a(edge, a), _a(Palette.PANEL if not done else Palette.BG, a))
		var kind: StringName = room["kind"]
		var kind_color := Palette.BAD if kind == Run.BOSS else (Palette.GOLD if next else Palette.TEXT)
		if done:
			kind_color = Palette.MUTED
		_text(tr("KIND_" + String(kind).to_upper()), Vector2(r.position.x + 8, r.position.y + 18), S, _a(kind_color, a))
		_text(tr("ALGO_" + String(room["algorithm"]).to_upper()), Vector2(r.position.x + 8, r.position.y + 35), S, _a(Palette.MUTED, a))
		if done and i < run.scores.size():
			_text(str(run.scores[i]), Vector2(r.position.x, r.position.y + 18), S, _a(Palette.GOOD, a), HORIZONTAL_ALIGNMENT_RIGHT, w - 8)
		elif kind == Run.BOSS:
			var face := 26.0 * (1.0 + (0.08 * sin(time * 5.0) if next else 0.0))
			Icons.draw_boss(self, Rect2(r.end.x - 8 - face, r.get_center().y - face * 0.5, face, face), a)


func _draw_reward() -> void:
	var title_a := Anim.ease_out_cubic((screen_t - 0.15) / 0.3)
	if run.slots_full():
		var c := Palette.BAD.lightened(0.15 + 0.4 * full_flash)
		_text(tr("SLOTS_FULL"), Vector2(0, 108), M, _a(c, title_a), HORIZONTAL_ALIGNMENT_CENTER, 640)
	elif run.current_room()["kind"] == Run.BOSS:
		# The last pick before the boss says so, in red.
		var pulse := 0.75 + 0.25 * sin(time * 4.0)
		_text(tr("NEXT_BOSS"), Vector2(0, 108), M, _a(Palette.BAD.lightened(0.15), title_a * pulse), HORIZONTAL_ALIGNMENT_CENTER, 640)
	else:
		_text(tr("CHOOSE_ITEM"), Vector2(0, 108), M, _a(Palette.TEXT, title_a), HORIZONTAL_ALIGNMENT_CENTER, 640)
	var pick_p := Anim.ease_out_cubic(pick_t / PICK_DUR) if picking >= 0 else 0.0
	for i in run.offer.size():
		var item := run.offer[i]
		var enter := Anim.stagger(screen_t, i, 0.08, 0.38)
		var a := Anim.clamp01(enter * 2.0)
		var r := _card_rect(i)
		r.position.y += 60.0 * (1.0 - Anim.ease_out_back(enter)) - card_lift[i]
		var sel := i == selected_card
		var s := 1.0
		if picking >= 0:
			if i == picking:
				r.position.y -= 18.0 * pick_p
				s = 1.0 + 0.06 * pick_p
			else:
				r.position.y += 50.0 * pick_p
				a *= 1.0 - pick_p
		draw_set_transform_matrix(Anim.around(r.get_center(), s))
		var edge := Palette.GOLD if sel else Palette.PANEL_EDGE
		var fill := Palette.PANEL.lerp(Palette.GOLD, 0.06 + (0.2 * pick_p if i == picking else 0.0)) if sel else Palette.PANEL
		_panel(r, _a(edge, a), _a(fill, a))
		Icons.draw(self, item.id, Rect2(r.end.x - 42, r.position.y + 10, 32, 32), a)
		draw_multiline_string(font, Vector2(r.position.x + 10, r.position.y + 24), tr(item.name_key),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 62, M, 2, _a(Palette.GOLD if sel else Palette.TEXT, a))
		draw_multiline_string(font, Vector2(r.position.x + 10, r.position.y + 64), tr(item.desc_key),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, S, 4, _a(Palette.SOFT, a))
		draw_set_transform_matrix(Transform2D.IDENTITY)

	# What you already have, lives, bits and the keys fade in last.
	var b := Anim.ease_out_cubic((screen_t - 0.35) / 0.3)
	var names: Array[String] = []
	for item in run.items:
		names.append(tr(item.name_key))
	var owned := ", ".join(names) if not names.is_empty() else tr("NO_ITEMS")
	draw_multiline_string(font, Vector2(16, 278), "%s %d/%d:  %s" % [tr("YOUR_ITEMS"), run.items.size(), Run.MAX_SLOTS, owned],
			HORIZONTAL_ALIGNMENT_LEFT, 608, S, 2, _a(Palette.SOFT, b))
	var y := 322.0
	_text(tr("LIVES"), Vector2(16, y), S, _a(Palette.MUTED, b))
	for i in run.max_lives:
		var r := Rect2(66 + i * 16, y - 11, 11, 11)
		if i < run.lives:
			draw_rect(r, _a(Palette.BAD, b))
		else:
			draw_rect(r, _a(Palette.PANEL_EDGE, b), false, 1.0)
	_text("%s %d" % [tr("BITS"), run.bits], Vector2(130, y), S, _a(Palette.GOLD, b))
	_text(tr("REWARD_KEYS") % [Run.SKIP_BITS, Run.REROLL_COST, Run.HEAL_COST], Vector2(16, y + 22), S, _a(Palette.TEXT, b))


func _draw_end() -> void:
	var won := run.phase == Run.Phase.WON
	var c := HORIZONTAL_ALIGNMENT_CENTER
	var title_s := 0.6 + 0.4 * Anim.ease_out_back((screen_t - 0.2) / 0.4)
	var title_a := Anim.clamp01((screen_t - 0.2) / 0.15)
	draw_set_transform_matrix(Anim.around(Vector2(320, 140), title_s))
	_text(tr("FLOOR_CLEARED") if won else tr("RUN_OVER"), Vector2(0, 150), L, _a(Palette.GOLD if won else Palette.BAD, title_a), c, 640)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var a1 := Anim.clamp01((screen_t - 0.5) / 0.3)
	if not won:
		_text(tr("ROOM_REACHED") % [run.cleared + 1, run.plan.size()], Vector2(0, 176), S, _a(Palette.SOFT, a1), c, 640)
	var total := 0
	for s in run.scores:
		total += s
	# The total counts up.
	var shown := int(total * Anim.ease_out_cubic((screen_t - 0.5) / 0.8))
	_text(tr("TOTAL_SCORE") % shown, Vector2(0, 210), M, _a(Palette.TEXT, a1), c, 640)
	var names: Array[String] = []
	for item in run.items:
		names.append(tr(item.name_key))
	draw_multiline_string(font, Vector2(60, 240), ", ".join(names), HORIZONTAL_ALIGNMENT_CENTER, 520, S, 2,
			_a(Palette.SOFT, Anim.clamp01((screen_t - 0.8) / 0.3)))
	var blink := 0.65 + 0.35 * sin(time * 3.0)
	_text(tr("NEW_RUN"), Vector2(0, 300), M, _a(Palette.GOLD, Anim.clamp01((screen_t - 1.1) / 0.3) * blink), c, 640)


# --- helpers -----------------------------------------------------------------

static func _a(color: Color, alpha: float) -> Color:
	return Color(color, color.a * Anim.clamp01(alpha))


func _text(s: String, pos: Vector2, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, pos, s, align, width, size, color)


func _panel(r: Rect2, edge := Palette.PANEL_EDGE, fill := Palette.PANEL) -> void:
	draw_rect(r, fill)
	draw_rect(r, edge, false, 1.0)
