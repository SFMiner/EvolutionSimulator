extends SceneTree
## Zoom camera maths: the view stays inside the arena, and zooming keeps the point under the cursor fixed.

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
	return a.distance_to(b) < 0.001


func _run() -> void:
	await get_root().ready
	# At 1x the whole arena is visible, so the centre is pinned to the origin
	_check(_near(ZoomCamera.clamp_center(Vector2(150, -90), 1.0), Vector2.ZERO), "1x view is pinned to the arena centre")
	# At 2x the view is 400 x 300 world px, so the centre can move at most 200 / 150 px
	_check(_near(ZoomCamera.clamp_center(Vector2(500, -500), 2.0), Vector2(200, -150)), "2x view stops at the arena edge")
	_check(_near(ZoomCamera.clamp_center(Vector2(50, 40), 2.0), Vector2(50, 40)), "2x view moves freely inside the arena")
	# Zooming about a screen point keeps the world point under it fixed
	var center: Vector2 = Vector2(30, -20)
	var offset: Vector2 = Vector2(120, 80)
	var before: Vector2 = center + offset / 1.5
	var new_center: Vector2 = ZoomCamera.zoom_about(center, 1.5, 3.0, offset)
	_check(_near(new_center + offset / 3.0, before), "world point under the cursor stays put")
	_check(_near(ZoomCamera.zoom_about(center, 1.0, 2.0, Vector2.ZERO), center), "zooming about the screen centre keeps the centre")
	# The real camera in Main: zoom is clamped and the view stays inside the arena
	var main: Node = (load("res://Scenes/Main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	await process_frame
	var cam: ZoomCamera = main.get_node("Camera2D") as ZoomCamera
	_check(cam != null, "Main's camera is a ZoomCamera")
	if cam != null:
		cam.set_zoom_level(99.0, Vector2(990, 600))
		_check(is_equal_approx(cam.zoom_level(), ZoomCamera.ZOOM_MAX), "zoom is capped at the maximum")
		var half_view: Vector2 = ZoomCamera.ARENA_HALF / cam.zoom_level()
		_check(absf(cam.position.x) <= ZoomCamera.ARENA_HALF.x - half_view.x + 0.001 and absf(cam.position.y) <= ZoomCamera.ARENA_HALF.y - half_view.y + 0.001,
				"zoomed view stays inside the arena")
		cam.set_zoom_level(0.1)
		_check(is_equal_approx(cam.zoom_level(), 1.0) and _near(cam.position, Vector2.ZERO), "zooming out stops at 1x, centred")
	main.queue_free()
	await process_frame
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
