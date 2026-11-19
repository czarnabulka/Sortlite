class_name Settings
extends RefCounted
## Player settings kept between sessions in user://settings.cfg.

const PATH := "user://settings.cfg"
const LANGUAGES: Array[String] = ["en", "pl"]
const DEFAULT_LANGUAGE := "en"


static func load_language() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return DEFAULT_LANGUAGE
	var lang := str(cfg.get_value("general", "language", DEFAULT_LANGUAGE))
	return lang if LANGUAGES.has(lang) else DEFAULT_LANGUAGE


static func save_language(lang: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # keep other values; a missing file is fine
	cfg.set_value("general", "language", lang)
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
