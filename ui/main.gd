extends Control
## Renders the game into a 640×360 SubViewport, shows it scaled up with
## crisp pixels (whole-number scale when it fits) and runs the CRT shader on
## top. Input is forwarded to the game view in its own 640×360 coordinates.

const BASE := Vector2i(640, 360)
const RoomView := preload("res://ui/room_view.gd")
const CrtShader := preload("res://ui/crt.gdshader")

var viewport: SubViewport
var screen: TextureRect
var view: RoomView
var crt: ShaderMaterial


func _ready() -> void:
	var lang := Settings.language_from_args()
	TranslationServer.set_locale(lang if lang != "" else Settings.load_language())

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

	view = RoomView.new()
	viewport.add_child(view)

	crt = ShaderMaterial.new()
	crt.shader = CrtShader
	crt.set_shader_parameter("source_size", Vector2(BASE))

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


func _layout() -> void:
	var win := get_viewport_rect().size
	var fit := minf(win.x / BASE.x, win.y / BASE.y)
	var scale_factor := floorf(fit) if fit >= 1.0 else fit
	var size_px := Vector2(BASE) * scale_factor
	screen.position = ((win - size_px) * 0.5).floor()
	screen.size = size_px


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F11:
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
				return
			KEY_C:
				crt.set_shader_parameter("enabled", not bool(crt.get_shader_parameter("enabled")))
				return
			KEY_L:
				var next := Settings.next_language(TranslationServer.get_locale().substr(0, 2))
				TranslationServer.set_locale(next)
				Settings.save_language(next)
				return
			KEY_ESCAPE:
				get_tree().quit()
				return
	var local := Vector2.ZERO
	if event is InputEventMouse:
		local = (event.position - screen.position) / (screen.size.x / BASE.x)
	view.handle_input(event, local)
