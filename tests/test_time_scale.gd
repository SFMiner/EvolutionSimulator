extends SceneTree
## Time-scale invariance check: a fast lizard walks to one food item. The simulated time it needs must not
## depend on GameConfig.set_sim_speed(). With only Engine.time_scale raised, physics steps grow with the
## scale (60 px/s at 8x is 8 px per step) and lizards overshoot the 5 px arrival window and the Area2D overlap.
## Also checks the engine really runs 60 physics steps per simulated second at each scale.

const SCALES: Array[float] = [1.0, 4.0, 8.0]
const WALK_FROM: Array[Vector2] = [Vector2(-150, 0), Vector2(100, -120), Vector2(-60, 140)]
const WALK_TO: Array[Vector2] = [Vector2(150, 0), Vector2(-180, 60), Vector2(160, -90)]
const MAX_SIM_SECONDS: float = 30.0
const TOLERANCE: float = 0.12

var _passed: int = 0
var _failed: int = 0
var _config: Node
var _physics_steps: int = 0


func _init() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + label)


func _on_physics_frame() -> void:
	_physics_steps += 1


func _run() -> void:
	await get_root().ready
	_config = get_root().get_node("/root/GameConfig")
	physics_frame.connect(_on_physics_frame)
	_config.spawn_founders = false
	_config.food_initial = 0
	_config.food_spawn_interval = 100000.0
	var times: Dictionary = {}  # scale -> Array[float]
	for scale: float in SCALES:
		var list: Array[float] = []
		for i: int in range(WALK_FROM.size()):
			list.append(await _walk(i, scale))
		times[scale] = list
	_config.set_sim_speed(1.0)
	var base: Array[float] = times[1.0]
	for scale: float in SCALES:
		var list: Array[float] = times[scale]
		print("walk times (sim s) at %.0fx: %s" % [scale, str(list)])
		for i: int in range(list.size()):
			_check(list[i] < MAX_SIM_SECONDS, "%.0fx walk %d reached the food" % [scale, i])
			_check(absf(list[i] - base[i]) <= TOLERANCE * base[i] + 0.1,
					"%.0fx walk %d took %.2f s, 1x took %.2f s (tolerance %.0f%%)" % [scale, i, list[i], base[i], TOLERANCE * 100.0])
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Seconds of simulated time until a lone fast lizard eats the food placed `i` away from it.
func _walk(i: int, scale: float) -> float:
	OS.set_environment("EVO_SEED", str(300 + i))
	OS.set_environment("EVO_MODE", "asexual")
	_config.reproduction_mode = 1
	var main: Node = (load("res://Scenes/Main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	_config.set_sim_speed(1.0)
	await process_frame
	await process_frame
	var org: Node2D = (load("res://Scenes/Organism.tscn") as PackedScene).instantiate() as Node2D
	org.set("rng", main.rng)
	var genotype: Dictionary = EvoGenetics.random_founder(main.rng)
	genotype[EvoGenetics.SPEED] = ["S", "S"]
	genotype[EvoGenetics.CANNIBAL] = ["K", "K"]
	org.set("genotype", genotype)
	main.organism_container.add_child(org)
	org.position = WALK_FROM[i]
	org.set("current_state", "adult")
	org.update_sprite()
	(org.get("animation_player") as AnimationPlayer).stop()
	org.set("age", 0.0)
	org.set("lifespan", 0.0)
	org.set("energy", 80.0)
	var food: Node2D = (load("res://Scenes/Food.tscn") as PackedScene).instantiate() as Node2D
	main.environment.get_node("FoodContainer").add_child(food)
	food.position = WALK_TO[i]
	await process_frame
	var ai: Node = org.get_node("AI")
	ai.call("set_food_target", food)
	main.simulation_time = 0.0
	_physics_steps = 0
	if OS.get_environment("TS_LEGACY") == "1":
		Engine.time_scale = scale  # diagnostic: the old behaviour (time scale only), should FAIL this suite
	else:
		_config.set_sim_speed(scale)
	while is_instance_valid(food) and not food.is_queued_for_deletion() and float(main.simulation_time) < MAX_SIM_SECONDS:
		await process_frame
	var took: float = float(main.simulation_time)
	_config.set_sim_speed(1.0)
	var steps_per_second: float = float(_physics_steps) / maxf(took, 0.001)
	_check(absf(steps_per_second - 60.0) <= 6.0, "%.0fx: %.1f physics steps per simulated second (want 60)" % [scale, steps_per_second])
	main.queue_free()
	await process_frame
	await process_frame
	return took
