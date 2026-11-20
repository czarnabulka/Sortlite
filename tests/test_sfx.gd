extends TestCase
## Sound effects: every row of Sfx.SOUNDS points at real files, and every
## sound the screens ask for has a row.


func test_every_sound_file_loads() -> void:
	for name: StringName in Sfx.SOUNDS:
		var row: Array = Sfx.SOUNDS[name]
		check(row.size() == 3 or row.size() == 4, "%s: [files, dB, spread, gap?]" % name)
		check(not (row[0] as Array).is_empty(), "%s: at least one file" % name)
		for file: String in row[0]:
			var stream := load(Sfx.DIR + file + ".ogg") as AudioStream
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
	for f in DirAccess.get_files_at(Sfx.DIR):
		if f.ends_with(".ogg"):
			check(used.has(f.get_basename()), "%s is not used in Sfx.SOUNDS" % f)


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


func test_score_notes_climb_a_fifth() -> void:
	check_eq(Sfx.score_pitch(1), 1.0, "first number at the base pitch")
	check(Sfx.score_pitch(2) > Sfx.score_pitch(1), "each next number higher")
	check(is_equal_approx(Sfx.score_pitch(8), pow(2.0, 7.0 / 12.0)), "a fifth at the 8th")
	check_eq(Sfx.score_pitch(20), Sfx.score_pitch(8), "never past a fifth")


## Played loudness (the file's RMS + the row's dB) stays under -24 dB for the
## loudest files, so no sound jumps out. File RMS measured once, in dB.
func test_no_sound_is_much_louder_than_the_rest() -> void:
	var rms := {"confirmation_001": -11.3, "maximize_009": -10.6, "minimize_009": -10.6, "lowDown": -10.1,
			"lowThreeTone": -10.9, "toggle_002": -12.2, "select_007": -13.6, "jingles_NES03": -13.8,
			"jingles_NES11": -13.7, "jingles_NES12": -13.7, "powerUp7": -14.8, "phaseJump2": -14.4,
			"jingles_NES09": -15.7, "jingles_NES10": -15.3, "jingles_NES15": -15.4, "back_002": -15.8,
			"error_004": -16.3, "impactPunch_medium_000": -17.2, "tone1": -17.2, "tick_002": -17.2,
			"impactPunch_heavy_000": -18.0}
	for name: StringName in Sfx.SOUNDS:
		var row: Array = Sfx.SOUNDS[name]
		for file: String in row[0]:
			if rms.has(file):
				var played := float(rms[file]) + float(row[1])
				check(played <= -24.0, "%s (%s) plays at %.1f dB RMS, over -24" % [name, file, played])


func test_play_without_the_node_does_nothing() -> void:
	# Tests and the simulator have no Sfx node; screens may still call it.
	Sfx.play(&"swap")
	check(true, "no crash")
