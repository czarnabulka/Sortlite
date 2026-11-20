class_name Sfx
extends Node
## Sound effects. Screens call `Sfx.play(&"swap")`; this node (made by
## main.gd) owns a few players and the volume. Without it (tests, sim) a call
## does nothing.
##
## Every sound is in the SOUNDS table: the files (one is picked at random) and
## a volume. To change a sound, change its row; the files are Kenney's CC0
## packs (assets/sounds/kenney, see CREDITS.md).

const DIR := "res://assets/sounds/kenney/"
const PLAYERS := 12
## The same sound again within this many seconds is skipped (a batch of
## arrivals, several items at once), so sounds don't stack into noise.
const MIN_GAP := 0.045
## Random pitch spread for sounds heard often, so repeats don't grate.
const SPREAD := 0.04

## name -> [files, volume in dB, spread pitch?]
const SOUNDS := {
	# Menus and cards
	&"cursor": [["tick_002"], -10.0, true],
	&"confirm": [["confirmation_001"], -8.0, false],
	&"back": [["back_002"], -8.0, false],
	&"toggle": [["toggle_002"], -8.0, false],
	&"card_open": [["maximize_009"], -12.0, false],
	&"card_close": [["minimize_009"], -12.0, false],
	# Moves
	&"swap": [["impactWood_light_000", "impactWood_light_001", "impactWood_light_002", "impactWood_light_003"], -6.0, true],
	&"insert": [["impactPlate_light_000"], -6.0, true],
	&"wrong": [["error_004"], -8.0, false],
	&"arrive": [["drop_003"], -12.0, true],
	&"ship": [["select_007"], -6.0, false],
	# Scoring: one pluck per number, a step higher each time (see score_pitch);
	# from the 4th number on, chips pile up under it, and the last number of a
	# shipment lands with a bigger handful the longer the shipment was.
	&"score": [["pluck_001"], -6.0, false],
	&"chips": [["chips-stack-1", "chips-stack-2", "chips-stack-4", "chips-stack-5", "chips-stack-6"], -10.0, true],
	&"combo_small": [["chips-handle-3"], -8.0, false],
	&"combo_mid": [["chips-handle-1"], -6.0, false],
	&"combo_big": [["chips-handle-5"], -4.0, false],
	&"combo_fanfare": [["jingles_NES09"], -8.0, false],
	&"item": [["glass_006"], -12.0, true],
	&"pattern": [["powerUp7"], -10.0, false],
	# A number joins the ready run at the exit (pitch rises with the run).
	&"ready": [["chip-lay-1"], -12.0, false],
	# Trouble
	&"overflow": [["impactPunch_medium_000"], -4.0, false],
	# Last shipment, or few moves left.
	&"warning": [["jingles_NES15"], -8.0, false],
	# The column is one number from full.
	&"danger": [["jingles_NES10"], -10.0, false],
	# Boss
	&"boss_intro": [["lowThreeTone"], -8.0, false],
	&"boss_aim": [["tone1"], -10.0, false],
	&"boss_strike": [["impactPunch_heavy_000"], -4.0, false],
	&"boss_dodged": [["phaseJump2"], -10.0, false],
	&"boss_enraged": [["lowDown"], -6.0, false],
	&"shield": [["impactMetal_light_002"], -8.0, false],
	# Between rooms: the offer is a hand of cards
	&"deal": [["card-fan-1"], -8.0, false],
	&"card_hover": [["card-slide-1", "card-slide-5"], -12.0, true],
	&"take": [["card-place-1"], -6.0, false],
	&"skip": [["back_003"], -8.0, false],
	&"heal": [["powerUp2"], -10.0, false],
	# Endings (8-bit jingles)
	&"room_won": [["jingles_NES03"], -8.0, false],
	&"boss_defeated": [["jingles_NES12"], -6.0, false],
	&"room_lost": [["jingles_NES11"], -6.0, false],
}

static var _main: Sfx

var _streams: Dictionary = {}  # file -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last: Dictionary = {}  # name -> time it last played
var _clock := 0.0


static func play(name: StringName, pitch := 1.0) -> void:
	if _main != null:
		_main._play(name, pitch)


## A note per shipped number: a semitone up each time, up to an octave.
static func score_pitch(index: int) -> float:
	return pow(2.0, mini(maxi(index - 1, 0), 12) / 12.0)


## 0..100, saved in the settings; 0 mutes.
static func set_volume(percent: int) -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(bus, percent <= 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(percent / 100.0, 0.001, 1.0)))


func _ready() -> void:
	_main = self
	for i in PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for row: Array in SOUNDS.values():
		for file: String in row[0]:
			if not _streams.has(file):
				_streams[file] = load(DIR + file + ".ogg")


func _exit_tree() -> void:
	if _main == self:
		_main = null


func _process(delta: float) -> void:
	_clock += delta


func _play(name: StringName, pitch: float) -> void:
	var row: Array = SOUNDS.get(name, [])
	if row.is_empty():
		push_error("Sfx: unknown sound '%s'" % name)
		return
	if _clock - float(_last.get(name, -1.0)) < MIN_GAP:
		return
	_last[name] = _clock
	var files: Array = row[0]
	var stream: AudioStream = _streams.get(files[randi() % files.size()])
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = float(row[1])
	p.pitch_scale = pitch * (randf_range(1.0 - SPREAD, 1.0 + SPREAD) if row[2] else 1.0)
	p.play()
