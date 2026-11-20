# Roguesort

A puzzle roguelite about sorting. You put numbers in order with the moves of
real sorting algorithms, then choose when the sorted ones leave: a shipment
scores like a poker hand, and the items you pick between rooms build on each
other.

Version 0.3.2 · Godot 4.7, GDScript · English and Polish ·
[design document](https://claude.ai/artifact/5ETaojyCo7PVF7KUTtAXea)

## Run it

Open the folder in Godot and press F5, or:

```bash
godot --path .
```

The game opens on the title screen: new run, a demo where the bot plays,
settings (language, sound volume, CRT effect, fullscreen, arrivals by moves
or by time) and quit. ESC during a run opens the pause menu.

Options after `--`, for testing: `--seed 123` replays a run, `--demo` lets the
bot play, `--skip 3` jumps to a room (0–7; 3 and 7 are the bosses); these
three start a run at once. `--lang pl` picks the language for one launch, and
`--classic` plays the older rooms where sorted numbers leave by themselves.

## How it plays

- A run is two floors of four rooms: two fights, an elite and a boss. Floor 1
  has Bubble and Insertion rooms and the Adversary; floor 2 brings Pancake,
  Quick and the Burnt Stack. Before each room you pick 1 of 3 items (up to
  6; slot order is the order they act in). With every slot full, a new item
  replaces one you choose and takes its slot.
- After every second room a shop sells 3 items for bits (8 each) and one
  more shipment for the next room (5). Bits come from cleared rooms, unused
  moves and skipped items.
- **Bubble**: swap neighbours; the largest number is ready at the exit.
  **Insertion**: insert the gold key into the sorted part; every number it
  passes costs a move; the smallest number is ready at the exit.
  **Pancake**: flip a number over together with everything above it; the
  exit is at the bottom, where the largest number is ready.
  **Quick**: pick a pivot in a segment not yet in place; the segment splits
  around it (1 move per other number in it) and the pivot lands in place;
  the smallest number is ready at the exit.
- Ready numbers wait at the exit. **E** ships them as one hand (1 move, up
  to 6 numbers), **Q** ships fewer. Each number scores `value × 10 × mult`; the mult is the
  hand's length plus a bonus per number for each pattern:

  | Pattern | Example | Bonus per number |
  |---------|---------|------------------|
  | straight (3+ consecutive) | 4 5 6 | +2 |
  | match (2+ equal) | 7 7 | +2 |
  | all prime / Fibonacci / powers of 2 / squares (3+) | 2 3 5 | +2 each |
  | all even / all odd (3+) | 2 6 8 | +1 |

- Every room has a score target, a move budget and 4–7 shipments. Running out
  of shipments below the target loses the room. New numbers keep arriving, and
  one that arrives in a full column costs a life (3 per run).
- Each floor ends with a boss. The Adversary sends worst-case numbers that
  score half and swaps a sorted pair every few moves (move it to dodge). The
  Burnt Stack gives every number a burnt side that a flip turns over (burnt
  side up scores half) and scorches the clean number nearest the exit (move or
  ship it to dodge). Both get faster at half HP, and a shield stops any single
  shipment from taking more than half their HP.

## Controls

| Key | Action |
|-----|--------|
| W / S, arrows, mouse wheel | pick a pair (Bubble), a place for the key (Insertion), where the spatula goes (Pancake) or a pivot (Quick) |
| SPACE, click | swap / insert / flip / split |
| E | ship the ready numbers |
| Q / right-click | ship fewer / ship up to the clicked number |
| F | let the next number in now |
| I | rules of this room |
| H | controls card |
| A / D, click, SPACE | between rooms: pick and take an item |
| A / D, click, SPACE, Q | slots full: choose the item to drop, replace it, Q goes back |
| SPACE / E / R / S | in the shop: buy the card / +1 shipment / restock (2 bits) / leave |
| S / R / E | between rooms: skip (+3 bits), reroll the offer (2 bits), heal a life (5 bits) |
| R | new run, on the end screen |
| F11 | fullscreen |
| ESC | pause menu |

## Project layout

| Folder | What it holds |
|--------|---------------|
| `core/` | the game rules as plain classes, no scenes: board, room, hands, algorithms, items, run, bots |
| `ui/` | the screens: title and settings (`menu_view.gd`), run (`run_view.gd`), room (`room_view.gd`), CRT shader |
| `sim/` | balance simulator |
| `tests/` | tests that run without a window |
| `i18n/` | all text: `strings.csv` with `keys`, `en` and `pl` columns |
| `assets/` | the font, the sound effects and the icon sheet |

Room settings (targets, moves, shipments, arrival pace) live in the `ROOMS`
table in [core/run.gd](core/run.gd), and the items in
[core/items/catalog.gd](core/items/catalog.gd).

## Tests and balance

```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
godot --headless --path . -s res://sim/sim_rooms.gd -- --ship
```

Run `--import` once, and again after adding a `class_name` or changing the
strings. The tests exit with 0 when everything passes; any engine error also
fails a test. The simulator plays every room with two bots, one that ships at
once and one that waits for better hands. A room is tuned when the first
usually misses the target and the second usually makes it.

## Text and translations

New text is a new row in [i18n/strings.csv](i18n/strings.csv) and `tr("KEY")`
in the code. `tests/test_i18n.gd` checks that every key has both languages and
that the font can draw every character. The font, Jersey 10, is used only at
16, 20 and 32 px, where it stays crisp.

## Assets

Every external asset is listed in [CREDITS.md](CREDITS.md) with its source and
licence.
