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
const WRONG_MOVE := &"wrong_move"
## An element is about to score. data.ctx is a ScoreContext; handlers change points / mult.
const SURFACE := &"surface"
## After an element scored. data: room, ctx, gained.
const SCORED := &"scored"
## After a chain of 2 or more surfacings. data: room, length.
const CHAIN := &"chain"
const ARRIVE := &"arrive"
const OVERFLOW := &"overflow"
