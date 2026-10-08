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
	_config.hawks_on = true
	_config.habitat = 1  # sand
	await _run_mode("sexual", 0, 22, true)
	_config.hawks_on = false
	_config.habitat = 0
	# Low space cap and short lives: the population must never exceed the cap and old age must kill
	var saved_founders: int = int(_config.founder_count)
	var saved_cap: int = int(_config.space_cap)
	var saved_life: float = float(_config.lifespan_seconds)
	_config.founder_count = 24
	_config.space_cap = 15
	_config.lifespan_seconds = 40.0
	await _run_mode("sexual", 0, 23, false, true)
	_config.founder_count = saved_founders
	_config.space_cap = saved_cap
	_config.lifespan_seconds = saved_life
	Engine.time_scale = 1.0
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run_mode(mode_name_in: String, mode: int, seed_value: int, hawks: bool = false, capped: bool = false) -> void:
	var mode_name: String = mode_name_in + ("+hawks" if hawks else "") + ("+cap" if capped else "")
	OS.set_environment("EVO_SEED", str(seed_value))
	OS.set_environment("EVO_MODE", mode_name_in)
	_config.reproduction_mode = mode
	var main: Node = (load("res://Scenes/Main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	Engine.time_scale = TIME_SCALE
	var started_ms: int = Time.get_ticks_msec()
	var max_live: int = 0
	var prev_live: int = 0
	var grew_over_cap: int = 0  # frames where the count rose while already above the cap
	while float(main.simulation_time) < SIM_SECONDS:
		await process_frame
		if float(main.simulation_time) > 1.0:
			var live_now: int = (main.get_live_genotypes() as Array).size()
			max_live = maxi(max_live, live_now)
			if live_now > prev_live and live_now > int(_config.space_cap) and prev_live > 0:
				grew_over_cap += 1
			prev_live = live_now
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
	_check(live.size() == pop, mode_name + ": population counter matches live organisms exactly")
	var deaths: Dictionary = main.deaths
	var dead: int = int(deaths["starved"]) + int(deaths["eaten"]) + int(deaths["hawk"]) + int(deaths["old_age"])
	var made: int = int(_config.founder_count) + int(births["mating"]) + int(births["self"]) + int(births["clone"])
	_check(made - dead == pop, mode_name + ": founders + births - deaths = population (" + str(made) + " - " + str(dead) + " vs " + str(pop) + ")")
	if hawks:
		_check(int(deaths["hawk"]) > 0, mode_name + ": hawks caught some lizards")
	else:
		_check(int(deaths["hawk"]) == 0, mode_name + ": no hawk deaths with hawks off")
	if capped:
		# Founders (24) start above the cap of 15; nobody may be added while the count is above it
		_check(max_live > int(_config.space_cap), mode_name + ": run started above the cap (max " + str(max_live) + ")")
		_check(grew_over_cap == 0, mode_name + ": population never grew while above the space cap (" + str(grew_over_cap) + " frames)")
		_check(int(deaths["old_age"]) > 0, mode_name + ": old age killed some lizards")
	else:
		_check(int(deaths["old_age"]) == 0, mode_name + ": no old-age deaths within 60 s at the default lifespan")
	if mode_name_in == "sexual":
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
