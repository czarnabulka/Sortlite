class_name Sfx
extends Node
## Sound effects. Screens call `Sfx.play(&"swap")`; this node (made by
## main.gd) owns a few players and the volume. Without it (tests, sim) a call
## does nothing.
##
## Every sound is in the SOUNDS table: the files (one is picked at random) and
## a volume. The effects are synthesized by tools/make_sfx.gd into
## assets/sounds/synth (one soft chiptune family in C major, change a sound
## there and run it again); the 8-bit jingles are Kenney's CC0 Music Jingles
## (assets/sounds/kenney, see CREDITS.md).
##
## Levels: the volumes put each sound at a measured loudness (the file's RMS
## plus the row's dB): about -30 dB for what plays all the time (moves,
## scores), -26 to -28 for events, -24 to -25 for the boss and the end of a
## room. A limiter on the Master bus keeps stacked sounds from clipping.

const DIR := "res://assets/sounds/"
const PLAYERS := 10
## The same sound again within this many seconds is skipped (a batch of
## arrivals, several items at once), so sounds don't stack into noise.
const MIN_GAP := 0.045
## Random pitch spread for sounds heard often, so repeats don't grate.
const SPREAD := 0.04
## The score notes climb the C major pentatonic, in semitones, up to an
## octave: every note fits the chord that ends the shipment.
const SCORE_STEPS: Array[int] = [0, 2, 4, 7, 9, 12]
## The Master limiter's ceiling, in dB.
const CEILING_DB := -3.0

## name -> [files (under DIR), volume in dB, spread pitch?, optional: seconds
## before it may play again]
const SOUNDS := {
	# Menus and cards
	&"cursor": [["synth/cursor.wav"], -17.5, true],
	&"confirm": [["synth/confirm.wav"], -16.0, false],
	&"back": [["synth/back.wav"], -16.0, false],
	&"toggle": [["synth/toggle.wav"], -14.5, false],
	&"card_open": [["synth/card_open.wav"], -14.5, false],
	&"card_close": [["synth/card_close.wav"], -14.5, false],
	# Moves
	&"swap": [["synth/swap.wav"], -19.0, true],
	&"insert": [["synth/insert.wav"], -16.5, true],
	&"flip": [["synth/flip.wav"], -16.5, true],
	&"partition": [["synth/partition.wav"], -19.0, true],
	&"wrong": [["synth/wrong.wav"], -21.5, false],
	&"arrive": [["synth/arrive.wav"], -16.5, true],
	&"ship": [["synth/ship.wav"], -18.0, false],
	# Scoring: one note per number, a step up the pentatonic each time (see
	# score_pitch); from the 4th number on, a coin tink under it, and the last
	# number of a shipment lands with a bigger chord the longer it was.
	&"score": [["synth/score.wav"], -17.5, false],
	&"chips": [["synth/chips.wav"], -13.5, true],
	&"combo_small": [["synth/combo_small.wav"], -16.0, false],
	&"combo_mid": [["synth/combo_mid.wav"], -15.5, false],
	&"combo_big": [["synth/combo_big.wav"], -10.5, false],
	&"combo_fanfare": [["kenney/jingles_NES09.ogg"], -12.0, false],
	&"item": [["synth/item.wav"], -18.5, true],
	&"pattern": [["synth/pattern.wav"], -16.0, false],
	# A number joins the ready run at the exit (pitch rises with the run).
	&"ready": [["synth/ready.wav"], -16.5, false],
	# Trouble
	&"overflow": [["synth/overflow.wav"], -12.0, false],
	# Last shipment, or few moves left.
	&"warning": [["kenney/jingles_NES15.ogg"], -14.0, false, 6.0],
	# The column is one number from full: it can flicker around that line,
	# so at most once every few seconds.
	&"danger": [["kenney/jingles_NES10.ogg"], -15.0, false, 8.0],
	# Boss
	&"boss_intro": [["synth/boss_intro.wav"], -13.5, false],
	&"boss_aim": [["synth/boss_aim.wav"], -19.0, false],
	&"boss_strike": [["synth/boss_strike.wav"], -10.0, false],
	&"boss_dodged": [["synth/boss_dodged.wav"], -14.5, false],
	&"boss_enraged": [["synth/boss_enraged.wav"], -12.0, false],
	&"shield": [["synth/shield.wav"], -11.5, false],
	# Between rooms: the offer is a hand of cards
	&"deal": [["synth/deal.wav"], -13.5, false],
	&"card_hover": [["synth/card_hover.wav"], -17.5, true],
	&"take": [["synth/take.wav"], -16.0, false],
	&"skip": [["synth/skip.wav"], -15.5, false],
	&"heal": [["synth/heal.wav"], -15.5, false],
	# Endings (8-bit jingles)
	&"room_won": [["kenney/jingles_NES03.ogg"], -12.0, false],
	&"boss_defeated": [["kenney/jingles_NES12.ogg"], -11.0, false],
	&"room_lost": [["kenney/jingles_NES11.ogg"], -12.0, false],
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


## A note per shipped number: a step up the pentatonic each time, up to an octave.
static func score_pitch(index: int) -> float:
	return pow(2.0, SCORE_STEPS[clampi(index - 1, 0, SCORE_STEPS.size() - 1)] / 12.0)


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
				_streams[file] = load(DIR + file)


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
