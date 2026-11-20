class_name Settings
extends RefCounted
## Player settings kept between sessions in user://settings.cfg.

const PATH := "user://settings.cfg"
const LANGUAGES: Array[String] = ["en", "pl"]
const DEFAULT_LANGUAGE := "en"
## Each language in its own words, so anyone can find theirs.
const LANGUAGE_NAMES := {"en": "English", "pl": "polski"}


static func load_language() -> String:
	var lang := str(_load("language", DEFAULT_LANGUAGE))
	return lang if LANGUAGES.has(lang) else DEFAULT_LANGUAGE


static func save_language(lang: String) -> void:
	_save("language", lang)


static func load_crt() -> bool:
	return bool(_load("crt", true))


static func save_crt(on: bool) -> void:
	_save("crt", on)


## Sound volume, 0..100 in steps of 10 (0 = off).
static func load_volume() -> int:
	return clampi(int(_load("volume", 80)), 0, 100)


static func save_volume(percent: int) -> void:
	_save("volume", percent)


static func load_fullscreen() -> bool:
	return bool(_load("fullscreen", false))


static func save_fullscreen(on: bool) -> void:
	_save("fullscreen", on)


static func load_arrival_mode() -> RoomSession.ArrivalMode:
	var m := int(_load("arrival_mode", RoomSession.ArrivalMode.TURNS))
	return m as RoomSession.ArrivalMode if m in RoomSession.ArrivalMode.values() else RoomSession.ArrivalMode.TURNS


static func save_arrival_mode(mode: RoomSession.ArrivalMode) -> void:
	_save("arrival_mode", int(mode))


## The game was called Roguesort until 0.3.3, and Godot keeps user data in a
## folder named after the game: copy the old settings over once, so a player
## keeps theirs.
const OLD_DIR_NAME := "Roguesort"


static func _migrate() -> void:
	if FileAccess.file_exists(PATH):
		return
	var old := OS.get_user_data_dir().get_base_dir().path_join(OLD_DIR_NAME).path_join(PATH.get_file())
	if FileAccess.file_exists(old):
		DirAccess.copy_absolute(old, ProjectSettings.globalize_path(PATH))


static func _load(key: String, default: Variant) -> Variant:
	_migrate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return default
	return cfg.get_value("general", key, default)


static func _save(key: String, value: Variant) -> void:
	_migrate()
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # keep other values; a missing file is fine
	cfg.set_value("general", key, value)
	cfg.save(PATH)


## The next language in the list, wrapping around.
static func next_language(current: String) -> String:
	var i := LANGUAGES.find(current)
	return LANGUAGES[(i + 1) % LANGUAGES.size()]


## `godot --path . -- --lang pl` overrides the saved language for one run.
static func language_from_args() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--lang")
	if i >= 0 and i + 1 < args.size() and LANGUAGES.has(args[i + 1]):
		return args[i + 1]
	return ""
