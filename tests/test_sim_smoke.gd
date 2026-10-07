extends SceneTree
## Headless sim smoke: seeded run of the real Main scene for ~60 simulated seconds per mode.
## Engine.time_scale fast-forwards timers, AI and graphs together.

const SIM_SECONDS: float = 60.0
const TIME_SCALE: float = 4.0
const MAX_WALL_SECONDS: float = 120.0

var _passed: int = 0
var _failed: int = 0
var _config: Node


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
	await _run_mode("sexual", 0, 21)
	await _run_mode("asexual", 1, 21)
	Engine.time_scale = 1.0
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run_mode(mode_name: String, mode: int, seed_value: int) -> void:
	OS.set_environment("EVO_SEED", str(seed_value))
	OS.set_environment("EVO_MODE", mode_name)
	_config.reproduction_mode = mode
	var main: Node = (load("res://Scenes/Main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	Engine.time_scale = TIME_SCALE
	var started_ms: int = Time.get_ticks_msec()
	while float(main.simulation_time) < SIM_SECONDS:
		await process_frame
		if float(Time.get_ticks_msec() - started_ms) / 1000.0 > MAX_WALL_SECONDS:
			break
		if int(main.population_count) <= 0:
			break
	Engine.time_scale = 1.0
	var pop: int = int(main.population_count)
	var births: Dictionary = main.births
	var live: Array[Dictionary] = main.get_live_genotypes()
	_check(float(main.simulation_time) >= SIM_SECONDS or pop <= 0, mode_name + ": ran the full time or went extinct")
	_check(pop > 0 or float(main.extinct_at) >= 0.0, mode_name + ": extinction is reported if population is 0")
	_check(live.size() == pop or live.size() == pop + 1, mode_name + ": population counter matches live organisms")
	if mode_name == "sexual":
		_check(int(births["clone"]) == 0, "sexual: no clone births")
	else:
		_check(int(births["mating"]) == 0 and int(births["self"]) == 0, "asexual: only clone births")
	var total: int = int(births["mating"]) + int(births["self"]) + int(births["clone"])
	var freqs: Dictionary = {}
	for id: String in EvoGenetics.LOCUS_IDS:
		freqs[id] = EvoGenetics.allele_frequencies(live, id)
	print("[%s] t=%.1f pop=%d births=%s (total %d) max_generation=%d extinct_at=%.1f" % [mode_name,
			float(main.simulation_time), pop, str(births), total, int(main.current_generation), float(main.extinct_at)])
	print("[%s] allele freqs: %s" % [mode_name, str(freqs)])
	main.queue_free()
	await process_frame
	await process_frame
