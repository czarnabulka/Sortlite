class_name Events
extends RefCounted
## Names of every game event. Items, curses and bosses react only to these,
## which is what lets them combine without knowing about each other.

const ROOM_START := &"room_start"
const ROOM_END := &"room_end"
## Before a move is applied. data.ctx is a MoveContext; handlers may change ctx.cost.
const BEFORE_MOVE := &"before_move"
## After any move. data: room, move, cost, wrong.
const MOVE := &"move"
## Algorithm-specific move kinds, emitted together with MOVE.
const SWAP := &"swap"
const INSERT := &"insert"
const FLIP := &"flip"
const PARTITION := &"partition"
const MERGE := &"merge"
## Heap: a number trades places with its parent.
const SIFT := &"sift"
## Heap: the root goes to the sorted tail at the exit.
const POP := &"pop"
## Ship rooms: the player sends the ready run out. Move: {"type": SHIP, "count": n}.
const SHIP := &"ship"
## A shipment is about to score. data: room, count, values, mult, patterns;
## handlers may add patterns and change mult.
const HAND := &"hand"
const WRONG_MOVE := &"wrong_move"
## An element is about to score. data.ctx is a ScoreContext; handlers change points / mult.
const SURFACE := &"surface"
## After an element scored. data: room, ctx, gained.
const SCORED := &"scored"
## After a chain of 2 or more surfacings. data: room, length.
const CHAIN := &"chain"
const ARRIVE := &"arrive"
## A board was full. data: room, value, absorbed (a handler may set it true).
const OVERFLOW := &"overflow"
## An item did something the player should see now. data: room, id.
const ITEM_TRIGGERED := &"item_triggered"
## A boss warns which pair it will hit next. data: room, uids, index.
const BOSS_AIM := &"boss_aim"
## A boss hit. data: room, index (the lower element of the swapped pair).
const BOSS_STRIKE := &"boss_strike"
## The aimed pair moved away in time. data: room.
const BOSS_DODGED := &"boss_dodged"
## A boss reached its second phase (half of the target scored). data: room.
const BOSS_ENRAGED := &"boss_enraged"
## The Memory Leak gave a cell back after a long shipment. data: room.
const MEMORY_FREED := &"memory_freed"
## A boss's phase shield stopped points (Room.score_cap). data: room, blocked.
const BOSS_SHIELD := &"boss_shield"
