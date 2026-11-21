extends TestCase
## Sound effects: every row of Sfx.SOUNDS points at real files, and every
## sound the screens ask for has a row.


func test_every_sound_file_loads() -> void:
	for name: StringName in Sfx.SOUNDS:
		var row: Array = Sfx.SOUNDS[name]
		check(row.size() == 3 or row.size() == 4, "%s: [files, dB, spread, gap?]" % name)
		check(not (row[0] as Array).is_empty(), "%s: at least one file" % name)
		for file: String in row[0]:
			var stream := load(Sfx.DIR + file) as AudioStream
			check(stream != null, "%s: %s loads" % [name, file])
			if stream != null:
				check(stream.get_length() > 0.0 and stream.get_length() < 2.0, "%s: %s is a short sound" % [name, file])
		check(float(row[1]) <= 0.0 and float(row[1]) >= -30.0, "%s: volume in dB" % name)


## Every file in the sounds folder is used, so no dead weight ships.
func test_no_unused_sound_files() -> void:
	var used := {}
	for row: Array in Sfx.SOUNDS.values():
		for file: String in row[0]:
			used[file] = true
	for sub in ["synth", "kenney"]:
		for f in DirAccess.get_files_at(Sfx.DIR + sub):
			if f.ends_with(".ogg") or f.ends_with(".wav"):
				check(used.has(sub + "/" + f), "%s/%s is not used in Sfx.SOUNDS" % [sub, f])


func test_sounds_used_in_code_exist() -> void:
	var re := RegEx.create_from_string("Sfx\\.play\\(&\"([a-z_]+)\"")
	var dynamic := RegEx.create_from_string("&\"([a-z_]+)\"")
	for f in DirAccess.get_files_at("res://ui"):
		if not f.ends_with(".gd") or f == "sfx.gd":
			continue
		var text := FileAccess.get_file_as_string("res://ui/" + f)
		for m in re.search_all(text):
			check(Sfx.SOUNDS.has(StringName(m.get_string(1))), "%s plays unknown sound %s" % [f, m.get_string(1)])
	# Names passed through a variable (the banner sound, the end of a room).
	var room := FileAccess.get_file_as_string("res://ui/room_view.gd")
	for line in room.split("\n"):
		if "banner_sound = " in line or "Sfx.play((" in line:
			for m in dynamic.search_all(line):
				check(Sfx.SOUNDS.has(StringName(m.get_string(1))), "room_view uses unknown sound %s" % m.get_string(1))


func test_score_notes_climb_the_pentatonic() -> void:
	check_eq(Sfx.score_pitch(1), 1.0, "first number at the base pitch")
	for i in range(2, 7):
		check(Sfx.score_pitch(i) > Sfx.score_pitch(i - 1), "number %d higher than the one before" % i)
	check(is_equal_approx(Sfx.score_pitch(3), pow(2.0, 4.0 / 12.0)), "a major third at the 3rd")
	check(is_equal_approx(Sfx.score_pitch(6), 2.0), "an octave at the 6th")
	check_eq(Sfx.score_pitch(20), Sfx.score_pitch(6), "never past an octave")


## Played loudness (the file's RMS + the row's dB) stays under -24 dB for the
## loudest files, so no sound jumps out. File RMS measured once, in dB
## (tools/make_sfx.gd prints it for the synthesized ones).
func test_no_sound_is_much_louder_than_the_rest() -> void:
	var rms := {
		"kenney/jingles_NES03.ogg": -13.8, "kenney/jingles_NES09.ogg": -15.7,
		"kenney/jingles_NES10.ogg": -15.3, "kenney/jingles_NES11.ogg": -13.7,
		"kenney/jingles_NES12.ogg": -13.7, "kenney/jingles_NES15.ogg": -15.4,
		"synth/arrive.wav": -13.7, "synth/back.wav": -11.1, "synth/boss_aim.wav": -8.1,
		"synth/boss_dodged.wav": -12.4, "synth/boss_enraged.wav": -12.5,
		"synth/boss_intro.wav": -11.0, "synth/boss_strike.wav": -14.4,
		"synth/card_close.wav": -12.6, "synth/card_hover.wav": -12.4, "synth/card_open.wav": -12.4,
		"synth/chips.wav": -16.6, "synth/combo_big.wav": -14.2, "synth/combo_mid.wav": -11.5,
		"synth/combo_small.wav": -11.2, "synth/confirm.wav": -11.2, "synth/cursor.wav": -12.6,
		"synth/deal.wav": -13.5, "synth/flip.wav": -13.4, "synth/heal.wav": -11.3,
		"synth/insert.wav": -13.5, "synth/item.wav": -11.7, "synth/overflow.wav": -15.1,
		"synth/partition.wav": -10.9, "synth/pattern.wav": -11.2, "synth/ready.wav": -13.4,
		"synth/score.wav": -12.4, "synth/shield.wav": -15.4, "synth/ship.wav": -9.2,
		"synth/skip.wav": -11.6, "synth/swap.wav": -10.9, "synth/take.wav": -11.0,
		"synth/toggle.wav": -12.6, "synth/wrong.wav": -5.3}
	for name: StringName in Sfx.SOUNDS:
		var row: Array = Sfx.SOUNDS[name]
		for file: String in row[0]:
			check(rms.has(file), "%s: RMS of %s listed here" % [name, file])
			if rms.has(file):
				var played := float(rms[file]) + float(row[1])
				check(played <= -24.0, "%s (%s) plays at %.1f dB RMS, over -24" % [name, file, played])


func test_play_without_the_node_does_nothing() -> void:
	# Tests and the simulator have no Sfx node; screens may still call it.
	Sfx.play(&"swap")
	check(true, "no crash")
