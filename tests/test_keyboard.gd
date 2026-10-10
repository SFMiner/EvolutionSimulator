extends SceneTree
## Keyboard use and the sims-site keyboard exit (SPEC §6): Tab walks every control in order, Tab past the last
## and Shift+Tab before the first leave the game, Escape closes the lizard box first and then leaves, Space
## pauses with nothing focused, N inspects a lizard, arrows move a focused slider, Enter cycles the speed.

const EXPECTED_STOPS: int = 11

var _passed: int = 0
var _failed: int = 0
var _main: Node = null
var _config: Node = null


func _init() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + label)


func _run() -> void:
	await get_root().ready
	_config = get_root().get_node("/root/GameConfig")
	_main = (load("res://Scenes/Main.tscn") as PackedScene).instantiate()
	get_root().add_child(_main)
	for i: int in range(5):
		await process_frame
	var nav: Node = _main.keyboard
	_check(nav != null, "KeyboardNav is set up")
	if nav == null:
		_finish()
		return

	# Tab from nothing focused walks the controls, then leaves past the last one
	var stops: Array[Control] = []
	var before: int = nav.leave_count
	for i: int in range(EXPECTED_STOPS + 5):
		await _key(KEY_TAB)
		var f: Control = get_root().gui_get_focus_owner()
		if f == null:
			break
		stops.append(f)
	_check(stops.size() == EXPECTED_STOPS, "Tab reaches %d controls (got %d)" % [EXPECTED_STOPS, stops.size()])
	_check(nav.leave_count == before + 1, "Tab past the last control leaves the game")
	_check(get_root().gui_get_focus_owner() == null, "focus is released after leaving")
	if stops.size() == EXPECTED_STOPS:
		_check(stops[0] == _main.spawn_button, "first stop is Spawn")
		_check(stops[2] == _main.speed_button, "third stop is Speed")
		_check(stops[4] == _main.mutation_slider, "fifth stop is the mutation slider")
		_check(stops[-1] == _main.allele_graph.locus_option(), "last stop is the gene picker")

	# Shift+Tab from nothing focused starts at the last control and walks back; before the first, it leaves
	before = nav.leave_count
	var back: int = 0
	for i: int in range(EXPECTED_STOPS + 5):
		await _key(KEY_TAB, true)
		if get_root().gui_get_focus_owner() == null:
			break
		back += 1
	_check(back == EXPECTED_STOPS, "Shift+Tab walks the same controls backwards (got %d)" % back)
	_check(nav.leave_count == before + 1, "Shift+Tab before the first control leaves the game")

	# Shift+Tab on the last control moves back instead of leaving (exact-match check)
	_main.allele_graph.locus_option().grab_focus()
	before = nav.leave_count
	await _key(KEY_TAB, true)
	_check(nav.leave_count == before and get_root().gui_get_focus_owner() == _main.labels_check, "Shift+Tab on the last control moves back")

	# Escape from a control in the middle leaves
	_main.food_slider.grab_focus()
	before = nav.leave_count
	await _key(KEY_ESCAPE)
	_check(nav.leave_count == before + 1, "Escape leaves the game")
	_check(get_root().gui_get_focus_owner() == null, "focus is released after Escape")

	# N opens the lizard box; Escape closes it first, a second Escape leaves
	# The founders are still eggs this early; N skips eggs, so mark two as hatched
	var marked: int = 0
	for node: Node in _main.organism_container.get_children():
		if marked < 2 and "current_state" in node:
			node.current_state = "juvenile"
			marked += 1
	await _key(KEY_N)
	_check(_main.inspector.selected() != null, "N inspects a lizard")
	var first: Object = _main.inspector.selected()
	await _key(KEY_N)
	_check(_main.inspector.selected() != null and _main.inspector.selected() != first, "N again moves to another lizard")
	before = nav.leave_count
	await _key(KEY_ESCAPE)
	_check(_main.inspector.selected() == null and nav.leave_count == before, "Escape closes the lizard box without leaving")
	await _key(KEY_ESCAPE)
	_check(nav.leave_count == before + 1, "a second Escape leaves")

	# Space with nothing focused pauses and resumes
	var paused: bool = _main.is_paused
	await _key(KEY_SPACE)
	_check(_main.is_paused != paused, "Space pauses with nothing focused")
	await _key(KEY_SPACE)
	_check(_main.is_paused == paused, "Space again resumes")

	# Arrows move a focused slider
	_main.mutation_slider.grab_focus()
	var v: float = _main.mutation_slider.value
	await _key(KEY_RIGHT)
	_check(_main.mutation_slider.value > v, "Right arrow raises the focused slider")
	await _key(KEY_LEFT)
	_check(is_equal_approx(_main.mutation_slider.value, v), "Left arrow lowers it back")

	# Enter on the speed button cycles 1x -> 2x -> 4x -> 1x
	_main.speed_button.grab_focus()
	await _key(KEY_ENTER)
	_check(_main.speed_button.text == "2x" and is_equal_approx(Engine.time_scale, 2.0), "Enter sets 2x speed")
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)
	_check(_main.speed_button.text == "1x" and is_equal_approx(Engine.time_scale, 1.0), "three presses come back to 1x")

	# Every stop has a visible focus outline (buttons via the theme override, sliders draw their own)
	for c: Control in stops:
		if not (c is Slider):
			_check(c.has_theme_stylebox_override("focus"), "%s has the focus outline" % c.name)
	_finish()


func _finish() -> void:
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _key(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.shift_pressed = shift
		e.pressed = pressed
		get_root().push_input(e)
	await process_frame
	await process_frame
