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
## With every slot full, taking a card first asks which item to drop:
## the card being taken (-1 = not asking) and the slot picked to drop.
## In the shop the card is one for sale.
var replacing := -1
var drop_slot := 0
## The slot the card being picked goes into (-1 = a free slot).
var pick_slot := -1

var _fade_state := 0  # 0 none, 1 going dark, 2 coming back
var _fade_t := 0.0
var _fade_then: Callable


func _ready() -> void:
	font = RoomView.load_pixel_font()
	demo = demo or OS.get_cmdline_user_args().has("--demo")
	room_view = RoomView.new()
	room_view.demo = demo
	room_view.help_open = OS.get_cmdline_user_args().has("--controls")
	room_view.continue_pressed.connect(func() -> void: _fade_to(_on_room_continue))
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


## Arrivals by moves or by time, from the settings: for this run and the room
## being played.
func set_arrival_mode(mode: RoomSession.ArrivalMode) -> void:
	run.mode = mode
	room_view.set_arrival_mode(mode)


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
	selected_card = 0
	replacing = -1
	if run.phase == Run.Phase.REWARD or run.phase == Run.Phase.SHOP:
		Sfx.play(&"deal")
	if run.phase == Run.Phase.ROOM:
		var algo: StringName = run.current_room()["algorithm"]
		var first_time := not seen_rules.has(algo)
		seen_rules[algo] = true
		var rooms := run.floor_rooms()
		room_view.set_session(run.session, run.cleared - rooms[0] + 1, rooms.size(), run.current_room()["kind"], run.bits,
				first_time, run.floor_no())
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
			Sfx.play(&"confirm")
			_fade_to(func() -> void: new_run(randi() % 100000))
		return
	# Reward phase or shop
	if replacing >= 0:
		_replace_input(event, local)
		return
	if run.phase == Run.Phase.SHOP:
		_shop_input(event, local)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_select_card(maxi(selected_card - 1, 0))
			KEY_RIGHT, KEY_D:
				_select_card(mini(selected_card + 1, _cards().size() - 1))
			KEY_SPACE, KEY_ENTER:
				_pick(selected_card)
			KEY_S:
				Sfx.play(&"skip")
				_fade_to(func() -> void:
					run.skip()
					_show_phase())
			KEY_R:
				if run.reroll():
					selected_card = 0
					screen_t = 0.15  # cards deal in again, map stays
					Sfx.play(&"deal")
				else:
					Sfx.play(&"wrong")
			KEY_E:
				Sfx.play(&"heal" if run.heal() else &"wrong")
	elif event is InputEventMouseMotion:
		var hover := _card_at(local)
		if hover >= 0:
			_select_card(hover)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _card_at(local)
		if i >= 0:
			_pick(i)


func _pick(i: int) -> void:
	if i < 0 or i >= run.offer.size():
		return
	selected_card = i
	if run.slots_full():
		# Every slot is taken: first choose which item this one replaces.
		replacing = i
		drop_slot = 0
		Sfx.play(&"card_open")
		return
	Sfx.play(&"take")
	picking = i
	pick_slot = -1
	pick_t = 0.0


## Choosing the item to drop: A D or the mouse pick it, SPACE or a click
## replaces it, Q or a right-click goes back to the cards.
func _replace_input(event: InputEvent, local: Vector2) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A, KEY_UP, KEY_W:
				_select_drop(drop_slot - 1)
			KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S:
				_select_drop(drop_slot + 1)
			KEY_SPACE, KEY_ENTER:
				_confirm_replace()
			KEY_Q, KEY_BACKSPACE:
				_cancel_replace()
	elif event is InputEventMouseMotion:
		var k := _slot_at(local)
		if k >= 0:
			_select_drop(k)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var k := _slot_at(local)
			if k >= 0:
				drop_slot = k
				_confirm_replace()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_replace()


## The shop: A D or the mouse choose a card, SPACE or a click buys it,
## E buys an extra shipment, R restocks, S leaves.
func _shop_input(event: InputEvent, local: Vector2) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_select_card(maxi(selected_card - 1, 0))
			KEY_RIGHT, KEY_D:
				_select_card(mini(selected_card + 1, _cards().size() - 1))
			KEY_SPACE, KEY_ENTER:
				_buy(selected_card)
			KEY_E:
				Sfx.play(&"take" if run.buy_ship() else &"wrong")
			KEY_R:
				if run.restock():
					screen_t = 0.15
					Sfx.play(&"deal")
				else:
					Sfx.play(&"wrong")
			KEY_S:
				Sfx.play(&"skip")
				_fade_to(func() -> void:
					run.leave_shop()
					_show_phase())
	elif event is InputEventMouseMotion:
		var hover := _card_at(local)
		if hover >= 0:
			_select_card(hover)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _card_at(local)
		if i >= 0:
			_buy(i)


func _buy(i: int) -> void:
	if i < 0 or i >= run.shop.size() or run.shop[i] == null or run.bits < Run.ITEM_PRICE:
		Sfx.play(&"wrong")
		return
	selected_card = i
	if run.slots_full():
		replacing = i
		drop_slot = 0
		Sfx.play(&"card_open")
		return
	if run.buy_item(i):
		Sfx.play(&"take")


func _select_drop(k: int) -> void:
	k = clampi(k, 0, run.items.size() - 1)
	if k != drop_slot:
		drop_slot = k
		Sfx.play(&"cursor")


func _confirm_replace() -> void:
	Sfx.play(&"take")
	if run.phase == Run.Phase.SHOP:
		run.buy_item(replacing, drop_slot)
		replacing = -1
		return
	picking = replacing
	pick_slot = drop_slot
	replacing = -1
	pick_t = 0.0


func _cancel_replace() -> void:
	replacing = -1
	Sfx.play(&"back")


## The owned items, two rows of three slots under the cards.
func _slot_rect(k: int) -> Rect2:
	var w := (608.0 - 2 * 10.0) / 3.0
	return Rect2(16 + (k % 3) * (w + 10.0), 272 + (k / 3) * 24.0, w, 20)


func _slot_at(p: Vector2) -> int:
	for k in run.items.size():
		if _slot_rect(k).has_point(p):
			return k
	return -1


func _select_card(i: int) -> void:
	if i != selected_card:
		selected_card = i
		Sfx.play(&"card_hover")


## The cards on screen: the item offer, or what the shop sells.
func _cards() -> Array[Item]:
	return run.shop if run.phase == Run.Phase.SHOP else run.offer


func _card_rect(i: int) -> Rect2:
	var n := _cards().size()
	var total := n * CARD_W + (n - 1) * 20.0
	var x0 := (640.0 - total) * 0.5
	return Rect2(x0 + i * (CARD_W + 20.0), CARD_Y, CARD_W, CARD_H)


func _card_at(p: Vector2) -> int:
	for i in _cards().size():
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
			var slot := pick_slot
			_fade_to(func() -> void:
				run.take(i, slot)
				_show_phase())

	for i in card_lift.size():
		var target := 6.0 if i == selected_card and (run.phase == Run.Phase.REWARD or run.phase == Run.Phase.SHOP) else 0.0
		card_lift[i] = lerpf(card_lift[i], target, 1.0 - exp(-14.0 * delta))

	if demo and not _busy():
		demo_timer += delta
		if demo_timer >= DEMO_PICK_SEC:
			demo_timer = 0.0
			if run.phase == Run.Phase.SHOP:
				_fade_to(func() -> void:
					run.leave_shop()
					_show_phase())
			elif run.phase == Run.Phase.REWARD:
				if run.slots_full():
					_fade_to(func() -> void:
						run.skip()
						_show_phase())
				else:
					_pick(0)
			elif run.phase == Run.Phase.ROOM and room_view.is_over() and room_view.end_t > 1.0:
				_fade_to(_on_room_continue)
			elif (run.phase == Run.Phase.WON or run.phase == Run.Phase.LOST) and screen_t > 5.0:
				# The demo keeps going: a new run after the end screen.
				_fade_to(func() -> void: new_run(randi() % 100000))
	if run.phase != Run.Phase.ROOM:
		queue_redraw()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if run.phase == Run.Phase.ROOM:
		return
	draw_rect(Rect2(0, 0, 640, 360), Palette.BG)
	var head := Anim.ease_out_cubic(screen_t / 0.3)
	_text("ROGUESORT", Vector2(16, 24), M, _a(Palette.GOLD, head))
	_text(tr("FLOOR_N") % run.floor_no(), Vector2(0, 24), M, _a(Palette.TEXT, head), HORIZONTAL_ALIGNMENT_CENTER, 640)
	_text("seed %d" % run.seed_value, Vector2(16, 24), S, _a(Palette.MUTED, head), HORIZONTAL_ALIGNMENT_RIGHT, 608)
	_draw_map(46)
	match run.phase:
		Run.Phase.REWARD, Run.Phase.SHOP:
			_draw_reward()
		Run.Phase.WON, Run.Phase.LOST:
			_draw_end()


## The current floor: one box per room, done ones dimmed, the next one
## outlined. Boxes drop in one after another.
func _draw_map(y: float) -> void:
	var rooms := run.floor_rooms()
	var n := rooms.size()
	var w := 128.0
	var gap := 22.0
	var x0 := (640.0 - (n * w + (n - 1) * gap)) * 0.5
	for k in n:
		var i: int = rooms[k]
		var p := Anim.stagger(screen_t, k, 0.06, 0.3)
		var a := p
		var room: Dictionary = run.plan[i]
		var r := Rect2(x0 + k * (w + gap), y - 16.0 * (1.0 - Anim.ease_out_cubic(p)), w, 42)
		if k > 0:
			draw_line(Vector2(r.position.x - gap, r.get_center().y), Vector2(r.position.x, r.get_center().y), _a(Palette.PANEL_EDGE, a), 1.0)
		var done := i < run.cleared
		var next := i == run.cleared and (run.phase == Run.Phase.REWARD or run.phase == Run.Phase.SHOP)
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
			Icons.draw_boss(self, Rect2(r.end.x - 8 - face, r.get_center().y - face * 0.5, face, face), a, room.get("boss", &"adversary"))


func _draw_reward() -> void:
	var title_a := Anim.ease_out_cubic((screen_t - 0.15) / 0.3)
	var shopping := run.phase == Run.Phase.SHOP
	if replacing >= 0:
		var taking := tr(_cards()[replacing].name_key)
		_text(tr("REPLACE_TITLE") % taking, Vector2(0, 108), M, _a(Palette.BAD.lightened(0.2), title_a), HORIZONTAL_ALIGNMENT_CENTER, 640)
	elif shopping:
		_text(tr("SHOP_TITLE"), Vector2(0, 108), M, _a(Palette.GOLD, title_a), HORIZONTAL_ALIGNMENT_CENTER, 640)
	elif run.slots_full():
		_text(tr("SLOTS_FULL"), Vector2(0, 108), M, _a(Palette.BAD.lightened(0.15), title_a), HORIZONTAL_ALIGNMENT_CENTER, 640)
	elif run.floor_starts():
		_text(tr("FLOOR_START") % run.floor_no(), Vector2(0, 108), M, _a(Palette.GOLD, title_a), HORIZONTAL_ALIGNMENT_CENTER, 640)
	elif run.current_room()["kind"] == Run.BOSS:
		# The last pick before the boss says so, in red.
		var pulse := 0.75 + 0.25 * sin(time * 4.0)
		_text(tr("NEXT_BOSS"), Vector2(0, 108), M, _a(Palette.BAD.lightened(0.15), title_a * pulse), HORIZONTAL_ALIGNMENT_CENTER, 640)
	else:
		_text(tr("CHOOSE_ITEM"), Vector2(0, 108), M, _a(Palette.TEXT, title_a), HORIZONTAL_ALIGNMENT_CENTER, 640)
	var pick_p := Anim.ease_out_cubic(pick_t / PICK_DUR) if picking >= 0 else 0.0
	var cards := _cards()
	for i in cards.size():
		var item := cards[i]
		var enter := Anim.stagger(screen_t, i, 0.08, 0.38)
		var a := Anim.clamp01(enter * 2.0)
		var r := _card_rect(i)
		r.position.y += 60.0 * (1.0 - Anim.ease_out_back(enter)) - card_lift[i]
		var sel := i == selected_card
		if replacing >= 0 and i != replacing:
			a *= 0.35  # the card being taken stays lit
		var s := 1.0
		if picking >= 0:
			if i == picking:
				r.position.y -= 18.0 * pick_p
				s = 1.0 + 0.06 * pick_p
			else:
				r.position.y += 50.0 * pick_p
				a *= 1.0 - pick_p
		draw_set_transform_matrix(Anim.around(r.get_center(), s))
		if item == null:
			# Sold: an empty frame where the card was.
			draw_rect(r, _a(Palette.PANEL_EDGE, a), false, 1.0)
			_text(tr("SHOP_SOLD"), Vector2(r.position.x, r.get_center().y + 6), M, _a(Palette.MUTED, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			continue
		var edge := Palette.GOLD if sel else Palette.PANEL_EDGE
		var fill := Palette.PANEL.lerp(Palette.GOLD, 0.06 + (0.2 * pick_p if i == picking else 0.0)) if sel else Palette.PANEL
		_panel(r, _a(edge, a), _a(fill, a))
		Icons.draw(self, item.id, Rect2(r.end.x - 42, r.position.y + 10, 32, 32), a)
		draw_multiline_string(font, Vector2(r.position.x + 10, r.position.y + 24), tr(item.name_key),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 62, M, 2, _a(Palette.GOLD if sel else Palette.TEXT, a))
		draw_multiline_string(font, Vector2(r.position.x + 10, r.position.y + 64), tr(item.desc_key),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, S, 4, _a(Palette.SOFT, a))
		if shopping:
			# The price on a tag at the card's foot, red when you cannot pay it.
			var afford := run.bits >= Run.ITEM_PRICE
			var tag := Rect2(r.end.x - 50, r.end.y - 10, 42, 20)
			var tc := Palette.GOLD if afford else Palette.BAD
			_panel(tag, _a(tc, a), _a(Palette.BG, a))
			Icons.draw_glyph(self, &"coin", Rect2(tag.position.x + 3, tag.position.y + 2, 16, 16), _a(tc, a))
			_text(str(Run.ITEM_PRICE), Vector2(tag.position.x + 22, tag.position.y + 15), S, _a(tc, a))
		draw_set_transform_matrix(Transform2D.IDENTITY)

	# What you already have (one box per slot), lives, bits and the keys fade
	# in last. While replacing, the item to drop is marked red.
	var b := Anim.ease_out_cubic((screen_t - 0.35) / 0.3)
	_text("%s %d/%d" % [tr("YOUR_ITEMS"), run.items.size(), Run.MAX_SLOTS], Vector2(16, 266), S, _a(Palette.SOFT, b))
	for k in Run.MAX_SLOTS:
		var r := _slot_rect(k)
		if k >= run.items.size():
			draw_rect(r, _a(Palette.PANEL_EDGE, b * 0.6), false, 1.0)  # a free slot
			continue
		var item := run.items[k]
		var dropping := replacing >= 0 and k == drop_slot
		var pulse := 0.6 + 0.4 * sin(time * 6.0) if dropping else 1.0
		_panel(r, _a(Palette.BAD if dropping else Palette.PANEL_EDGE, b * pulse),
				_a(Palette.PANEL.lerp(Palette.BAD, 0.18) if dropping else Palette.PANEL, b))
		Icons.draw(self, item.id, Rect2(r.position.x + 2, r.position.y + 2, 16, 16), b)
		_text(tr(item.name_key), Vector2(r.position.x + 24, r.position.y + 15), S,
				_a(Palette.BAD.lightened(0.35) if dropping else Palette.TEXT, b))
	var y := 336.0
	_text(tr("LIVES"), Vector2(16, y), S, _a(Palette.MUTED, b))
	for i in run.max_lives:
		var r := Rect2(62 + i * 18, y - 13, 16, 16)
		Icons.draw_glyph(self, &"heart" if i < run.lives else &"heart_empty", r,
				_a(Palette.BAD if i < run.lives else Palette.PANEL_EDGE.lightened(0.2), b))
	Icons.draw_glyph(self, &"coin", Rect2(130, y - 13, 16, 16), _a(Palette.GOLD, b))
	_text("%s %d" % [tr("BITS"), run.bits], Vector2(150, y), S, _a(Palette.GOLD, b))
	if run.bonus_ships > 0:
		_text(tr("SHOP_SHIP_BOUGHT") % run.bonus_ships, Vector2(240, y), S, _a(Palette.GOOD, b))
	var keys := tr("REWARD_KEYS") % [Run.SKIP_BITS, Run.REROLL_COST, Run.HEAL_COST]
	if replacing >= 0:
		keys = tr("REPLACE_KEYS")
	elif shopping:
		keys = tr("SHOP_KEYS") % [Run.SHIP_PRICE, Run.RESTOCK_COST]
	_text(keys, Vector2(16, y + 18), S, _a(Palette.TEXT, b))


func _draw_end() -> void:
	var won := run.phase == Run.Phase.WON
	var c := HORIZONTAL_ALIGNMENT_CENTER
	var title_s := 0.6 + 0.4 * Anim.ease_out_back((screen_t - 0.2) / 0.4)
	var title_a := Anim.clamp01((screen_t - 0.2) / 0.15)
	draw_set_transform_matrix(Anim.around(Vector2(320, 140), title_s))
	_text(tr("RUN_CLEARED") if won else tr("RUN_OVER"), Vector2(0, 150), L, _a(Palette.GOLD if won else Palette.BAD, title_a), c, 640)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var a1 := Anim.clamp01((screen_t - 0.5) / 0.3)
	if not won:
		var rooms := run.floor_rooms()
		_text(tr("ROOM_REACHED") % [run.floor_no(), run.cleared - rooms[0] + 1, rooms.size()], Vector2(0, 176), S, _a(Palette.SOFT, a1), c, 640)
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
