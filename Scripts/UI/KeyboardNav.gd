class_name KeyboardNav
extends Node
## Keyboard use and the keyboard exit for the sims site (SPEC §6, docs/game-keyboard-exit.md there).
## Tab walks the controls in panel order; Tab past the last or Shift+Tab before the first leaves the game.
## Escape closes the lizard box if it is open, otherwise leaves. With no control focused, Space pauses and
## N inspects the next lizard. Lives in the UI layer (process ALWAYS), so it works while paused.

const FOCUS_COLOR: Color = Color(1.0, 0.85, 0.2)

## Times the keyboard left the game; read by tests/test_keyboard.gd.
var leave_count: int = 0

var _controls: Array[Control] = []
var _inspector: Node = null
var _pause_button: Button = null
var _ring: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ring = StyleBoxFlat.new()
	_ring.draw_center = false
	_ring.border_color = FOCUS_COLOR
	_ring.set_border_width_all(2)
	_ring.set_corner_radius_all(3)
	_ring.set_expand_margin_all(2.0)


## Controls in Tab order. Buttons get a bright focus outline; sliders, which only brighten their grabber, get the
## same outline drawn round them.
func setup(controls: Array[Control], inspector: Node, pause_button: Button) -> void:
	_controls = controls
	_inspector = inspector
	_pause_button = pause_button
	for i: int in range(_controls.size()):
		var c: Control = _controls[i]
		c.focus_mode = Control.FOCUS_ALL
		var next: Control = _controls[(i + 1) % _controls.size()]
		var prev: Control = _controls[(i - 1 + _controls.size()) % _controls.size()]
		c.focus_next = c.get_path_to(next)
		c.focus_previous = c.get_path_to(prev)
		if c is Slider:
			_draw_ring(c)
		else:
			c.add_theme_stylebox_override("focus", _ring)


func _draw_ring(c: Control) -> void:
	c.draw.connect(func() -> void:
		if c.has_focus():
			c.draw_style_box(_ring, Rect2(Vector2.ZERO, c.size).grow_individual(2.0, 0.0, 2.0, 0.0)))
	c.focus_entered.connect(c.queue_redraw)
	c.focus_exited.connect(c.queue_redraw)


func _input(event: InputEvent) -> void:
	# In _input, not _unhandled_input: the GUI takes Tab for its own focus movement before that.
	# An open OptionButton list is its own popup window, so its Escape closes it and never gets here.
	if _controls.is_empty() or not (event is InputEventKey and event.pressed):
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	var leave: bool = false
	if event.is_action_pressed("ui_cancel"):
		if _inspector != null and _inspector.selected() != null:
			_inspector.select(null)
			get_viewport().set_input_as_handled()
			return
		leave = true
	# Exact match (third argument): without it ui_focus_next also matches Shift+Tab
	elif event.is_action_pressed("ui_focus_next", true, true):
		if focus == null:
			_controls[0].grab_focus()
			get_viewport().set_input_as_handled()
			return
		leave = focus == _controls[-1]
	elif event.is_action_pressed("ui_focus_prev", true, true):
		if focus == null:
			_controls[-1].grab_focus()
			get_viewport().set_input_as_handled()
			return
		leave = focus == _controls[0]
	if leave:
		leave_game()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			# A focused button takes Space itself (presses it), so this only runs with nothing focused
			if _pause_button != null:
				_pause_button.pressed.emit()
				get_viewport().set_input_as_handled()
		KEY_N:
			if _inspector != null:
				_inspector.select_next()
				get_viewport().set_input_as_handled()


## Drops focus and asks the sims site's play page to take the keyboard back. On its own page there is no parent.
func leave_game() -> void:
	get_viewport().gui_release_focus()
	leave_count += 1
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
				"if (window.parent !== window) window.parent.postMessage({type: 'sims:leave-game'}, location.origin)")
