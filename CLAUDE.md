# Roguesort: notes for Claude

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
  67–84% with no items. Update the balance chart in the design document.
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
- Files use LF line endings. Python on Windows writes CRLF in text mode, so
  open files with `newline=""` (or `"\n"`) when editing them from a script.
- Player settings are saved in `user://settings.cfg` on the user's machine.
  A script that changes settings must restore the file afterwards.
- Roguesort is its own project: no references to Bubble Sort Quest. Keep docs
  plain and current, without hype or stage history.
- Code, comments, docs and commit messages are in English. Reply to the user
  in the language they write in (usually Polish).

## Git and releases

- Solo project on `main`. Commit or push only when asked.
- Commit message: a short title line, then a few bullets on what changed and
  why; end with the co-author line the session provides.
- A release X.Y: set `config/version` in `project.godot`, commit
  "Version X.Y: <what is new>", add an annotated tag `vX.Y`
  ("Roguesort X.Y: <theme>"), push `main` and the tag. Releases are tags only;
  `gh` is not installed, so GitHub pages and the repo description are set by
  the user.

## Where things stand

- Released: 0.2 (shipment limits, boss phase shield). Since then: title
  screen, settings and pause menu; README rewrite.
- Open questions: Sieve + Doubler can decide a normal room with one shipment;
  values are 1–12 (patterns would like a wider range); keep or drop classic
  rooms (`--classic`); does Insertion's ship decision feel real to players.
- Next steps: the Roadmap section of the design document.
