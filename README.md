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
picks the language for a single launch, and `-- --seed 123` replays a run.

## Languages

The game is in English by default, with Polish as an option (L key; the
choice is saved in `user://settings.cfg`). All text lives in
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
| I | room rules card (shows up by itself in the first room of each algorithm) |
| A / D, click | pick an item between rooms; SPACE takes it |
| S / R / E | between rooms: skip (+bits), reroll the offer, heal a life |
| M | inflow: every N moves or every 6 s |
| D | demo: the bot plays by itself |
| R | new run (on the end screen) |
| C | CRT effect on / off |
| L | language: English / polski (remembered) |
| H | controls card |
| F11 | fullscreen |
| ESC | quit |

## Status: stage 3 (mini-run)

A run is one floor with 4 rooms: a Bubble fight and an Insertion fight (in
random order), an elite on reversed data, and the boss **The Adversary**,
which always adds the worst possible element. Before each room you pick 1 of 3
items (max 5, order = order of activation). Lives carry over between rooms.
Each room pays bits (+1 for every 5 unspent moves): 2 bits reroll the offer,
5 heal a life, and skipping an item gives 3.

- `core/run.gd`: floor plan (the `ROOMS` table), rewards, bits, lives.
- `core/items/catalog.gd`: 10 items, including Sieve of Eratosthenes, Parity
  Bit, Fibonacci Spiral, Power Tower, Chain Reactor, Fuse, Binary Search
  (Insertion only).
- `core/bots/bots.gd`: a perfect player for each algorithm (demo, sim, tests).
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

With no items the bot beats it in ~59% of runs, with two in ~78%: this is
where items really decide the outcome.

### Items

11 items, each with a pixel icon (`ui/icons.gd`, drawn in code). When an item
triggers, what it added pops up above its row (`+3` multiplier in red, `+20`
points in blue, `×2`), and items with a different effect show it in words
("+1 move", "free move"). **Express Lane** changes how you play: lifting the
largest number carries it up to 3 cells higher for free.

### Balance

`sim/sim_rooms.gd` plays every room type from `Run.ROOMS` on 300 seeds (a
flawless bot, no target) and shows how often it would beat the target. Targets
are set to about half of the bot's median with no items, because a human plays
slower and makes mistakes. Current numbers (no items): fights 88–100%, elites
92–100%, boss 76%.

```bash
godot --headless --path . -s res://sim/sim_rooms.gd
```

## Core (stage 1)

The game logic is plain classes (`RefCounted`), with no scenes or window, so
it can be tested and simulated.

| File | What it does |
|------|--------------|
| `core/board.gd`, `core/element.gd` | array of elements with a capacity |
| `core/events.gd`, `core/event_bus.gd` | event names and the event bus (order = slot order) |
| `core/room.gd` | room: moves, budget, clearing, chains, score, win/loss, inflow |
| `core/score_context.gd`, `core/move_context.gd` | what items can change (points × multiplier, move cost) |
| `core/algorithms/bubble.gd` | swapping neighbours, the largest surfaces at the top |
| `core/algorithms/insertion.gd` | inserting the key, every shift costs 1, the smallest leaves first |
| `core/data_gen.gd` | starting data: random, nearly sorted, reversed, duplicates |
| `core/number_props.gd` | even, prime, powers of two, Fibonacci, squares |
| `core/items/` | an item as data + reactions to events |

The rule shared by all algorithms: an element at the exit disappears and
scores when it is the extreme one (largest in Bubble, smallest in Insertion).
Several clears after one move make a chain. Clear score =
`value × 10 × multiplier`, where the multiplier starts at the link's number in
the chain (max 8), and items add to the points or the multiplier.

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
