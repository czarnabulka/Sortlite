# Sortlite: notes for Claude

A puzzle roguelite about sorting, in Godot 4.7 and GDScript. The
[README](README.md) explains the game and the folders. The design document
is a Claude Docs doc: https://claude.ai/artifact/5ETaojyCo7PVF7KUTtAXea
(read and edit it with the Claude Docs connector, never by fetching the URL).
Keep it in step when rules, rooms, items or balance numbers change.

## Commands

Godot is not on PATH. The executable for this machine is in
`CLAUDE.local.md` (`$GODOT` below); use the `_console.exe` build so output
reaches the terminal.

```bash
$GODOT --headless --path . --import                         # after adding a class_name or editing i18n/strings.csv
$GODOT --headless --path . -s res://tests/run_tests.gd      # tests; exit 0 = all passed
$GODOT --headless --path . -s res://sim/sim_rooms.gd -- --ship              # balance: greedy vs smart bot per room
$GODOT --headless --path . -s res://sim/sim_rooms.gd -- --ship --only boss_adversary --seeds 300
$GODOT --headless --path . -s res://sim/sim_rooms.gd -- --ship --only "*quick" --items 0,5   # floor 2 with a floor-2 hand
$GODOT --headless --path . -s res://sim/sim_rooms.gd -- --ship --build sieve,doubler,bubble_pump,power_tower
$GODOT --path . -s res://tools/shot.gd -- --screen room --room 1 --lang pl --out <png>   # screenshot (opens a window)
```

`tools/shot.gd` lists its options at the top (title, settings, pause, rules
and boss cards). Write PNGs and scratch scripts to the session's scratchpad,
not the repo.

## Before calling a change done

- The tests pass. Any engine error during a test also fails it.
- A rules or balance change: run the simulator. A ship room is tuned when the
  greedy bot (ships at once) usually misses the target and the smart bot
  (waits for better hands) usually makes it; today greedy wins 2–27% and smart
  67–84% with no items. Floor 2 rooms are tuned the same way but with 5
  random items (`--items 5`), since a player holds 5–6 by then; watch the
  one-shot column (a single shipment clears the room). Update the balance
  chart in the design document.
- A UI change: take screenshots in English and Polish and look at them.
  Polish text is longer and wraps differently; check for overlaps and cut
  lines.
- You cannot play the game. Say what you checked (tests, sim, screenshots)
  and what you did not.

## Conventions

- Game rules live in `core/` as plain `RefCounted` classes with no scenes;
  the `ui/` scripts only draw and forward input. Items and the boss react to
  events on the `EventBus`, never to each other.
- Room tuning (targets, moves, shipments, arrival pace, data) is the `ROOMS`
  table in `core/run.gd`; `ship_cfg` overrides it for ship rooms, which are
  the default.
- Every player-facing string is a row in `i18n/strings.csv` with both `en`
  and `pl`, read with `tr("KEY")`. Quote a text that contains a comma. Run
  `--import` after editing. `tests/test_i18n.gd` checks keys, both languages
  and font glyphs; menu labels go through `MenuView.LABELS`.
- Text is drawn only at 16, 20 and 32 px (`S`, `M`, `L`); other sizes blur
  the pixel font.
- Sounds: screens call `Sfx.play(&"name")`; every name is a row in
  `Sfx.SOUNDS` (`ui/sfx.gd`: files, volume, pitch spread). The effects are
  synthesized by `tools/make_sfx.gd` into `assets/sounds/synth/` (one soft
  chiptune family in C major; it replaced a mix of five Kenney packs that
  players found weak); only the 8-bit jingles are Kenney files in
  `assets/sounds/kenney/`. To change a sound, edit its voices in the tool, run
  it (`$GODOT --headless --path . -s res://tools/make_sfx.gd`), then
  `--import`, and copy the printed dB into `Sfx.SOUNDS` and the RMS into
  `tests/test_sfx.gd`. The test checks every file loads, every played name
  exists, no file goes unused and nothing plays over -24 dB. You cannot hear
  the sounds: say the user should listen. Played loudness (the file's RMS + the
  dB) sits in the bands at the top of `ui/sfx.gd`; a player found the first
  levels painful.
- Icons are 16×16 cells of Kenney's 1-Bit Pack (`assets/icons/kenney_1bit.png`,
  49×22 cells), tinted when drawn; `ui/icons.gd` maps items, the boss and UI
  glyphs to cells. Check a new cell by rendering it: neighbouring cells are
  easy to mix up. `tests/test_icons.gd` checks every item has a non-empty cell.
- `tools/shot.gd -- --items a,b,c` gives the run items; `--screen reward`
  shows the item choice, `--screen shop` the shop (`--bits N`, `--replace`);
  `--seed 3` fixes the run (seed 3: floor 2 opens with a Quick fight and has
  the Quick elite, `--room 4` / `--room 6`).
- Files use LF line endings. Python on Windows writes CRLF in text mode, so
  open files with `newline=""` (or `"\n"`) when editing them from a script.
- Player settings are saved in `user://settings.cfg` on the user's machine.
  A script that changes settings must restore the file afterwards.
- Sortlite is its own project: no references to Bubble Sort Quest. Keep docs
  plain and current, without hype or stage history.
- Code, comments, docs and commit messages are in English. Reply to the user
  in the language they write in (usually Polish).

## Git and releases

- Solo project on `main`. Commit or push only when asked.
- Commit message: a short title line, then a few bullets on what changed and
  why; end with the co-author line the session provides.
- A release X.Y: set `config/version` in `project.godot`, commit
  "Version X.Y: <what is new>", add an annotated tag `vX.Y`
  ("Sortlite X.Y: <theme>"), push `main` and the tag. Releases are tags only;
  `gh` is not installed, so GitHub pages and the repo description are set by
  the user.

## Keeping this file current

When a change adds a command, a tool, a convention or a design decision, or
finishes a release, update this file in the same commit. Keep it short:
remove what is no longer true instead of adding notes beside it. The
balance numbers above and "Where things stand" go stale first. Details that
only apply to this machine go in `CLAUDE.local.md`.

## Where things stand

- Released: 0.3.4 (the game was called Roguesort before it; the GitHub repo
  is now `czarnabulka/sortlite`, this folder still has the old name). Two floors (`Run.FLOORS`): Bubble and Insertion with the
  Adversary, then Pancake and Quick with the Burnt Stack, floor 2 tuned for
  a 5-item hand; 13 items (Spatula and Median of Three for the new
  algorithms) in 6 slots, a full hand replaces one; a shop after rooms 2, 4
  and 6; at most 6 numbers per shipment; title screen, settings and pause menu; synthesized
  sound effects (players found them much better than the Kenney mix) and icons from the 1-Bit Pack.
- Open questions: a strong build still clears floor 1 rooms with one
  shipment (76–81%, the 6-number cap cut Quick's 43% to 14–19% but not
  this); with the cap, waiting matters less in Insertion (greedy 26–30%
  against 60–70%) and Quick (28%); are the Burnt Stack's sides readable to
  players;
  are strong builds rewarded right (after the Sieve and
  Doubler nerf, Sieve + Doubler + Bubble Pump + Power Tower scores about 3×
  a room's target, was 5×);
  values are 1–12 (patterns would like a wider range); keep or drop classic
  rooms (`--classic`); does Insertion's ship decision feel real to players.
- Next steps: the Roadmap section of the design document.
