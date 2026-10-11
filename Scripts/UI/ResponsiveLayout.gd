class_name ResponsiveLayout
extends Node
## Fits the screen to the frame the game runs in: a wide window, a short iframe on the sims site, or a phone.
## The base layout is 1200 x 648: allele panel | 800 x 600 arena | controls over the population graph.
## Scaled down whole, a 360 px frame drew text at about 8 px. Instead the UI never goes below MIN_UI_SCALE
## (screen px per base px, CSS px on the web), the arena shrinks to fit the room left, and a panel that no
## longer fits scrolls. In a tall frame the arena goes on top with the two panels side by side under it.

const BASE_SIZE: Vector2 = Vector2(1200.0, 648.0)
## Smallest UI scale: base text of 13-16 px stays 11-14 px on screen.
const MIN_UI_SCALE: float = 0.85
## The view is always at least this wide in base px, so the two panels (200 px plus a scroll bar each) fit side by side.
const MIN_VIEW_WIDTH: float = 440.0
const ARENA_SIZE: Vector2 = Vector2(800.0, 600.0)
const COLUMN_WIDTH: float = 200.0
## Room a column's scroll bar takes when its content is taller than the column.
const SCROLLBAR_WIDTH: float = 12.0
## Content heights: the allele panel's text ends near y 545; controls 404 + gap 10 + population graph 230.
const LEFT_CONTENT_HEIGHT: float = 560.0
const RIGHT_GAP: float = 10.0
const CONTROL_PANEL_HEIGHT: float = 404.0
const GRAPH_HEIGHT: float = 230.0
const RIGHT_CONTENT_HEIGHT: float = CONTROL_PANEL_HEIGHT + RIGHT_GAP + GRAPH_HEIGHT
## Tall layout: the least height kept for the panels under the arena, and the gap between the two panels.
const MIN_PANEL_HEIGHT: float = 240.0
const PANEL_GAP: float = 8.0

var _left: ScrollContainer
var _right: ScrollContainer
var _camera: ZoomCamera
var _applying: bool = false


## Screen px per base px for a window (physical px) on a screen with `dpr` physical px per CSS px.
static func view_scale(window: Vector2, dpr: float) -> float:
	var fit: float = minf(window.x / BASE_SIZE.x, window.y / BASE_SIZE.y)
	return minf(maxf(fit, MIN_UI_SCALE * dpr), window.x / MIN_VIEW_WIDTH)


static func _column_width(content_height: float, column_height: float) -> float:
	return COLUMN_WIDTH + (SCROLLBAR_WIDTH if content_height > column_height + 0.5 else 0.0)


## Where everything goes in a view of `view` base px: {"tall", "arena", "left", "right"} (Rect2s in base px).
## Picks whichever of the wide and tall layouts shows the arena bigger.
static func plan(view: Vector2) -> Dictionary:
	var left_w: float = _column_width(LEFT_CONTENT_HEIGHT, view.y)
	var right_w: float = _column_width(RIGHT_CONTENT_HEIGHT, view.y)
	var wide_zoom: float = minf((view.x - left_w - right_w) / ARENA_SIZE.x, view.y / ARENA_SIZE.y)
	var tall_arena_h: float = minf(view.x * ARENA_SIZE.y / ARENA_SIZE.x, view.y - MIN_PANEL_HEIGHT)
	var tall_zoom: float = minf(view.x / ARENA_SIZE.x, tall_arena_h / ARENA_SIZE.y)
	if wide_zoom >= tall_zoom:
		var arena_size: Vector2 = ARENA_SIZE * wide_zoom
		var x0: float = floorf((view.x - left_w - arena_size.x - right_w) * 0.5)
		var arena: Rect2 = Rect2(x0 + left_w, floorf((view.y - arena_size.y) * 0.5), arena_size.x, arena_size.y)
		return {
			"tall": false,
			"arena": arena,
			"left": Rect2(x0, 0.0, left_w, view.y),
			"right": Rect2(arena.end.x, 0.0, right_w, view.y),
		}
	var size: Vector2 = ARENA_SIZE * tall_zoom
	var top_arena: Rect2 = Rect2(maxf(0.0, floorf((view.x - size.x) * 0.5)), 0.0, size.x, size.y)
	var panel_top: float = top_arena.end.y + 4.0
	var panel_h: float = view.y - panel_top
	var lw: float = _column_width(LEFT_CONTENT_HEIGHT, panel_h)
	var rw: float = _column_width(RIGHT_CONTENT_HEIGHT, panel_h)
	var px: float = floorf((view.x - lw - PANEL_GAP - rw) * 0.5)
	return {
		"tall": true,
		"arena": top_arena,
		"left": Rect2(px, panel_top, lw, panel_h),
		"right": Rect2(px + lw + PANEL_GAP, panel_top, rw, panel_h),
	}


## Moves the allele panel, the control panel and the population graph into two scrolling columns and lays
## them out now and whenever the window changes size.
func setup(ui: CanvasLayer, allele_graph: Control, control_panel: Control, population_graph: Control, camera: ZoomCamera) -> void:
	_camera = camera
	_left = _make_column(ui, "LeftColumn")
	allele_graph.reparent(_left, false)
	allele_graph.custom_minimum_size = Vector2(COLUMN_WIDTH, LEFT_CONTENT_HEIGHT)
	allele_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right = _make_column(ui, "RightColumn")
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", int(RIGHT_GAP))
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_child(stack)
	control_panel.reparent(stack, false)
	control_panel.custom_minimum_size = Vector2(COLUMN_WIDTH, CONTROL_PANEL_HEIGHT)
	# Let the mouse wheel over the panel reach the scroll column
	control_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	population_graph.reparent(stack, false)
	population_graph.custom_minimum_size = Vector2(COLUMN_WIDTH, GRAPH_HEIGHT)
	# Main.tscn gave it z_index -1, which drew it under ZoomCamera's frame strips: it was never visible
	population_graph.z_index = 0
	get_tree().root.size_changed.connect(apply)
	apply()


func _make_column(ui: CanvasLayer, column_name: String) -> ScrollContainer:
	var column: ScrollContainer = ScrollContainer.new()
	column.name = column_name
	column.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.follow_focus = true  # Tab scrolls the focused control into view
	ui.add_child(column)
	return column


func apply() -> void:
	if _applying:
		return
	_applying = true
	var win: Window = get_window()
	var window_size: Vector2 = Vector2(win.size)
	if window_size.x >= 1.0 and window_size.y >= 1.0:
		var s: float = view_scale(window_size, DisplayServer.screen_get_scale())
		win.content_scale_size = Vector2i((window_size / s).floor())
	var view: Vector2 = get_viewport().get_visible_rect().size
	var p: Dictionary = plan(view)
	_place(_left, p["left"])
	_place(_right, p["right"])
	_camera.set_arena_screen(p["arena"], view)
	_applying = false


func _place(column: Control, rect: Rect2) -> void:
	column.position = rect.position
	column.size = rect.size
