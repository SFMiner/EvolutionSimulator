extends SceneTree
## Strain-season prototype (NOT part of run_all_tests). Two strains of ADULT lizards share one arena for a
## "season"; each lizard's fitness is eggs it would have laid + 1 if alive at the end. Then an offline
## frequency simulation (bootstrap of the measured seasons + binomial drift) shows what the counts would do.
##
## Run: PS_OUT=out.txt PS_A=MM PS_B=mm PS_FOOD=0.25 ../Godot_v4.5-stable_win64.exe --headless --fixed-fps 60 \
##        --path . --script tests/prototype_strains.gd >/dev/null
## Env (all optional): PS_NAME  PS_A (mutant, first)  PS_B (resident)  PS_BG (background, default "Mm,Ss,Gg,CbCb,KK")
##   PS_FOOD (food spawn interval s, default 0.35)  PS_HABITAT grass|sand|rock  PS_HAWKS=1  PS_HAWK_RISK
##   PS_SEASONS=20  PS_SECONDS=40  PS_PER=20 (lizards per strain)  PS_ENERGY=60  PS_SCALE=8  PS_OUT=<file>
##   PS_N=5000  PS_GENS=30  PS_REPS=200  PS_SEED=1
## A strain is a comma list of genotype tokens laid over the background: "MM", "ss", "CgCg", "bg" (= background only).

var _config: Node
var _out_path: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_run()


func _emit(line: String) -> void:
	print(line)
	if _out_path != "":
		var file: FileAccess = FileAccess.open(_out_path, FileAccess.READ_WRITE if FileAccess.file_exists(_out_path) else FileAccess.WRITE)
		if file != null:
			file.seek_end()
			file.store_line(line)
			file.close()


func _env_float(key: String, fallback: float) -> float:
	var text: String = OS.get_environment(key)
	return text.to_float() if text.is_valid_float() else fallback


func _env_str(key: String, fallback: String) -> String:
	var text: String = OS.get_environment(key)
	return text if text != "" else fallback


## "MM" -> {metabolism: [M, M]}; "CgCg" -> {color: [Cg, Cg]}. Tokens override the background.
func _apply_token(genotype: Dictionary, token: String) -> void:
	var t: String = token.strip_edges()
	if t == "" or t == "bg":
		return
	if t.begins_with("C"):
		genotype[EvoGenetics.COLOR] = [t.substr(0, 2), t.substr(2, 2)]
		return
	var locus: String = ""
	match t[0].to_upper():
		"M":
			locus = EvoGenetics.METABOLISM
		"S":
			locus = EvoGenetics.SPEED
		"G":
			locus = EvoGenetics.GROWTH_RATE
		"K":
			locus = EvoGenetics.CANNIBAL
	genotype[locus] = [t.substr(0, 1), t.substr(1, 1)]


func _make_genotype(background: String, spec: String) -> Dictionary:
	var genotype: Dictionary = {}
	for token: String in background.split(",", false):
		_apply_token(genotype, token)
	for token: String in spec.split(",", false):
		_apply_token(genotype, token)
	return genotype


func _run() -> void:
	await get_root().ready
	_config = get_root().get_node("/root/GameConfig")
	_out_path = OS.get_environment("PS_OUT")
	var name_text: String = _env_str("PS_NAME", "cond")
	var spec_a: String = _env_str("PS_A", "MM")
	var spec_b: String = _env_str("PS_B", "mm")
	var background: String = _env_str("PS_BG", "Mm,Ss,Gg,CbCb,KK")
	var seasons: int = int(_env_float("PS_SEASONS", 20.0))
	var season_seconds: float = _env_float("PS_SECONDS", 40.0)
	var per: int = int(_env_float("PS_PER", 20.0))
	var start_energy: float = _env_float("PS_ENERGY", 60.0)
	var time_scale: float = _env_float("PS_SCALE", 8.0)
	_rng.seed = int(_env_float("PS_SEED", 1.0))

	_config.food_spawn_interval = _env_float("PS_FOOD", 0.35)
	var habitat_text: String = OS.get_environment("PS_HABITAT").to_lower()
	_config.habitat = {"grass": 0, "sand": 1, "rock": 2}.get(habitat_text, 0)
	_config.hawks_on = OS.get_environment("PS_HAWKS") == "1"
	if OS.get_environment("PS_HAWK_RISK").is_valid_float():
		_config.hawk_risk = OS.get_environment("PS_HAWK_RISK").to_float()
	_config.reproduction_mode = 1  # asexual: no mate wait
	_config.spawn_founders = false
	_config.eggs_count_only = true

	var genotypes: Array[Dictionary] = [_make_genotype(background, spec_a), _make_genotype(background, spec_b)]
	_emit("PS config name=%s A=%s B=%s bg=%s food=%.3f habitat=%d hawks=%s hawk_risk=%.4f seasons=%d seconds=%.0f per=%d energy=%.0f scale=%.1f" % [
			name_text, spec_a, spec_b, background, float(_config.food_spawn_interval), int(_config.habitat),
			str(_config.hawks_on), float(_config.hawk_risk), seasons, season_seconds, per, start_energy, time_scale])

	var wa: Array[float] = []
	var wb: Array[float] = []
	var rows: Array[Dictionary] = []
	for s: int in range(seasons):
		var row: Dictionary = await _run_season(s, genotypes, per, start_energy, season_seconds, time_scale)
		rows.append(row)
		wa.append(float(row["w0"]))
		wb.append(float(row["w1"]))
		_emit("PS season=%d wA=%.3f wB=%.3f survA=%d survB=%d eggsA=%d eggsB=%d deathsA=%s deathsB=%s wall=%.1fs" % [
				s, float(row["w0"]), float(row["w1"]), int(row["surv0"]), int(row["surv1"]), int(row["eggs0"]), int(row["eggs1"]),
				str(row["causes0"]), str(row["causes1"]), float(row["wall"])])

	_summary(name_text, rows, wa, wb)
	for p0: float in [0.10, 0.01]:
		_trajectories(wa, wb, p0, int(_env_float("PS_N", 5000.0)), int(_env_float("PS_GENS", 30.0)), int(_env_float("PS_REPS", 200.0)))
	_emit("PS done")
	_config.set_sim_speed(1.0)
	quit(0)


## One season: `per` adults of each strain scattered in one arena. Returns means and counts per strain.
func _run_season(season: int, genotypes: Array[Dictionary], per: int, start_energy: float, season_seconds: float, time_scale: float) -> Dictionary:
	OS.set_environment("EVO_SEED", str(1000 + season * 7 + int(_rng.randi() % 100000)))
	var main: Node = (load("res://Scenes/Main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	_config.set_sim_speed(1.0)
	await process_frame
	await process_frame
	var scene: PackedScene = load("res://Scenes/Organism.tscn") as PackedScene
	var records: Array[Dictionary] = []  # {strain, org, dead, eggs, cause}
	for strain: int in range(2):
		for i: int in range(per):
			var org: Node2D = scene.instantiate() as Node2D
			org.set("rng", main.rng)
			org.set("genotype", (genotypes[strain] as Dictionary).duplicate(true))
			main.organism_container.add_child(org)
			org.position = Vector2(randf_range(-300.0, 300.0), randf_range(-200.0, 200.0))
			# Born as an egg (the AI's _ready needs that), then made an adult at once
			org.set("current_state", "adult")
			org.update_sprite()
			(org.get("animation_player") as AnimationPlayer).stop()
			org.set("age", 0.0)
			org.set("lifespan", 0.0)
			org.set("energy", start_energy)
			var rec: Dictionary = {"strain": strain, "org": org, "dead": false, "eggs": 0, "cause": ""}
			records.append(rec)
			org.organism_died.connect(_on_died.bind(rec))
	var started_ms: int = Time.get_ticks_msec()
	main.simulation_time = 0.0
	_config.set_sim_speed(time_scale)
	while float(main.simulation_time) < season_seconds:
		await process_frame
	_config.set_sim_speed(1.0)
	var out: Dictionary = {"wall": float(Time.get_ticks_msec() - started_ms) / 1000.0}
	for strain: int in range(2):
		var total_w: float = 0.0
		var surv: int = 0
		var eggs: int = 0
		var causes: Dictionary = {"starved": 0, "hawk": 0, "eaten": 0, "old_age": 0}
		for rec: Dictionary in records:
			if int(rec["strain"]) != strain:
				continue
			var dead: bool = bool(rec["dead"])
			var alive: bool = not dead
			var e: int = int(rec["eggs"])
			if alive:
				var org: Node2D = rec["org"] as Node2D
				e = int(org.get("eggs_laid"))
			eggs += e
			if alive:
				surv += 1
			else:
				causes[str(rec["cause"])] = int(causes.get(str(rec["cause"]), 0)) + 1
			total_w += float(e) + (1.0 if alive else 0.0)
		out["w%d" % strain] = total_w / float(per)
		out["surv%d" % strain] = surv
		out["eggs%d" % strain] = eggs
		out["causes%d" % strain] = "s%d/h%d/e%d/o%d" % [causes["starved"], causes["hawk"], causes["eaten"], causes["old_age"]]
	main.queue_free()
	await process_frame
	await process_frame
	return out


func _on_died(organism: Node2D, rec: Dictionary) -> void:
	rec["dead"] = true
	rec["eggs"] = int(organism.get("eggs_laid"))
	rec["cause"] = str(organism.get("death_cause"))


# === OFFLINE ===

func _summary(name_text: String, rows: Array[Dictionary], wa: Array[float], wb: Array[float]) -> void:
	var ratios: Array[float] = []
	var diffs: Array[float] = []
	for i: int in range(wa.size()):
		diffs.append(wa[i] - wb[i])
		if wb[i] > 0.0:
			ratios.append(wa[i] / wb[i])
	var sa: Array[float] = _col(rows, "surv0")
	var sb: Array[float] = _col(rows, "surv1")
	var ea: Array[float] = _col(rows, "eggs0")
	var eb: Array[float] = _col(rows, "eggs1")
	_emit("PS SUMMARY %s: wA=%.3f (sd %.3f) wB=%.3f (sd %.3f) ratio_of_means=%.3f seasonratio mean=%.3f sd=%.3f | diff mean=%.3f sd=%.3f se=%.3f | survA=%.1f survB=%.1f eggsA=%.1f eggsB=%.1f (per %d-lizard strain per season)" % [
			name_text, _mean(wa), _sd(wa), _mean(wb), _sd(wb), _mean(wa) / maxf(_mean(wb), 0.0001), _mean(ratios), _sd(ratios),
			_mean(diffs), _sd(diffs), _sd(diffs) / sqrt(float(diffs.size())), _mean(sa), _mean(sb), _mean(ea), _mean(eb), int(_env_float("PS_PER", 20.0))])
	var totals: Dictionary = {"A": {}, "B": {}}
	for r: Dictionary in rows:
		for side: String in ["A", "B"]:
			var key: String = "causes0" if side == "A" else "causes1"
			for part: String in str(r[key]).split("/"):
				var d: Dictionary = totals[side]
				d[part.substr(0, 1)] = int(d.get(part.substr(0, 1), 0)) + part.substr(1).to_int()
	_emit("PS DEATHS total over seasons (s=starved h=hawk e=eaten o=old age) A=%s B=%s" % [str(totals["A"]), str(totals["B"])])


func _col(rows: Array[Dictionary], key: String) -> Array[float]:
	var out: Array[float] = []
	for r: Dictionary in rows:
		out.append(float(r[key]))
	return out


func _binomial(n: int, p: float) -> int:
	if p <= 0.0:
		return 0
	if p >= 1.0:
		return n
	var mean: float = float(n) * p
	var var_: float = mean * (1.0 - p)
	if mean >= 25.0 and float(n) - mean >= 25.0:
		return clampi(int(round(_rng.randfn(mean, sqrt(var_)))), 0, n)
	if mean < 25.0:
		return mini(n, _poisson(mean))
	return maxi(0, n - _poisson(float(n) - mean))


func _poisson(lambda_: float) -> int:
	var limit: float = exp(-lambda_)
	var k: int = 0
	var prod: float = _rng.randf()
	while prod > limit:
		k += 1
		prod *= _rng.randf()
	return k


func _trajectories(wa: Array[float], wb: Array[float], p_start: float, n: int, gens: int, reps: int) -> void:
	var finals: Array[float] = []
	var took: int = 0
	var lost: int = 0
	for r: int in range(reps):
		var p: float = p_start
		for g: int in range(gens):
			var k: int = _rng.randi() % wa.size()
			var denom: float = p * wa[k] + (1.0 - p) * wb[k]
			var p_exp: float = p
			if denom > 0.0:
				p_exp = p * wa[k] / denom
			p = float(_binomial(n, p_exp)) / float(n)
		finals.append(p)
		if p > 0.9:
			took += 1
		elif p < 0.01:
			lost += 1
	_emit("PS TRAJ p0=%.2f N=%d gens=%d reps=%d: mean final p=%.3f sd=%.3f | took over (p>0.9) %.1f%% | lost (p<0.01) %.1f%% | between %.1f%%" % [
			p_start, n, gens, reps, _mean(finals), _sd(finals), 100.0 * float(took) / float(reps), 100.0 * float(lost) / float(reps),
			100.0 * float(reps - took - lost) / float(reps)])


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
