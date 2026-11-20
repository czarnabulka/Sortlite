extends Control
## Renders the game into a 640×360 SubViewport, shows it scaled up with
## crisp pixels (whole-number scale when it fits) and runs the CRT shader on
## top. Input is forwarded to the game view in its own 640×360 coordinates.
##
## The game opens on the title screen (ui/menu_view.gd). ESC in a run pauses
## it and opens the same menu over it. `-- --demo`, `--seed`, `--skip` and
## `--controls` skip the title and start a run at once (for testing).

const BASE := Vector2i(640, 360)
const RunView := preload("res://ui/run_view.gd")
const MenuView := preload("res://ui/menu_view.gd")
const CrtShader := preload("res://ui/crt.gdshader")
const SKIP_TITLE_ARGS: Array[String] = ["--demo", "--seed", "--skip", "--controls"]

var viewport: SubViewport
var screen: TextureRect
## The run being played, or null on the title screen.
var view: RunView
var menu: MenuView
var crt: ShaderMaterial


func _ready() -> void:
	var lang := Settings.language_from_args()
	TranslationServer.set_locale(lang if lang != "" else Settings.load_language())
	_apply_fullscreen(Settings.load_fullscreen())
	add_child(Sfx.new())
	Sfx.set_volume(Settings.load_volume())

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	viewport = SubViewport.new()
	viewport.size = BASE
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	crt = ShaderMaterial.new()
	crt.shader = CrtShader
	crt.set_shader_parameter("source_size", Vector2(BASE))
	crt.set_shader_parameter("enabled", Settings.load_crt())

	menu = MenuView.new()
	menu.z_index = 200  # over the run, and over its fades
	menu.crt = Settings.load_crt()
	menu.fullscreen = Settings.load_fullscreen()
	menu.arrival_mode = Settings.load_arrival_mode()
	menu.volume = Settings.load_volume()
	menu.play_pressed.connect(func() -> void: start_run(false))
	menu.demo_pressed.connect(func() -> void: start_run(true))
	menu.resume_pressed.connect(resume)
	menu.title_pressed.connect(to_title)
	menu.quit_pressed.connect(func() -> void: get_tree().quit())
	menu.crt_changed.connect(func(on: bool) -> void: crt.set_shader_parameter("enabled", on))
	menu.fullscreen_changed.connect(_set_fullscreen)
	menu.arrival_mode_changed.connect(func(m: RoomSession.ArrivalMode) -> void:
		if view != null:
			view.set_arrival_mode(m))
	viewport.add_child(menu)

	screen = TextureRect.new()
	screen.texture = viewport.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.material = crt
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)

	get_viewport().size_changed.connect(_layout)
	_layout()

	var args := OS.get_cmdline_user_args()
	if SKIP_TITLE_ARGS.any(func(a: String) -> bool: return args.has(a)):
		start_run(false)
	else:
		menu.open(MenuView.Page.TITLE)


## A new run (or the bot's demo run) in place of whatever was there.
func start_run(demo: bool) -> void:
	_drop_run()
	view = RunView.new()
	view.demo = demo
	viewport.add_child(view)
	menu.visible = false


func to_title() -> void:
	_drop_run()
	menu.open(MenuView.Page.TITLE)


func pause() -> void:
	view.process_mode = Node.PROCESS_MODE_DISABLED  # the room clock stops too
	menu.open(MenuView.Page.PAUSE)


func resume() -> void:
	menu.visible = false
	if view != null:
		view.process_mode = Node.PROCESS_MODE_INHERIT


func _drop_run() -> void:
	if view != null:
		view.queue_free()
		view = null


## F11 or the settings: switch, remember, and show it in the menu.
func _set_fullscreen(on: bool) -> void:
	_apply_fullscreen(on)
	Settings.save_fullscreen(on)
	menu.fullscreen = on


func _apply_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func _layout() -> void:
	var win := get_viewport_rect().size
	var fit := minf(win.x / BASE.x, win.y / BASE.y)
	var scale_factor := floorf(fit) if fit >= 1.0 else fit
	var size_px := Vector2(BASE) * scale_factor
	screen.position = ((win - size_px) * 0.5).floor()
	screen.size = size_px


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if event.keycode == KEY_ESCAPE and not menu.visible and view != null:
			pause()
			return
	var local := Vector2.ZERO
	if event is InputEventMouse:
		local = (event.position - screen.position) / (screen.size.x / BASE.x)
	if menu.visible:
		menu.handle_input(event, local)
	elif view != null:
		view.handle_input(event, local)
