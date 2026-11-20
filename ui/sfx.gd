class_name Sfx
extends Node
## Sound effects. Screens call `Sfx.play(&"swap")`; this node (made by
## main.gd) owns a few players and the volume. Without it (tests, sim) a call
## does nothing.
##
## Every sound is in the SOUNDS table: the files (one is picked at random) and
## a volume. To change a sound, change its row; the files are Kenney's CC0
## packs (assets/sounds/kenney, see CREDITS.md).
##
## Levels: the volumes put each sound at a measured loudness (the file's RMS
## plus the row's dB): about -30 dB for what plays all the time (moves,
## scores), -26 to -28 for events, -24 to -25 for the boss and the end of a
## room. A limiter on the Master bus keeps stacked sounds from clipping.

const DIR := "res://assets/sounds/kenney/"
const PLAYERS := 10
## The same sound again within this many seconds is skipped (a batch of
## arrivals, several items at once), so sounds don't stack into noise.
const MIN_GAP := 0.045
## Random pitch spread for sounds heard often, so repeats don't grate.
const SPREAD := 0.04
## How high the score notes climb, in semitones (a fifth): bright plucks an
## octave up got shrill.
const SCORE_STEPS := 7
## The Master limiter's ceiling, in dB.
const CEILING_DB := -3.0

## name -> [files, volume in dB, spread pitch?, optional: seconds before it
## may play again]
const SOUNDS := {
	# Menus and cards
	&"cursor": [["tick_002"], -13.0, true],
	&"confirm": [["confirmation_001"], -15.0, false],
	&"back": [["back_002"], -12.0, false],
	&"toggle": [["toggle_002"], -16.0, false],
	&"card_open": [["maximize_009"], -18.0, false],
	&"card_close": [["minimize_009"], -18.0, false],
	# Moves
	&"swap": [["impactWood_light_000", "impactWood_light_001", "impactWood_light_002", "impactWood_light_003"], -8.0, true],
	&"insert": [["impactPlate_light_000"], -5.0, true],
	&"flip": [["card-slide-5"], -2.0, true],
	&"partition": [["card-fan-1"], -6.0, true],
	&"wrong": [["error_004"], -12.0, false],
	&"arrive": [["drop_003"], -12.0, true],
	&"ship": [["select_007"], -13.0, false],
	# Scoring: one pluck per number, a step higher each time (see score_pitch);
	# from the 4th number on, chips pile up under it, and the last number of a
	# shipment lands with a bigger handful the longer the shipment was.
	&"score": [["pluck_001"], -10.0, false],
	&"chips": [["chips-stack-1", "chips-stack-2", "chips-stack-4", "chips-stack-5", "chips-stack-6"], -10.0, true],
	&"combo_small": [["chips-handle-3"], -8.0, false],
	&"combo_mid": [["chips-handle-1"], -6.0, false],
	&"combo_big": [["chips-handle-5"], -4.0, false],
	&"combo_fanfare": [["jingles_NES09"], -12.0, false],
	&"item": [["glass_006"], -12.0, true],
	&"pattern": [["powerUp7"], -13.0, false],
	# A number joins the ready run at the exit (pitch rises with the run).
	&"ready": [["chip-lay-1"], -12.0, false],
	# Trouble
	&"overflow": [["impactPunch_medium_000"], -8.0, false],
	# Last shipment, or few moves left.
	&"warning": [["jingles_NES15"], -14.0, false, 6.0],
	# The column is one number from full: it can flicker around that line,
	# so at most once every few seconds.
	&"danger": [["jingles_NES10"], -15.0, false, 8.0],
	# Boss
	&"boss_intro": [["lowThreeTone"], -14.0, false],
	&"boss_aim": [["tone1"], -12.0, false],
	&"boss_strike": [["impactPunch_heavy_000"], -7.0, false],
	&"boss_dodged": [["phaseJump2"], -14.0, false],
	&"boss_enraged": [["lowDown"], -14.0, false],
	&"shield": [["impactMetal_light_002"], -8.0, false],
	# Between rooms: the offer is a hand of cards
	&"deal": [["card-fan-1"], -8.0, false],
	&"card_hover": [["card-slide-1", "card-slide-5"], -12.0, true],
	&"take": [["card-place-1"], -6.0, false],
	&"skip": [["back_003"], -8.0, false],
	&"heal": [["powerUp2"], -10.0, false],
	# Endings (8-bit jingles)
	&"room_won": [["jingles_NES03"], -12.0, false],
	&"boss_defeated": [["jingles_NES12"], -11.0, false],
	&"room_lost": [["jingles_NES11"], -12.0, false],
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


## A note per shipped number: a semitone up each time, up to a fifth.
static func score_pitch(index: int) -> float:
	return pow(2.0, mini(maxi(index - 1, 0), SCORE_STEPS) / 12.0)


## 0..100, saved in the settings; 0 mutes.
static func set_volume(percent: int) -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(bus, percent <= 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(percent / 100.0, 0.001, 1.0)))


func _ready() -> void:
	_main = self
	_add_limiter()
	for i in PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for row: Array in SOUNDS.values():
		for file: String in row[0]:
			if not _streams.has(file):
				_streams[file] = load(DIR + file + ".ogg")


## Several sounds at once (a long shipment, the boss's rage) add up; the
## limiter stops their sum from clipping into harsh distortion.
func _add_limiter() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = CEILING_DB
	AudioServer.add_bus_effect(bus, limiter)


func _exit_tree() -> void:
	if _main == self:
		_main = null
	# Take the limiter off again, so the bus holds no effect of ours at exit.
	var bus := AudioServer.get_bus_index(&"Master")
	for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectHardLimiter:
			AudioServer.remove_bus_effect(bus, i)


func _process(delta: float) -> void:
	_clock += delta


func _play(name: StringName, pitch: float) -> void:
	var row: Array = SOUNDS.get(name, [])
	if row.is_empty():
		push_error("Sfx: unknown sound '%s'" % name)
		return
	var gap := float(row[3]) if row.size() > 3 else MIN_GAP
	if _last.has(name) and _clock - float(_last[name]) < gap:
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
