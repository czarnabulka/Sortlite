extends SceneTree
## Screenshots of the real game, for checking the UI without playing it.
## Runs the game in a window, sets up a screen, waits, saves a PNG (2× scale,
## without the CRT effect) and quits.
##
##   godot --path . -s res://tools/shot.gd -- --screen room --room 1 --moves 8 --lang pl --out shot.png
##
## --screen   title | settings | pause | room | reward (default room)
## --room N   room of the run plan, 0..7 (3 and 7 = the bosses, 4..7 = floor 2); room and pause only
## --moves N  moves the smart bot plays first (default 6)
## --items a,b,c   item ids the run holds (room and reward screens)
## --rules / --help / --intro   open the rules card / controls card / boss card
## --replace  on the reward screen with full slots: choosing the item to drop
## --sel N    selected row on the settings page
## --lang     en | pl (default en)
## --frame N  frame to capture at (default 90; animations need ~60+, an end card ~400)
## --out      PNG path (default user://shot.png)
##
## The run's seed is random, so which algorithm room 1 has can differ between
## shots. Settings are not changed.

var main: Node
var frames := 0
var args: PackedStringArray


func _arg(name: String, def: String) -> String:
	var i := args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else def


func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	var screen := _arg("--screen", "room")
	if frames == 3:
		TranslationServer.set_locale(_arg("--lang", "en"))
		if screen == "settings":
			main.menu.settings_from = main.MenuView.Page.TITLE
			main.menu.open(main.MenuView.Page.SETTINGS)
			main.menu.selected = int(_arg("--sel", "0"))
		elif screen in ["room", "pause", "reward"]:
			main.start_run(false)
			for id in _arg("--items", "").split(",", false):
				main.view.run.items.append(ItemCatalog.make(StringName(id)))
			if screen == "reward":
				main.view.run.cleared = int(_arg("--room", "1"))
				main.view._show_phase()
				if args.has("--replace"):
					main.view._pick(0)
					main.view.drop_slot = 1
	if frames == 5 and screen in ["room", "pause"]:
		var view = main.view
		view.run.cleared = int(_arg("--room", "1"))
		view.run.skip()
		view._show_phase()
		var rv = view.room_view
		rv.rules_open = args.has("--rules")
		rv.boss_intro_open = args.has("--intro")
		rv.help_open = args.has("--help")
		var s: RoomSession = view.run.session
		for i in int(_arg("--moves", "6")):
			var m := Bots.choose_in(s)
			if m.is_empty() or not s.play(m):
				s.deliver()
		if screen == "pause":
			main.pause()
	if frames == int(_arg("--frame", "90")):
		var img: Image = main.viewport.get_texture().get_image()
		img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		img.save_png(_arg("--out", "user://shot.png"))
		quit()
	return false
