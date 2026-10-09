extends SceneTree
## Selection experiment (NOT part of run_all_tests: too slow; filename has no test_ prefix on purpose).
## Runs the real Main scene for several seeds per reproduction mode and prints per-allele frequency
## trajectories plus population stats, so you can judge selection against seed-to-seed spread.
##
## Run (repeatable: fixed frame delta + seed):
##   ../Godot_v4.5-stable_win64.exe --headless --fixed-fps 60 --path . --script tests/experiment_selection.gd
## Settings via environment variables (all optional):
##   EXP_SEEDS=1,2,3,4,5   EXP_SECONDS=600   EXP_MODES=sexual,asexual   EXP_SCALE=8 (GameConfig.set_sim_speed; 1, 4 and 8 measured equivalent)
##   EXP_FOOD_INTERVAL=<s> EXP_FOOD_MAX=<n>  EXP_FOUNDERS=<n>   (override GameConfig for a variant)
##   EXP_HABITAT=grass|sand|rock  EXP_HAWKS=1  EXP_HAWK_RISK=<per s>  (environment controls)
##   EXP_CANNIBAL_EFF=<x> EXP_UPKEEP=slow,med,fast EXP_MEALMULT=low,med,high  (trade-off tuning overrides)
##   EXP_EGG_COST=<energy> (parent pays it, hatchling starts with it)
##   EXP_CANNIBALS=0 turns all cannibal predation off (pair with EXP_CANNIBAL_EFF=1 to remove the plant penalty too)
##   EXP_OUT=<file> also appends every EXP line to a file (Godot prints are very slow when piped
##   on Windows; run with stdout to /dev/null and read the file instead).
##   EXP_QUIET=1 hides the per-run lines.   EXP_BENCH=50,100,300 runs the frame-time benchmark instead.
## Output lines start with "EXP" so the engine's debug prints can be filtered: ... | grep '^EXP'

const CHECKPOINTS: Array[float] = [0.25, 0.5, 0.75, 1.0]

var _config: Node
var _scale: float = 8.0
var _seconds: float = 600.0
var _quiet: bool = false


func _init() -> void:
	_run()


## Print an EXP line and, if EXP_OUT is set, append it to that file.
func _emit(line: String) -> void:
	print(line)
	var path: String = OS.get_environment("EXP_OUT")
	if path != "":
		var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
		if file != null:
			file.seek_end()
			file.store_line(line)
			file.close()


func _env_float(key: String, fallback: float) -> float:
	var text: String = OS.get_environment(key)
	return text.to_float() if text.is_valid_float() else fallback


func _run() -> void:
	await get_root().ready
	_config = get_root().get_node("/root/GameConfig")
	_scale = _env_float("EXP_SCALE", 8.0)
	_seconds = _env_float("EXP_SECONDS", 600.0)
	_quiet = OS.get_environment("EXP_QUIET") == "1"
	if OS.get_environment("EXP_FOOD_INTERVAL").is_valid_float():
		_config.food_spawn_interval = OS.get_environment("EXP_FOOD_INTERVAL").to_float()
	if OS.get_environment("EXP_FOOD_MAX").is_valid_int():
		_config.food_max = OS.get_environment("EXP_FOOD_MAX").to_int()
	var habitat_text: String = OS.get_environment("EXP_HABITAT").to_lower()
	if habitat_text != "":
		_config.habitat = {"grass": 0, "sand": 1, "rock": 2}.get(habitat_text, 0)
	if OS.get_environment("EXP_HAWKS") != "":
		_config.hawks_on = OS.get_environment("EXP_HAWKS") == "1"
	if OS.get_environment("EXP_HAWK_RISK").is_valid_float():
		_config.hawk_risk = OS.get_environment("EXP_HAWK_RISK").to_float()
	if OS.get_environment("EXP_FOOD_INITIAL").is_valid_int():
		_config.food_initial = OS.get_environment("EXP_FOOD_INITIAL").to_int()
	if OS.get_environment("EXP_FOOD_ENERGY").is_valid_float():
		_config.food_energy_value = OS.get_environment("EXP_FOOD_ENERGY").to_float()
	if OS.get_environment("EXP_SATIETY") != "":
		_config.satiety_enabled = OS.get_environment("EXP_SATIETY") != "0"
	if OS.get_environment("EXP_EGG_COST").is_valid_float():
		_config.egg_cost = OS.get_environment("EXP_EGG_COST").to_float()
	if OS.get_environment("EXP_HAWK_FACTOR").is_valid_float():
		_config.hawk_camouflage_factor = OS.get_environment("EXP_HAWK_FACTOR").to_float()
	# Optional trade-off overrides for tuning: EXP_CANNIBAL_EFF, EXP_UPKEEP="0,0.4,0.9", EXP_MEALMULT="0.7,1,1.4"
	if OS.get_environment("EXP_CANNIBAL_EFF").is_valid_float():
		_config.cannibal_plant_efficiency = OS.get_environment("EXP_CANNIBAL_EFF").to_float()
	var upkeep_text: PackedStringArray = OS.get_environment("EXP_UPKEEP").split(",", false)
	if upkeep_text.size() == 3:
		_config.speed_upkeep_by_speed = {"slow": upkeep_text[0].to_float(), "medium": upkeep_text[1].to_float(), "fast": upkeep_text[2].to_float()}
	var meal_text: PackedStringArray = OS.get_environment("EXP_MEALMULT").split(",", false)
	if meal_text.size() == 3:
		_config.meal_multiplier_by_metabolism = {"low": meal_text[0].to_float(), "medium": meal_text[1].to_float(), "high": meal_text[2].to_float()}
	if OS.get_environment("EXP_CANNIBALS") != "":
		_config.cannibalism_enabled = OS.get_environment("EXP_CANNIBALS") != "0"
	if OS.get_environment("EXP_SPACE").is_valid_int():
		_config.space_cap = OS.get_environment("EXP_SPACE").to_int()  # 0 = no cap
	if OS.get_environment("EXP_LIFESPAN").is_valid_float():
		_config.lifespan_seconds = OS.get_environment("EXP_LIFESPAN").to_float()
	if OS.get_environment("EXP_FOUNDERS").is_valid_int():
		_config.founder_count = OS.get_environment("EXP_FOUNDERS").to_int()
	var seeds: Array[int] = []
	var seed_text: String = OS.get_environment("EXP_SEEDS")
	if seed_text == "":
		seed_text = "1,2,3,4,5"
	for token: String in seed_text.split(",", false):
		seeds.append(token.strip_edges().to_int())
	var modes: Array[String] = []
	var mode_text: String = OS.get_environment("EXP_MODES")
	if mode_text == "":
		mode_text = "sexual,asexual"
	for token: String in mode_text.split(",", false):
		modes.append(token.strip_edges().to_lower())

	if OS.get_environment("EXP_BENCH") != "":
		await _bench(OS.get_environment("EXP_BENCH"))
		quit(0)
		return

	_emit("EXP config: founders=%d food_interval=%.3f food_max=%d seconds=%.0f scale=%.1f seeds=%s fps=%d habitat=%d hawks=%s hawk_risk=%.4f cannibal_eff=%.2f upkeep=%s meal_mult=%s space=%d lifespan=%.0f" % [
			int(_config.founder_count), float(_config.food_spawn_interval), int(_config.food_max),
			_seconds, _scale, str(seeds), Engine.max_fps, int(_config.habitat), str(_config.hawks_on),
			float(_config.hawk_risk), float(_config.cannibal_plant_efficiency),
			str(_config.speed_upkeep_by_speed), str(_config.meal_multiplier_by_metabolism),
			int(_config.space_cap), float(_config.lifespan_seconds)])
	for mode_name: String in modes:
		var results: Array[Dictionary] = []
		for seed_value: int in seeds:
			var result: Dictionary = await _run_one(mode_name, seed_value)
			results.append(result)
			if not _quiet:
				_emit("EXP run mode=%s seed=%d pop_end=%d pop_min=%d pop_mean2=%.1f pop_max=%d extinct_at=%.1f counter_drift_max=%d food_mean2=%.0f births=%s deaths=%s maxgen=%d digest=%d wall=%.1fs" % [
						mode_name, seed_value, int(result["pop_end"]), int(result["pop_min"]), float(result["pop_mean2"]),
						int(result["pop_max"]), float(result["extinct_at"]), int(result["max_drift"]), float(result["food_mean2"]), str(result["births"]), str(result["deaths"]),
						int(result["max_gen"]), int(result["digest"]), float(result["wall"])])
		if OS.get_environment("EXP_TRACE") == "1":
			for r: Dictionary in results:
				if float(r["extinct_at"]) >= 0.0:
					var trace: PackedStringArray = PackedStringArray()
					var series: Array = r["pops"]
					for i: int in range(0, series.size(), 20):
						trace.append(str(series[i]))
					_emit("EXP trace (extinct run, population every 20 s): " + " ".join(trace))
		_report(mode_name, results)
	_config.set_sim_speed(1.0)
	quit(0)


## One seeded run. Returns frequencies at start and each checkpoint plus population stats.
func _run_one(mode_name: String, seed_value: int) -> Dictionary:
	OS.set_environment("EVO_SEED", str(seed_value))
	OS.set_environment("EVO_MODE", mode_name)
	_config.reproduction_mode = 1 if mode_name == "asexual" else 0
	var main: Node = (load("res://Scenes/Main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	_config.set_sim_speed(1.0)
	await process_frame
	await process_frame
	_config.set_sim_speed(_scale)
	var started_ms: int = Time.get_ticks_msec()
	var traj: Array[Dictionary] = []  # index 0 = start, then one entry per checkpoint
	traj.append(_freqs(main.get_live_genotypes()))
	var next_cp: int = 0
	var pops: Array[int] = []
	var foods: Array[int] = []
	var next_second: float = 1.0
	var extinct_at: float = -1.0
	var max_drift: int = 0
	var meals_at_half: int = 0
	_config.diag = {"plant_meals": 0, "kill_egg": 0, "kill_juvenile": 0, "kill_adult": 0}
	while next_cp < CHECKPOINTS.size():
		await process_frame
		var t: float = float(main.simulation_time)
		while t >= next_second:
			pops.append(_alive(main))
			if pops.size() == int(_seconds) / 2:
				meals_at_half = int(_config.diag["plant_meals"])
			foods.append(main.environment.get_node("FoodContainer").get_child_count())
			max_drift = maxi(max_drift, absi(int(main.population_count) - pops[pops.size() - 1]))
			next_second += 1.0
		if t >= CHECKPOINTS[next_cp] * _seconds:
			traj.append(_freqs(main.get_live_genotypes()))
			next_cp += 1
		if _alive(main) <= 0:
			extinct_at = t
			# fill the rest of the trajectory with the empty population so rows stay aligned
			while next_cp < CHECKPOINTS.size():
				traj.append(_freqs([] as Array[Dictionary]))
				next_cp += 1
	_config.set_sim_speed(1.0)
	var pop_end: int = _alive(main)
	var live: Array[Dictionary] = main.get_live_genotypes()
	var half: int = pops.size() / 2
	var sum2: float = 0.0
	var min2: int = 1000000
	var max2: int = 0
	var at_cap: int = 0
	var cap: int = int(_config.space_cap)
	for i: int in range(half, pops.size()):
		sum2 += float(pops[i])
		if cap > 0 and pops[i] >= cap:
			at_cap += 1
		min2 = mini(min2, pops[i])
		max2 = maxi(max2, pops[i])
	var meals_2: int = int(_config.diag["plant_meals"]) - meals_at_half
	var result: Dictionary = {
		"cap_frac": float(at_cap) / maxf(1.0, float(pops.size() - half)),
		"meals_per_lizard_s": float(meals_2) / maxf(1.0, sum2) if sum2 > 0.0 else -1.0,
		"kills": (_config.diag as Dictionary).duplicate(),
		"traj": traj,
		"pop_end": pop_end,
		"pop_min": min2 if pops.size() > half else 0,
		"pop_max": max2,
		"pop_mean2": sum2 / maxf(1.0, float(pops.size() - half)),
		"extinct_at": extinct_at,
		"max_drift": max_drift,
		"births": main.births.duplicate(),
		"deaths": main.deaths.duplicate(),
		"max_gen": int(main.current_generation),
		"digest": _digest(main, live),
		"wall": float(Time.get_ticks_msec() - started_ms) / 1000.0,
		"pops": pops,
		"food_mean2": _mean_int_tail(foods),
	}
	main.queue_free()
	await process_frame
	await process_frame
	return result


func _mean_int_tail(values: Array[int]) -> float:
	var half: int = values.size() / 2
	var total: float = 0.0
	for i: int in range(half, values.size()):
		total += float(values[i])
	return total / maxf(1.0, float(values.size() - half))


## Real number of living organisms. SimulationManager.population_count can drift (die() can run twice).
func _alive(main: Node) -> int:
	return (main.get_live_genotypes() as Array).size()


func _freqs(genotypes: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for id: String in EvoGenetics.LOCUS_IDS:
		out[id] = EvoGenetics.allele_frequencies(genotypes, id)
	return out


## Hash of the final state (pop, genotypes, positions, energies): equal digests = identical runs.
func _digest(main: Node, live: Array[Dictionary]) -> int:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(str(live.size()))
	parts.append(str(main.births))
	var container: Node = main.organism_container
	for child: Node in container.get_children():
		var org: Node2D = child as Node2D
		if org != null:
			parts.append("%s|%.2f|%.2f|%.2f" % [str(org.get("genotype")), org.position.x, org.position.y, float(org.get("energy"))])
	return hash("\n".join(parts))


func _allele_list(locus_id: String) -> Array[String]:
	var out: Array[String] = []
	for allele: String in EvoGenetics.get_library().get_locus(locus_id).alleles:
		out.append(allele)
	return out


func _report(mode_name: String, all_results: Array[Dictionary]) -> void:
	var results: Array[Dictionary] = all_results
	var n: int = results.size()
	var ends: Array[float] = []
	var mean_pop2: Array[float] = []
	var extinctions: int = 0
	for r: Dictionary in results:
		ends.append(float(r["pop_end"]))
		mean_pop2.append(float(r["pop_mean2"]))
		if float(r["extinct_at"]) >= 0.0:
			extinctions += 1
	_emit("EXP == %s: %d seeds, extinctions=%d, pop_end mean=%.1f (min %d max %d), pop mean over 2nd half mean=%.1f" % [
			mode_name, n, extinctions, _mean(ends), int(ArrayMin(ends)), int(ArrayMax(ends)), _mean(mean_pop2)])
	var survivors: Array[Dictionary] = []
	for r: Dictionary in all_results:
		if float(r["extinct_at"]) < 0.0:
			survivors.append(r)
	results = survivors
	_report_diag(results)
	_emit("EXP allele freq (surviving runs only, n=%d): start  25%%   50%%   75%%   end | sd_end | per-seed end" % survivors.size())
	for id: String in EvoGenetics.LOCUS_IDS:
		for allele: String in _allele_list(id):
			var cols: PackedStringArray = PackedStringArray()
			for step: int in range(CHECKPOINTS.size() + 1):
				var vals: Array[float] = []
				for r: Dictionary in results:
					var traj: Array = r["traj"]
					vals.append(float((traj[step] as Dictionary)[id][allele]))
				cols.append("%.3f" % _mean(vals))
			var end_vals: Array[float] = []
			var seed_cols: PackedStringArray = PackedStringArray()
			for r: Dictionary in results:
				var traj: Array = r["traj"]
				var v: float = float((traj[CHECKPOINTS.size()] as Dictionary)[id][allele])
				end_vals.append(v)
				seed_cols.append("%.2f" % v)
			var start_vals: Array[float] = []
			for r: Dictionary in results:
				var traj0: Array = r["traj"]
				start_vals.append(float((traj0[0] as Dictionary)[id][allele]))
			var sd_end: float = _sd(end_vals)
			# movement of the mean from the start, in seed-spread units (rises = at least +2)
			var z: float = (_mean(end_vals) - _mean(start_vals)) / maxf(sd_end, 0.0001)
			_emit("EXP   %-11s %-2s  %s | sd %.3f | z %+.1f | %s" % [id, allele, "  ".join(cols), sd_end, z, " ".join(seed_cols)])


## Per-capita diagnostics over all runs: meals per lizard-second (2nd half), cannibal kills by prey stage, deaths by cause.
func _report_diag(results: Array[Dictionary]) -> void:
	var meals: Array[float] = []
	var causes: Array[String] = ["starved", "eaten", "hawk", "old_age"]
	var cap_fracs: Array[float] = []
	var stages: Array[String] = ["kill_egg", "kill_juvenile", "kill_adult"]
	var cause_vals: Dictionary = {}
	var stage_vals: Dictionary = {}
	for key: String in causes:
		cause_vals[key] = [] as Array[float]
	for key: String in stages:
		stage_vals[key] = [] as Array[float]
	var young_share: Array[float] = []
	for r: Dictionary in results:
		cap_fracs.append(float(r["cap_frac"]))
		var mpl: float = float(r["meals_per_lizard_s"])
		if mpl >= 0.0:
			meals.append(mpl)
		var deaths: Dictionary = r["deaths"]
		for key: String in causes:
			(cause_vals[key] as Array[float]).append(float(deaths.get(key, 0)))
		var kills: Dictionary = r["kills"]
		var total_kills: float = 0.0
		for key: String in stages:
			(stage_vals[key] as Array[float]).append(float(kills.get(key, 0)))
			total_kills += float(kills.get(key, 0))
		if total_kills > 0.0:
			young_share.append((float(kills.get("kill_egg", 0)) + float(kills.get("kill_juvenile", 0))) / total_kills)
	_emit("EXP per-capita: plant meals per lizard-second (2nd half) mean=%.4f sd=%.4f (= one meal per %.1f s)" % [
			_mean(meals), _sd(meals), 1.0 / maxf(_mean(meals), 0.00001)])
	_emit("EXP time at the space cap (2nd half, population >= cap; 0 if no cap) mean=%.3f sd=%.3f" % [_mean(cap_fracs), _sd(cap_fracs)])
	var cause_line: PackedStringArray = PackedStringArray()
	for key: String in causes:
		cause_line.append("%s %.0f (sd %.0f)" % [key, _mean(cause_vals[key] as Array[float]), _sd(cause_vals[key] as Array[float])])
	_emit("EXP deaths per run (mean, sd): " + ", ".join(cause_line))
	var stage_line: PackedStringArray = PackedStringArray()
	for key: String in stages:
		stage_line.append("%s %.1f (sd %.1f)" % [key, _mean(stage_vals[key] as Array[float]), _sd(stage_vals[key] as Array[float])])
	_emit("EXP cannibal kills per run by prey stage: " + ", ".join(stage_line) + " | egg+juvenile share of kills mean=%.3f sd=%.3f" % [_mean(young_share), _sd(young_share)])


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var s: float = 0.0
	for v: float in values:
		s += v
	return s / float(values.size())


func _sd(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var m: float = _mean(values)
	var s: float = 0.0
	for v: float in values:
		s += (v - m) * (v - m)
	return sqrt(s / float(values.size() - 1))


func ArrayMin(values: Array[float]) -> float:
	var m: float = INF
	for v: float in values:
		m = minf(m, v)
	return m


func ArrayMax(values: Array[float]) -> float:
	var m: float = -INF
	for v: float in values:
		m = maxf(m, v)
	return m


# === FRAME-TIME BENCHMARK (EXP_BENCH=50,100,300) ===
## Spawns extra founders up to each target and averages frame time over a window while the
## population is still stable (founders start as eggs and take ~50 s to starve).
func _bench(sizes_text: String) -> void:
	for token: String in sizes_text.split(",", false):
		var target: int = token.strip_edges().to_int()
		OS.set_environment("EVO_SEED", "7")
		OS.set_environment("EVO_MODE", "sexual")
		_config.reproduction_mode = 0
		_config.founder_count = target
		var main: Node = (load("res://Scenes/Main.tscn") as PackedScene).instantiate()
		get_root().add_child(main)
		_config.set_sim_speed(1.0)
		# warm-up: let eggs hatch so the AI and detection run
		while float(main.simulation_time) < 12.0:
			await process_frame
		var frames: int = 0
		var wall_us: int = 0
		var pop_sum: int = 0
		var food_sum: int = 0
		while float(main.simulation_time) < 27.0:
			var t0: int = Time.get_ticks_usec()
			await process_frame
			wall_us += Time.get_ticks_usec() - t0
			pop_sum += _alive(main)
			food_sum += main.environment.get_node("FoodContainer").get_child_count()
			frames += 1
		var fn: float = float(frames)
		_emit("EXP bench target=%d avg_pop=%.0f avg_food=%.0f frames=%d ms/frame=%.2f (physics + process + timers, headless: no rendering)" % [
				target, float(pop_sum) / fn, float(food_sum) / fn, frames, float(wall_us) / 1000.0 / fn])
		# micro-benchmark: the O(N) group scan in find_mate and the AI's overlap query
		var orgs: Array[Node] = main.organism_container.get_children()
		var t1: int = Time.get_ticks_usec()
		var reps: int = 0
		for node: Node in orgs:
			node.find_mate()
			reps += 1
		var find_mate_us: float = float(Time.get_ticks_usec() - t1) / float(maxi(1, reps))
		var t2: int = Time.get_ticks_usec()
		var q: int = 0
		for node: Node in orgs:
			var area: Area2D = node.detection_area
			area.get_overlapping_areas()
			q += 1
		var overlap_us: float = float(Time.get_ticks_usec() - t2) / float(maxi(1, q))
		_emit("EXP bench target=%d  find_mate=%.1f us/call (all %d organisms = %.2f ms)  get_overlapping_areas=%.1f us/call (all = %.2f ms)" % [
				target, find_mate_us, reps, find_mate_us * float(reps) / 1000.0, overlap_us, overlap_us * float(q) / 1000.0])
		main.queue_free()
		await process_frame
		await process_frame
