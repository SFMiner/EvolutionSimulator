extends SceneTree
## Small-frame layout: text never shrinks below the minimum, the arena and the panels never overlap, and the
## camera draws the arena centre in the middle of the arena rect.

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + label)


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.5


func _no_overlap(p: Dictionary) -> bool:
	var arena: Rect2 = p["arena"]
	var left: Rect2 = p["left"]
	var right: Rect2 = p["right"]
	# Rect2.intersects counts touching edges as overlap only with include_borders
	return not arena.intersects(left) and not arena.intersects(right) and not left.intersects(right)


func _inside(r: Rect2, view: Vector2) -> bool:
	return r.position.x >= -0.01 and r.position.y >= -0.01 and r.end.x <= view.x + 0.01 and r.end.y <= view.y + 0.01


func _run() -> void:
	await get_root().ready

	# The base window keeps the original layout exactly
	var base: Dictionary = ResponsiveLayout.plan(ResponsiveLayout.BASE_SIZE)
	_check(not base["tall"], "1200 x 648 uses the wide layout")
	_check(base["arena"] == ZoomCamera.ARENA_SCREEN, "1200 x 648 keeps the arena at (200, 24) 800 x 600 (got %s)" % str(base["arena"]))
	_check(is_equal_approx(ResponsiveLayout.view_scale(Vector2(1200, 648), 1.0), 1.0), "1200 x 648 draws at scale 1")

	# Frames from the site: (window px, device px per CSS px, expect tall)
	var frames: Array = [
		[Vector2(1280, 360), 1.0, false],  # shortest iframe on a wide screen
		[Vector2(1366, 487), 1.0, false],  # laptop, 75vh
		[Vector2(390, 600), 1.0, true],  # phone portrait (CSS px)
		[Vector2(1170, 1800), 3.0, true],  # the same phone in device px
		[Vector2(844, 360), 1.0, false],  # phone landscape
		[Vector2(320, 480), 1.0, true],  # smallest phone
		[Vector2(1920, 1080), 1.0, false],  # full screen
	]
	for f: Array in frames:
		var window: Vector2 = f[0]
		var dpr: float = f[1]
		var s: float = ResponsiveLayout.view_scale(window, dpr)
		var view: Vector2 = window / s
		var p: Dictionary = ResponsiveLayout.plan(view)
		var tag: String = "%dx%d@%.0f" % [int(window.x), int(window.y), dpr]
		var narrowest: bool = view.x <= ResponsiveLayout.MIN_VIEW_WIDTH + 0.5
		_check(s / dpr >= ResponsiveLayout.MIN_UI_SCALE - 0.001 or narrowest, tag + ": text at least the minimum scale (%.2f)" % (s / dpr))
		_check(bool(p["tall"]) == bool(f[2]), tag + ": %s layout" % ("tall" if f[2] else "wide"))
		_check(_no_overlap(p), tag + ": arena and panels do not overlap")
		_check(_inside(p["arena"], view) and _inside(p["left"], view) and _inside(p["right"], view), tag + ": everything is on screen")
		var arena: Rect2 = p["arena"]
		_check(is_equal_approx(arena.size.x / arena.size.y, 4.0 / 3.0), tag + ": arena keeps its 4:3 shape")

	# In Main, the camera puts the world origin (arena centre) at the arena rect's centre, at 1x and zoomed
	var main: Node = (load("res://Scenes/Main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var cam: ZoomCamera = main.get_node("Camera2D") as ZoomCamera
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	_check(_near(xf * Vector2.ZERO, cam.arena_screen.get_center()), "world origin is drawn at the arena centre (got %s)" % str(xf * Vector2.ZERO))
	_check(_near(xf * Vector2(400, 300), cam.arena_screen.end), "arena corner is drawn at the arena rect's corner")
	cam.set_zoom_level(2.0)
	xf = main.get_viewport().get_canvas_transform()
	_check(_near(xf * cam.position, cam.arena_screen.get_center()), "zoomed, the view centre is still drawn at the arena centre")
	cam.reset_view()
	_check(main.get_node_or_null("UI/LeftColumn/AlleleGraph") != null, "the allele panel moved into the left column")
	_check(main.get_node_or_null("UI/RightColumn") != null and main.population_graph.get_parent().get_parent().name == "RightColumn",
			"the population graph moved into the right column")
	main.queue_free()
	await process_frame
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
