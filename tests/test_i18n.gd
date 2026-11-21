extends TestCase
## Every key in i18n/strings.csv has an English and a Polish text, every key
## the code asks for exists, and the pixel font can draw every character.

const CSV := "res://i18n/strings.csv"
const FONT := "res://assets/fonts/Jersey10-Regular.ttf"
const SOURCES: Array[String] = ["res://ui/room_view.gd", "res://ui/run_view.gd", "res://ui/main.gd",
		"res://ui/menu_view.gd"]


func _rows() -> Dictionary:
	var rows := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	var header := f.get_csv_line()
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() >= header.size() and line[0] != "":
			rows[line[0]] = line
	return rows


## The screens are not covered by other tests; at least make sure they parse.
func test_ui_scripts_compile() -> void:
	for f in DirAccess.get_files_at("res://ui"):
		if f.ends_with(".gd"):
			var script := load("res://ui/" + f) as GDScript
			check(script != null and script.can_instantiate(), "ui/%s compiles" % f)


func test_header_is_keys_en_pl() -> void:
	var f := FileAccess.open(CSV, FileAccess.READ)
	check_eq(f.get_csv_line(), PackedStringArray(["keys", "en", "pl"]), "header")


func test_every_key_has_both_languages() -> void:
	var rows := _rows()
	check(rows.size() > 20, "table loaded")
	for key: String in rows:
		var row: PackedStringArray = rows[key]
		check(row[1].strip_edges() != "", "%s: English text" % key)
		check(row[2].strip_edges() != "", "%s: Polish text" % key)
		check_eq(row[1].count("%d"), row[2].count("%d"), "%s: same placeholders" % key)


func test_keys_used_in_code_exist() -> void:
	var rows := _rows()
	var re := RegEx.create_from_string("tr\\(\"([A-Z0-9_]+)\"\\)")
	for path in SOURCES:
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			check(rows.has(m.get_string(1)), "%s uses missing key %s" % [path.get_file(), m.get_string(1)])
	var help_re := RegEx.create_from_string("\"(HELP_[A-Z_]+)\"")
	for m in help_re.search_all(FileAccess.get_file_as_string("res://ui/room_view.gd")):
		check(rows.has(m.get_string(1)), "missing help key %s" % m.get_string(1))


func test_every_item_has_texts() -> void:
	var rows := _rows()
	for id in ItemCatalog.IDS:
		var item := ItemCatalog.make(id)
		check(rows.has(item.name_key), "missing %s" % item.name_key)
		check(rows.has(item.desc_key), "missing %s" % item.desc_key)


func test_every_hand_pattern_has_a_name() -> void:
	var rows := _rows()
	for p: StringName in Hands.BONUS_PER_ELEMENT:
		check(rows.has("HAND_" + String(p).to_upper()), "missing name for hand %s" % p)


func test_translations_load_in_both_languages() -> void:
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("pl")
	check_eq(TranslationServer.translate("LIVES"), "ŻYCIA", "Polish")
	TranslationServer.set_locale("en")
	check_eq(TranslationServer.translate("LIVES"), "LIVES", "English")
	TranslationServer.set_locale(before)


func test_font_draws_every_character() -> void:
	var font := load(FONT) as FontFile
	check(font != null, "font loads")
	if font == null:
		return
	var rows := _rows()
	var missing := {}
	for key: String in rows:
		var row: PackedStringArray = rows[key]
		for text in [row[1], row[2]]:
			for c in text:
				if not font.has_char(c.unicode_at(0)):
					missing[c] = key
	check(missing.is_empty(), "font lacks: %s" % str(missing))


## Keys the screens build from ids ("KIND_" + kind, "ALGO_" + id, "HINT_" + id).
func test_built_keys_exist() -> void:
	var rows := _rows()
	for kind in [Run.FIGHT, Run.ELITE, Run.BOSS]:
		check(rows.has("KIND_" + String(kind).to_upper()), "kind %s" % kind)
	for id in Algorithms.ALL:
		check(rows.has("ALGO_" + String(id).to_upper()), "algo %s" % id)
		check(rows.has("HINT_" + String(id).to_upper()), "hint %s" % id)
	for id in Algorithms.ALL:
		for i in range(1, 5):
			check(rows.has("RULES_%s_%d" % [String(id).to_upper(), i]), "rules %s %d" % [id, i])
	for id in Algorithms.ALL:
		check(rows.has("HINT_SHIP_" + String(id).to_upper()), "ship hint %s" % id)
	for boss in RoomSession.BOSSES:
		var b := String(boss).to_upper()
		for key in ["BOSS_NAME_", "BOSS_HP_", "BOSS_STRIKES_IN_", "RULES_"]:
			check(rows.has(key + b), "%s%s" % [key, b])
		for i in [1, 2]:
			check(rows.has("BOSS_INTRO_%s_%d" % [b, i]), "boss intro %s %d" % [b, i])
		check(rows.has("BOSS_INTRO_%s_2_MANY" % b), "boss intro %s with 5+ moves" % b)
	for key in ["EVERY_N_MOVES_MANY", "HINT_ADVERSARY", "WRONG_INSERT", "WRONG_SWAP", "WRONG_FLIP", "HELP_RULES", "BOSS_INTRO_SHIELD"]:
		check(rows.has(key), key)


## A comma inside an unquoted text splits it into extra columns and cuts it.
func test_every_row_has_exactly_three_columns() -> void:
	var f := FileAccess.open(CSV, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() == 1 and line[0] == "":
			continue
		check_eq(line.size(), 3, "row %s" % line[0])


## The menu builds its labels from a table (tr(LABELS[id])), out of reach of the
## regex above; every row of every page needs a text.
func test_menu_labels_exist() -> void:
	var rows := _rows()
	var menu := load("res://ui/menu_view.gd")
	for page in menu.PAGES:
		for id in menu.PAGES[page]:
			check(menu.LABELS.has(id), "menu row %s has a label" % id)
			check(rows.has(menu.LABELS.get(id, "")), "menu label for %s" % id)
	for lang in Settings.LANGUAGES:
		check(Settings.LANGUAGE_NAMES.has(lang), "name for language %s" % lang)
