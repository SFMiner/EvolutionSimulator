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
## Screen rect of the arena between the two side panels (window 1200 x 648, panels 200 px).
const ARENA_SCREEN: Rect2 = Rect2(200.0, 24.0, 800.0, 600.0)
## Arrow-key pan speed in screen px per second.
const KEY_PAN_SPEED: float = 400.0

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
		_hint.position = ARENA_SCREEN.position + Vector2(6.0, ARENA_SCREEN.size.y - 20.0)
		ui.add_child(_hint)
	var env_zoom: String = OS.get_environment("EVO_ZOOM")  # screenshot gate: start zoomed in at the centre
	if env_zoom.is_valid_float():
		set_zoom_level(env_zoom.to_float())
	_update_hint()


## Opaque strips around the arena, drawn under the panels: zoomed in, the world would otherwise show
## behind the (partly transparent) side panels and above and below the arena.
func _add_frame(ui: Node) -> void:
	var view: Vector2 = get_viewport_rect().size
	var color: Color = RenderingServer.get_default_clear_color()
	var a: Rect2 = ARENA_SCREEN
	var strips: Array[Rect2] = [
		Rect2(0.0, 0.0, a.position.x, view.y),  # left
		Rect2(a.end.x, 0.0, view.x - a.end.x, view.y),  # right
		Rect2(a.position.x, 0.0, a.size.x, a.position.y),  # top
		Rect2(a.position.x, a.end.y, a.size.x, view.y - a.end.y),  # bottom
	]
	for strip: Rect2 in strips:
		var rect: ColorRect = ColorRect.new()
		rect.color = color
		rect.position = strip.position
		rect.size = strip.size
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(rect)
		ui.move_child(rect, 0)


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
	return zoom.x


func set_zoom_level(level: float, screen_point: Vector2 = Vector2(-1.0, -1.0)) -> void:
	var old_level: float = zoom.x
	var new_level: float = clampf(level, ZOOM_MIN, ZOOM_MAX)
	var offset: Vector2 = Vector2.ZERO
	if screen_point.x >= 0.0:
		offset = screen_point - get_viewport_rect().size * 0.5
	position = clamp_center(zoom_about(position, old_level, new_level, offset), new_level)
	zoom = Vector2(new_level, new_level)
	_update_hint()


func reset_view() -> void:
	zoom = Vector2.ONE
	position = Vector2.ZERO
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.pressed and ARENA_SCREEN.has_point(button.position):
			if button.button_index == MOUSE_BUTTON_WHEEL_UP:
				set_zoom_level(zoom.x * ZOOM_STEP, button.position)
				get_viewport().set_input_as_handled()
			elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				set_zoom_level(zoom.x / ZOOM_STEP, button.position)
				get_viewport().set_input_as_handled()
		if button.button_index == MOUSE_BUTTON_RIGHT or button.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = button.pressed and ARENA_SCREEN.has_point(button.position)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		position = clamp_center(position - motion.relative / zoom.x, zoom.x)
		return
	var pinch: InputEventMagnifyGesture = event as InputEventMagnifyGesture
	if pinch != null:
		set_zoom_level(zoom.x * pinch.factor, pinch.position)
		return
	var pan: InputEventPanGesture = event as InputEventPanGesture
	if pan != null:
		position = clamp_center(position + pan.delta * 4.0 / zoom.x, zoom.x)
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed:
		match key.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				set_zoom_level(zoom.x * ZOOM_STEP)
				get_viewport().set_input_as_handled()
			KEY_MINUS, KEY_KP_SUBTRACT:
				set_zoom_level(zoom.x / ZOOM_STEP)
				get_viewport().set_input_as_handled()
			KEY_0, KEY_KP_0:
				reset_view()
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Arrow keys pan (only when zoomed; a focused slider gets the arrows first via the GUI)
	if zoom.x <= ZOOM_MIN:
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
	position = clamp_center(position + dir * KEY_PAN_SPEED * real_delta / zoom.x, zoom.x)


func _update_hint() -> void:
	# Keep lizard labels at their normal on-screen size (Organism reads the zoom when it spawns)
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("organisms"):
			if node.has_method("apply_label_zoom"):
				node.apply_label_zoom(zoom.x)
	if _hint == null:
		return
	if zoom.x <= ZOOM_MIN + 0.001:
		_hint.text = "Scroll or + to zoom  ·  click a lizard or press N to inspect  ·  Space pauses  ·  Tab: controls"
	else:
		_hint.text = "Zoom %.1fx  ·  right-drag or arrows to move  ·  0 to reset" % zoom.x
