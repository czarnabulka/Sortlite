# Roguesort (working title)

A puzzle roguelite about sorting, grown out of *Bubble Sort Quest*.
You put numbers in order with the moves of real algorithms, and items combine
into synergies like in Isaac and multiply your score like in Balatro.

Design document: https://claude.ai/artifact/5ETaojyCo7PVF7KUTtAXea

Engine: **Godot 4.7**, GDScript.

## How to play

Open the folder in Godot and press F5, or from the command line:

```bash
godot --path .
```

`godot --path . -- --demo` starts with the bot turned on, `-- --lang pl`
picks the language for a single launch, `-- --seed 123` replays a run, and
`-- --classic` plays the old rooms where sorted numbers leave by themselves.

## Languages

The game is in English by default, with Polish as an option (L key). The
language, the CRT effect and the inflow mode are saved in
`user://settings.cfg`. All text lives in
[i18n/strings.csv](i18n/strings.csv): a `keys` column, then `en` and `pl`.
New text in the game = a new row there and `tr("KEY")` in the code; the
`tests/test_i18n.gd` test makes sure every key has both languages and that the
font has every character. After changing the CSV, run `--import` once.

Font: Jersey 10 (OFL), always crisp; text only at 16, 20 and 32 px
(`S`, `M`, `L` in `ui/room_view.gd`), because smaller sizes lose letters.

| Key | Action |
|-----|--------|
| W / S, arrows, mouse wheel | pick a pair (Bubble) or a spot for the key (Insertion) |
| SPACE, click the selection | swap / insert |
| F | let the next element in now |
| E | ship the ready run (ship rooms) |
| Q / right-click | ship fewer / ship up to the clicked number |
| I | room rules card (shows up by itself in the first room of each algorithm) |
| A / D, click | pick an item between rooms; SPACE takes it |
| S / R / E | between rooms: skip (+bits), reroll the offer, heal a life |
| M | inflow: every N moves or every 6 s (remembered) |
| D | demo: the bot plays by itself |
| R | new run (on the end screen) |
| C | CRT effect on / off (remembered) |
| L | language: English / polski (remembered) |
| H | controls card |
| F11 | fullscreen |
| ESC | quit |

## Status: stage 4 (ship rooms)

### Ship rooms: you decide when sorted numbers leave

Sorting alone was trivial: every move had one obvious right answer, and doing
it also scored. Now sorted numbers at the exit **do not leave by themselves**.
They glow green (the *ready run*) and wait until you **ship** them with E,
which costs 1 move. A shipment scores like a poker hand
([core/hands.gd](core/hands.gd)): every number scores `value × 10 × mult`,
where the mult is the shipment's length plus a bonus per number for each
pattern the whole shipment has.

| Pattern | Example | Bonus per number |
|---------|---------|------------------|
| straight (3+ consecutive) | 4 5 6 | +2 |
| match (2+ equal) | 7 7 | +2 |
| all prime / Fibonacci / powers of 2 / squares (3+) | 2 3 5 | +2 each |
| all even / all odd (3+) | 2 6 8 | +1 |

So 4 5 6 shipped together score ×9, while 3 7 9 score only ×6 (odd), and
shipping each number on its own scores ×1. Q (or a right-click) ships only part
of the run, from the exit: from a ready 3 7 8 9, ship 7 8 9 as a straight and
keep the 3. The tension: waiting builds a bigger, prettier hand, but the run
takes up room in the column, newcomers keep arriving, an overflow costs a
life, and the boss swaps the sorted pair nearest the exit. Ship rooms get no
free batch of three when the board empties, and they have their own
arrival pace and targets (`ship_cfg` in `Run.ROOMS`).

`-- --classic` brings back the old rules for comparison.

### The floor

A run is one floor with 4 rooms: a Bubble fight and an Insertion fight (in
random order), an elite on reversed data, and the boss **The Adversary**,
which always adds the worst possible element. Before each room you pick 1 of 3
items (max 5, order = order of activation; with every slot full you can only
skip). Items that work in one algorithm only (Binary Search, Express Lane)
are offered only while a room of that algorithm is still ahead. Lives carry over between rooms.
Each room pays bits (+1 for every 5 unspent moves): 2 bits reroll the offer,
5 heal a life, and skipping an item gives 3.

- `core/run.gd`: floor plan (the `ROOMS` table), rewards, bits, lives.
- `core/items/catalog.gd`: 11 items, including Sieve of Eratosthenes, Parity
  Bit, Fibonacci Spiral, Power Tower, Chain Reactor, Fuse, Binary Search
  (Insertion only), Express Lane (Bubble only).
- `core/bots/bots.gd`: players for each algorithm (demo, sim, tests). They
  always sort perfectly; in ship rooms GREEDY ships whatever is ready at once,
  SMART grows runs and ships the best part of them when it has to.
- `ui/run_view.gd`: item choice with the floor map, end of run, transitions
  between screens (fade) and entry animations.
- `ui/anim.gd`: easings and animation helpers.
- `ui/room_view.gd`: the room for both algorithms. In Insertion the sorted
  part grows from the top (green bracket), you insert the golden key at the
  chosen spot, and the cost (shifts) is shown next to it.

### Boss: The Adversary

- Before the fight: a red warning on the choice screen and a boss card with
  its face and rules. The room has a red theme, and the goal is the **boss's
  HP**, which drops with every point.
- Its numbers are bigger than anything on the board (they have to travel the
  whole column) and **cursed**: they score half (purple frame).
- Every 4 moves it **strikes**, with a warning one move ahead: it swaps the
  sorted pair closest to the exit (move it first to dodge) or, when nothing is
  sorted, throws in an extra number.
- At half HP it becomes **enraged** (phase 2): new numbers and strikes come
  one move sooner.

In a ship room with no items a smart shipper beats it in ~73% of runs and a
greedy one in ~9%; with two items 78% and 40%.

### Items

11 items, each with a pixel icon (`ui/icons.gd`, drawn in code). When an item
triggers, what it added pops up above its row (`+3` multiplier in red, `+20`
points in blue, `×2`), and items with a different effect show it in words
("+1 move", "free move"). **Express Lane** changes how you play: lifting the
largest number carries it up to 3 cells higher for free.

### Balance

`sim/sim_rooms.gd` plays every room type from `Run.ROOMS` on many seeds (no
target, until the move budget runs out) and shows how often each player would
beat the target: the perfect bot in a classic room, and the greedy and smart
shippers in a ship room. The boss still gets enraged at half of its real
target. A ship room is well tuned when greedy usually misses and smart usually
makes it: the gap is what the ship decision is worth.

| Room (no items) | classic | ship: greedy | ship: smart |
|-----------------|---------|--------------|-------------|
| Bubble fight | 88% | 11% | 91% |
| Insertion fight | 100% | 29% | 74% |
| Bubble elite | 93% | 6% | 91% |
| Insertion elite | 100% | 31% | 52% |
| Boss | 56% | 9% | 73% |

The Insertion elite (reversed data) still has a small gap: there the smart
bot's simple rule is not much better than shipping at once.

```bash
godot --headless --path . -s res://sim/sim_rooms.gd
godot --headless --path . -s res://sim/sim_rooms.gd -- --ship --seeds 100 --only fight_bubble
```

## Core (stage 1)

The game logic is plain classes (`RefCounted`), with no scenes or window, so
it can be tested and simulated.

| File | What it does |
|------|--------------|
| `core/board.gd`, `core/element.gd` | array of elements with a capacity |
| `core/events.gd`, `core/event_bus.gd` | event names and the event bus (order = slot order) |
| `core/room.gd` | room: moves, budget, clearing, chains, shipping, score, win/loss, inflow |
| `core/hands.gd` | what a shipment is worth: length + patterns → mult |
| `core/score_context.gd`, `core/move_context.gd` | what items can change (points × multiplier, move cost) |
| `core/algorithms/bubble.gd` | swapping neighbours, the largest surfaces at the top |
| `core/algorithms/insertion.gd` | inserting the key, every shift costs 1, the smallest leaves first |
| `core/data_gen.gd` | starting data: random, nearly sorted, reversed, duplicates |
| `core/number_props.gd` | even, prime, powers of two, Fibonacci, squares |
| `core/items/` | an item as data + reactions to events |

The rule shared by all algorithms: an element at the exit disappears and
scores when it is the extreme one (largest in Bubble, smallest in Insertion).
In classic rooms it leaves by itself, and several clears after one move make a
chain: clear score = `value × 10 × multiplier`, where the multiplier starts at
the link's number in the chain (max 8). In ship rooms it waits for a SHIP move
and the multiplier is the hand's. Either way items add to the points or the
multiplier of each number.

## Tests

```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
```

The first command is needed only once and after adding a new class
(`class_name`). Exit code 0 = everything passed. A test fails on a failed
check or on any engine error while it runs.

## Assets

Every external asset has an entry in [CREDITS.md](CREDITS.md).
