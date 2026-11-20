class_name Settings
extends RefCounted
## Player settings kept between sessions in user://settings.cfg.

const PATH := "user://settings.cfg"
const LANGUAGES: Array[String] = ["en", "pl"]
const DEFAULT_LANGUAGE := "en"


static func load_language() -> String:
	var lang := str(_load("language", DEFAULT_LANGUAGE))
	return lang if LANGUAGES.has(lang) else DEFAULT_LANGUAGE


static func save_language(lang: String) -> void:
	_save("language", lang)


static func load_crt() -> bool:
	return bool(_load("crt", true))


static func save_crt(on: bool) -> void:
	_save("crt", on)


static func load_arrival_mode() -> RoomSession.ArrivalMode:
	var m := int(_load("arrival_mode", RoomSession.ArrivalMode.TURNS))
	return m as RoomSession.ArrivalMode if m in RoomSession.ArrivalMode.values() else RoomSession.ArrivalMode.TURNS


static func save_arrival_mode(mode: RoomSession.ArrivalMode) -> void:
	_save("arrival_mode", int(mode))


static func _load(key: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return default
	return cfg.get_value("general", key, default)


static func _save(key: String, value: Variant) -> void:
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
