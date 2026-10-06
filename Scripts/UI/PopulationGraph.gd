extends Control

# This script handles drawing the population graph
# It's attached to a Control node in the UI CanvasLayer

var population_count: int = 0
var font: Font

# Rolling history for simple line graph
var population_history: Array[float] = []
var max_points: int = 100

# Removed time-based sampling (rolled back per request)

func _ready():
	# Get the fallback font
	font = ThemeDB.fallback_font
	if font == null:
		print("WARNING: No fallback font available for graph!")
	else:
		print("Graph font available: ", font)
	# Align below the control panel after layout settles
	call_deferred("_align_to_control_panel")

func _align_to_control_panel():
	var panel = get_parent().get_node("ControlPanel")
	if panel != null and panel is Control:
		var ctrl := panel as Control
		# Use absolute positioning for predictable placement
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = Vector2(ctrl.position.x, ctrl.position.y + ctrl.size.y + 10.0)
		size = Vector2(ctrl.size.x, size.y)  # match panel width, keep current height
		z_index = -1
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_population(count: int):
	population_count = count
	population_history.append(float(count))
	if population_history.size() > max_points:
		population_history.pop_front()
	queue_redraw()

func update_population_time(time_sec: float, count: int):
	# Backward-compat shim; simply call update_population
	update_population(count)

func _process(delta: float) -> void:
	# No-op after rollback; keep for future
	pass

func _draw():
	# Get the size of this control node
	var size = get_size()
	
	# Legend metrics (we reserve space BELOW the graph)
	var legend_line_h = 16.0
	var legend_lines = 3
	var legend_gap_top = 6.0
	var legend_height = legend_lines * legend_line_h + legend_gap_top
	
	# Layout margins (leave room for legend at bottom)
	var margin_left = 30.0
	var margin_right = 10.0
	var margin_top = 10.0
	var margin_bottom = 10.0 + legend_height
	var content_rect = Rect2(margin_left, margin_top, max(1.0, size.x - margin_left - margin_right), max(1.0, size.y - margin_top - margin_bottom))
	
	# Draw background
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(content_rect, Color(0.3, 0.3, 0.3, 0.2), false, 2.0)
	
	# Scale based on current population
	var current_pop = float(population_count)
	var min_pop = 0.0
	var max_pop = max(10.0, current_pop, _get_history_max())
	
	# Grid lines and labels
	for i in range(6):  # 0..5 -> 0..100%
		var y_ratio = 1.0 - float(i) / 5.0
		var y_pos = content_rect.position.y + content_rect.size.y * y_ratio
		var pop_value = min_pop + (max_pop - min_pop) * float(i) / 5.0
		draw_line(Vector2(content_rect.position.x, y_pos), Vector2(content_rect.position.x + content_rect.size.x, y_pos), Color(0.8, 0.8, 0.8), 1.0)
		if font != null:
			var label_text = str(int(pop_value))
			draw_string(font, Vector2(5, y_pos + 4), label_text, HORIZONTAL_ALIGNMENT_LEFT)

	# Time-series population line (green) using last max_points samples
	if population_history.size() >= 2:
		var points: PackedVector2Array = PackedVector2Array()
		var step_x = content_rect.size.x / float(max(1, max_points - 1))
		var start_index = max(0, population_history.size() - max_points)
		for i in range(start_index, population_history.size()):
			var idx_in_window = i - start_index
			var x = content_rect.position.x + step_x * float(idx_in_window)
			var value = population_history[i]
			var y = content_rect.position.y + content_rect.size.y * (1.0 - (value - min_pop) / (max_pop - min_pop))
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.0, 1.0, 0.0), 2.0, true)

	# Current population horizontal line (yellow)
	var current_y = content_rect.position.y + content_rect.size.y * (1.0 - (current_pop - min_pop) / (max_pop - min_pop))
	draw_line(Vector2(content_rect.position.x, current_y), Vector2(content_rect.position.x + content_rect.size.x, current_y), Color.YELLOW, 3.0)

	# Legend BELOW the graph at the left edge (stacked vertically)
	var legend_x = content_rect.position.x + 4
	var legend_y0 = content_rect.position.y + content_rect.size.y + legend_gap_top
	# Yellow - current population
	draw_rect(Rect2(legend_x, legend_y0, 10, 10), Color.YELLOW)
	if font != null:
		draw_string(font, Vector2(legend_x + 15, legend_y0 + 9), "Current Population", HORIZONTAL_ALIGNMENT_LEFT)
	# Green - population over time
	var legend_y1 = legend_y0 + legend_line_h
	draw_rect(Rect2(legend_x, legend_y1, 10, 10), Color(0.0, 1.0, 0.0))
	if font != null:
		draw_string(font, Vector2(legend_x + 15, legend_y1 + 9), "Population Line", HORIZONTAL_ALIGNMENT_LEFT)
	# White - grid lines
	var legend_y2 = legend_y1 + legend_line_h
	draw_rect(Rect2(legend_x, legend_y2, 10, 10), Color.WHITE)
	if font != null:
		draw_string(font, Vector2(legend_x + 15, legend_y2 + 9), "Grid Lines", HORIZONTAL_ALIGNMENT_LEFT)

func _get_history_max() -> float:
	var max_val: float = 0.0
	for v in population_history:
		if v > max_val:
			max_val = v
	return max_val
