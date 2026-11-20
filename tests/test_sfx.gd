extends TestCase
## Sound effects: every row of Sfx.SOUNDS points at real files, and every
## sound the screens ask for has a row.


func test_every_sound_file_loads() -> void:
	for name: StringName in Sfx.SOUNDS:
		var row: Array = Sfx.SOUNDS[name]
		check(row.size() == 3, "%s: [files, dB, spread]" % name)
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


func test_score_notes_climb_an_octave() -> void:
	check_eq(Sfx.score_pitch(1), 1.0, "first number at the base pitch")
	check(Sfx.score_pitch(2) > Sfx.score_pitch(1), "each next number higher")
	check(is_equal_approx(Sfx.score_pitch(13), 2.0), "an octave at the 13th")
	check_eq(Sfx.score_pitch(20), Sfx.score_pitch(13), "never past an octave")


func test_play_without_the_node_does_nothing() -> void:
	# Tests and the simulator have no Sfx node; screens may still call it.
	Sfx.play(&"swap")
	check(true, "no crash")
