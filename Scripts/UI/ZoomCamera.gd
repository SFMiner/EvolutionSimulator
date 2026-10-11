class_name ZoomCamera
extends Camera2D
## Zoom and pan over the arena so the small lizards and insects can be seen up close.
## Mouse wheel (or trackpad pinch) zooms toward the cursor; right- or middle-drag pans; + / - zoom,
## arrow keys pan and 0 resets. Works while paused (process_mode ALWAYS). The view never leaves the arena.

const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 5.0
const ZOOM_STEP: float = 1.25
## Arena half-size in world px (EnvironmentManager spawns in 800 x 600 around the origin).
const ARENA_HALF: Vector2 = Vector2(400.0, 300.0)
## Screen rect of the arena at the base size (1200 x 648, panels 200 px). ResponsiveLayout moves and resizes it
## for small frames through set_arena_screen().
const ARENA_SCREEN: Rect2 = Rect2(200.0, 24.0, 800.0, 600.0)
## Arrow-key pan speed in screen px per second.
const KEY_PAN_SPEED: float = 400.0

## Where the arena is drawn now (base px), and the camera zoom that fits it there (1 at the base size).
## zoom_level() is relative to that fit: 1 shows the whole arena.
var arena_screen: Rect2 = ARENA_SCREEN
var _fit_zoom: float = 1.0
var _view: Vector2 = Vector2(1200.0, 648.0)
var _strips: Array[ColorRect] = []
var _dragging: bool = false
var _hint: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ui: Node = get_node_or_null("../UI")
	if ui != null:
		_add_frame(ui)
		_hint = Label.new()
		_hint.add_theme_font_size_override("font_size", 12)
		_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui.add_child(_hint)
	set_arena_screen(ARENA_SCREEN, get_viewport_rect().size)
	var env_zoom: String = OS.get_environment("EVO_ZOOM")  # screenshot gate: start zoomed in at the centre
	if env_zoom.is_valid_float():
		set_zoom_level(env_zoom.to_float())
	_update_hint()


## Opaque strips around the arena, drawn under the panels: zoomed in, the world would otherwise show
## behind the (partly transparent) side panels and above and below the arena.
func _add_frame(ui: Node) -> void:
	var color: Color = RenderingServer.get_default_clear_color()
	for i: int in range(4):
		var rect: ColorRect = ColorRect.new()
		rect.color = color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(rect)
		ui.move_child(rect, 0)
		_strips.append(rect)


## Draw the arena in `rect` (base px) of a `view`-sized screen: fits the zoom, the frame strips and the hint.
## Keeps the current zoom level and view centre.
func set_arena_screen(rect: Rect2, view: Vector2) -> void:
	var level: float = zoom_level()
	arena_screen = rect
	_view = view
	_fit_zoom = rect.size.x / (ARENA_HALF.x * 2.0)
	if _strips.size() == 4:
		var a: Rect2 = rect
		var strips: Array[Rect2] = [
			Rect2(0.0, 0.0, a.position.x, view.y),  # left
			Rect2(a.end.x, 0.0, view.x - a.end.x, view.y),  # right
			Rect2(a.position.x, 0.0, a.size.x, a.position.y),  # top
			Rect2(a.position.x, a.end.y, a.size.x, view.y - a.end.y),  # bottom
		]
		for i: int in range(4):
			_strips[i].position = strips[i].position
			_strips[i].size = strips[i].size
	_set_level(level)
	_update_hint()


## Camera zoom for `level`, and the offset that puts the camera centre in the middle of the arena rect
## (not the middle of the screen). The offset is in world px, so it changes with the zoom.
func _set_level(level: float) -> void:
	zoom = Vector2.ONE * level * _fit_zoom
	offset = (_view * 0.5 - arena_screen.get_center()) / zoom.x


## Camera centre that keeps a view at `level` inside the arena.
static func clamp_center(center: Vector2, level: float) -> Vector2:
	var half_view: Vector2 = ARENA_HALF / level
	return Vector2(
			clampf(center.x, -ARENA_HALF.x + half_view.x, ARENA_HALF.x - half_view.x),
			clampf(center.y, -ARENA_HALF.y + half_view.y, ARENA_HALF.y - half_view.y))


## New camera centre after zooming from `old_level` to `new_level` so the world point under
## `screen_offset` (cursor position relative to the screen centre) stays under the cursor.
static func zoom_about(center: Vector2, old_level: float, new_level: float, screen_offset: Vector2) -> Vector2:
	var world: Vector2 = center + screen_offset / old_level
	return world - screen_offset / new_level


func zoom_level() -> float:
	return zoom.x / _fit_zoom


func set_zoom_level(level: float, screen_point: Vector2 = Vector2(-1.0, -1.0)) -> void:
	var old_level: float = zoom_level()
	var new_level: float = clampf(level, ZOOM_MIN, ZOOM_MAX)
	var from_center: Vector2 = Vector2.ZERO
	if screen_point.x >= 0.0:
		from_center = (screen_point - arena_screen.get_center()) / _fit_zoom
	position = clamp_center(zoom_about(position, old_level, new_level, from_center), new_level)
	_set_level(new_level)
	_update_hint()


func reset_view() -> void:
	_set_level(1.0)
	position = Vector2.ZERO
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.pressed and arena_screen.has_point(button.position):
			if button.button_index == MOUSE_BUTTON_WHEEL_UP:
				set_zoom_level(zoom_level() * ZOOM_STEP, button.position)
				get_viewport().set_input_as_handled()
			elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				set_zoom_level(zoom_level() / ZOOM_STEP, button.position)
				get_viewport().set_input_as_handled()
		if button.button_index == MOUSE_BUTTON_RIGHT or button.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = button.pressed and arena_screen.has_point(button.position)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		position = clamp_center(position - motion.relative / zoom.x, zoom_level())
		return
	var pinch: InputEventMagnifyGesture = event as InputEventMagnifyGesture
	if pinch != null:
		set_zoom_level(zoom_level() * pinch.factor, pinch.position)
		return
	var pan: InputEventPanGesture = event as InputEventPanGesture
	if pan != null:
		position = clamp_center(position + pan.delta * 4.0 / zoom.x, zoom_level())
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed:
		match key.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				set_zoom_level(zoom_level() * ZOOM_STEP)
				get_viewport().set_input_as_handled()
			KEY_MINUS, KEY_KP_SUBTRACT:
				set_zoom_level(zoom_level() / ZOOM_STEP)
				get_viewport().set_input_as_handled()
			KEY_0, KEY_KP_0:
				reset_view()
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Arrow keys pan (only when zoomed; a focused slider gets the arrows first via the GUI)
	if zoom_level() <= ZOOM_MIN + 0.001:
		return
	var dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir == Vector2.ZERO or get_viewport().gui_get_focus_owner() != null:
		return
	# Real seconds, so panning speed does not change with the simulation speed
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	position = clamp_center(position + dir * KEY_PAN_SPEED * real_delta / zoom.x, zoom_level())


func _update_hint() -> void:
	# Keep lizard labels at their normal on-screen size (Organism reads the zoom when it spawns)
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("organisms"):
			if node.has_method("apply_label_zoom"):
				node.apply_label_zoom(zoom.x)
	if _hint == null:
		return
	if zoom_level() <= ZOOM_MIN + 0.001:
		_hint.text = "Scroll or + to zoom  ·  click a lizard or press N to inspect  ·  Space pauses  ·  Tab: controls"
	else:
		_hint.text = "Zoom %.1fx  ·  right-drag or arrows to move  ·  0 to reset" % zoom_level()
	# Bottom left of the arena; wraps upward when the arena is narrow
	_hint.size = Vector2(arena_screen.size.x - 12.0, 0.0)
	var text_height: float = float(_hint.get_line_count() * _hint.get_line_height())
	_hint.position = Vector2(arena_screen.position.x + 6.0, arena_screen.end.y - text_height - 4.0)
