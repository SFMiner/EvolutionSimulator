# Evolution Simulator (Godot 4.5)

Spec: `Docs/Genetics v2 - Diploid + Mating.md`. Feature checklist: `README.md`.

- **Vendoring:** `addons/genome/` is a vendored copy of `../genome-engine`. Never edit it. Update with
  `bash tools/sync_genome.sh ../evolution-simulator` run from `../genome-engine`.
- **Genotype vs genome:** `organism.genotype` is the inherited truth (`{locus: [a, b]}`).
  `organism.genome` is the expressed phenotype (metabolism/speed/growth_rate/color strings, cannibal bool),
  derived by `EvoGenetics.to_genome()` in `Organism._ready`. Keep that dict shape exactly; the lookup
  tables, OrganismAI and the UI tags read it. Pass genotypes through signals, never phenotypes.
- Loci and founder weights live only in `Scripts/Genetics/EvoGenetics.gd`.
- `GameConfig` is the single source of truth for mode, mutation rate, mate radius and energy costs.
- One RNG: `SimulationManager.rng` (seed with env `EVO_SEED`). Pass it to every Genome call.
- Pause is `get_tree().paused`; the UI CanvasLayer is `process_mode = ALWAYS` so its controls work paused.
  New timed logic must use Timers or `_process` delta so pause and `Engine.time_scale` apply.
- **Fast-forward ONLY via `GameConfig.set_sim_speed(scale)`**, never `Engine.time_scale` alone. Time scale alone makes each 1/60 s physics
  step cover `scale` times more time, so lizards overshoot food (they orbit it forever at 4x-8x) and Area2D overlaps are sampled too rarely.
  The helper also sets `physics_ticks_per_second = 60 x scale` (60 steps per simulated second, verified headless with `--fixed-fps 60`).
  Measured 1x = 4x = 8x within noise, so **8x is the max safe scale tested** (the experiment default; higher is untested). All earlier tuned
  numbers (before 2026-10-08) came from a non-invariant 4x and are void. `tests/test_time_scale.gd` guards this. Headless wall time is
  physics-bound, so a higher scale saves little.
- **Tests:** `GODOT=../Godot_v4.5-stable_win64.exe bash tests/run_all_tests.sh` (each suite is
  `../Godot_v4.5-stable_win64.exe --headless --path . --script tests/test_x.gd`). Test scripts must not
  name `Organism`/`SimulationManager` as types (autoloads are not identifiers when they compile); use
  `root.get_node("/root/GameConfig")` after `await get_root().ready`.
- **Screenshot gate (not headless):** `EVO_SHOT=<png> EVO_MODE=sexual|asexual EVO_SECONDS=90 EVO_SEED=n
  ../Godot_v4.5-stable_win64.exe --path .` runs at 4x (via `set_sim_speed`), saves the viewport, quits.
- Checks: `--headless --path . --editor --quit-after 250` and `--headless --path . --quit-after 600`
  must print no errors/warnings (baseline was clean).
- Conventions: tabs; full type hints in new code (legacy files are untyped, leave them); no `:=` on untyped
  values; legacy scripts are CRLF, new files LF.

## Ecology tuning and the selection experiment
- Ecology numbers live in `GameConfig` (founders, food interval/cap/initial, energy tables, reproduction
  energy). `Organism`, `OrganismAI` and `EnvironmentManager` read them; do not re-hardcode them there.
  Tuned in `fb31c7a` (24 founders, food every 0.35 s, cap 150) to a population of 70-80; after the trade-offs
  (below) it settles ~30 at the default food, and `food_initial` is 30 (was 5: a 5-item start starved the founder
  batch in ~1 of 10 runs once meals were worth less).
- **Selection experiment (slow, not in run_all_tests):**
  `EXP_OUT=out.txt ../Godot_v4.5-stable_win64.exe --headless --fixed-fps 60 --path . --script tests/experiment_selection.gd >/dev/null`
  Env: `EXP_SEEDS=1,2,3,4,5` `EXP_SECONDS=600` `EXP_MODES=sexual,asexual` `EXP_SCALE=8` and `EXP_FOOD_INTERVAL` /
  `EXP_FOOD_MAX` / `EXP_FOUNDERS` for variants (scarce food: `EXP_FOOD_INTERVAL=0.7`). `EXP_BENCH=50,100,300` runs the
  frame-time benchmark instead. Prints per-allele frequency (start, 25/50/75/100%, mean over seeds, sd, per-seed end).
  Read `EXP_OUT`, not stdout: the project's debug `print`s make piped/file output ~6x slower on Windows.
  Run several processes in parallel (one per mode/variant); 10 seeds x 600 s takes ~10 min per process with 15 in parallel.
- **Seeded runs are NOT bit-exact** even with `--fixed-fps 60` + `EVO_SEED`: the state first diverges at the first egg
  hatch (~4 s) because Area2D overlap/signal order picks a different food among several in range. Compare runs
  statistically (many seeds), not by digest.
- `Organism.die()` now returns early if already queued for deletion. Before, a cannibal kill plus a starvation tick
  could emit `organism_died` twice, so `SimulationManager.population_count` undercounted (UI showed 41 vs 52 actual)
  and failed the smoke test's counter check at tuned densities. The experiment uses the true live count anyway.
- Trait effects: see README "Selection pressures" (measured after the trade-offs spec, `Docs/Trade-offs and Environment.md`).

## Trade-offs, environment and display (spec: `Docs/Trade-offs and Environment.md`)
- Pure rules live in `Scripts/Systems/Ecology.gd` (static functions taking the GameConfig node as `cfg`; tested by
  `tests/test_ecology.gd`). Numbers: `GameConfig` ("TRADE-OFFS AND ENVIRONMENT"). Hawk rolls use the lizard's `rng` (the shared one).
- `Organism.die(cause)` records `death_cause` (starved / eaten / hawk) and calls `queue_free()` BEFORE emitting
  `organism_died`, so counting listeners never see the dying lizard still in the container (that was the "53 vs 54" label).
  `SimulationManager.deaths` counts by cause; invariant tested in the smoke test: founders + births - deaths = population.
- Environment controls (Food slider, Ground, Hawks, Show labels) are in `SimulationManager`; the Environment node's
  `set_habitat()` / `set_food_interval()` apply them. `EVO_HABITAT`, `EVO_HAWKS`, `EVO_LABELS`, `EVO_FOOD_INTERVAL`,
  `EVO_INSPECT=1` (select an adult before the shot) extend the screenshot gate. The Main node reads `EVO_*` after the
  Environment child is ready, so `_setup_environment_controls` re-applies habitat/food to it.
- The click-to-inspect box is `Scripts/UI/Inspector.gd` (in the always-processing UI layer, so it works while paused).
- Window is 1200x648 (project.godot display + canvas_items stretch): arena 800 px wide plus two 200 px panels, no overlap.
- Debug `print`s are gated by `Organism.DEBUG` / `Food.DEBUG` (false). They cost ~6x on the experiment; do not re-enable in loops.
- `GameConfig.cannibalism_enabled` (default true; `EXP_CANNIBALS=0` in the experiment) stops all cannibal predation. The
  experiment report now prints insect meals per lizard-second (2nd half), cannibal kills by prey stage and deaths by cause.
  Finding (2026-10-07, 10 seeds, sexual): cannibals do NOT regulate the population; see the report for numbers.
- Experiment extras: `EXP_HABITAT=grass|sand|rock`, `EXP_HAWKS=1`, `EXP_HAWK_RISK`, `EXP_HAWK_FACTOR`, `EXP_CANNIBAL_EFF`,
  `EXP_UPKEEP=slow,med,fast`, `EXP_MEALMULT=low,med,high`, `EXP_FOOD_ENERGY`, `EXP_FOOD_INITIAL`, `EXP_TRACE=1` (population
  trace of extinct runs). The report prints sd and `z` = (end mean - start mean) / sd across seeds. It now takes ~1-2 min
  for 10 seeds x 600 s (prints gated off); 14 processes in parallel on a 16-core box is fine.
  Runs that share an output file append to it: kill old processes before rerunning with the same `EXP_OUT`.
- Space cap + old age (spec `Docs/Space and Life History.md`): `GameConfig.space_cap` DEFAULTS TO 0 = NO LIMIT (decision 2026-10-08).
  When set, it stops `Organism.reproduce()` at eggs + juveniles + adults >= cap (`Ecology.can_lay`). The Space slider is 15-60 plus a
  "No limit" notch at 65 (`space_slider_no_limit`). `lifespan_seconds` 150 x 0.8-1.2 is rolled at hatch (`Ecology.DEATH_OLD_AGE`);
  shorter lives (60-90 s) make the founder cohort die together and 20-50% of runs go extinct. Experiment env: `EXP_SPACE`
  (0 = no cap), `EXP_LIFESPAN`. Multipliers 0.7 / 1.0 / 1.4 (break-even 0.048 / 0.067 / 0.071 must stay ordered).
- SPEED UPKEEP 0 / 3.5 / 7.5 (tuned 2026-10-09; sexual, 10 seeds x 600 s, no limit): `S` Plenty 0.75 (z +2.0), Default 0.48 (polymorphic),
  Scarce 0.5 s 0.16 (z -2.6). Fast wins the race for food but pays upkeep always. Old 0.9 made fast win everywhere (0.9-0.96); upkeep up to 3
  changed little. The flip needs fast ~7 (6: fast at Plenty, ~neutral Scarce; 8: slow at Default and Scarce). Side effect: `M` now follows
  food too (Plenty 0.78 z +2.7, Default neutral, Scarce 0.26) and populations are ~15 (was 27). Numbers: README "Selection pressures".
  Earlier finding (upkeep 0.9): `m` won at every food level because the population grows to each lizard's break-even; do not add mechanics.
- Population (~15) is NOT raised by bigger meals (food energy 40) or costlier eggs (`egg_cost` 30-50, hatchlings now start with
  it): both tried 2026-10-09, flat or lower population, more extinctions. Satiety (`satiety_enabled`, full ready adults skip
  insects) is OFF: it grew Plenty/asexual populations to ~24 but sexual extinctions went 1 -> 17 of 60 and the speed flip vanished.
  Without the "always eat below reproduction_energy" guard it was worse (waiting lizards fell out of mating readiness).
- Food naming: the small food (`Food.gd`) is drawn as tiny insects (was berries; the old "plant" wording is gone from code).
  Beetles (`Bug.gd`, not a .tscn) are large prey only adults eat (`Ecology.can_eat_bug`), 60 energy, no cannibal penalty
  (cannibals get `cannibal_insect_efficiency` 0.6 only from small insects). `GameConfig.body_size` 0.5 shrinks ONLY the
  sprite + collision (root `scale` is game logic: drain, sensing, cannibal size rule). Measured 2026-10-09 (10 seeds x 600 s):
  beetle speed 15 erased the Scarce speed trend (fast lizards catch beetles); 10 keeps speed and metabolism flips, populations
  Default 17 / Plenty 22 / hawks 14-18. 30-seed recheck (seeds 11-40, 10 px/s): food rows 0 of 90 extinct, but HAWK rows 9 of 90
  (Grass 5, Sand 1, Rock 3). NOT a regression: the old game (body 1, no beetles) on the same seeds is 10 of 90, shrink-only 8,
  full-size + beetles 4. Hawk rows went ~10% extinct all along; the "1 of 30" baseline was lucky seeds 1-10. Extinct runs crash
  in the first minute (24 founders -> 4-12; exposed lizards last ~50 s at risk 0.02; Grass worst, green is the rarest founder
  color), then fade. Speed z per 15 seeds: Scarce -1.5/-1.4, Plenty +0.7/+1.6.
- Hawk extinctions are an ALLEE TRAP, not hawk strength (2026-10-10; `EXP_TRACE=1` now prints a 20 s census of extinct runs:
  stages, ready adults, camouflaged, births and deaths by cause). The 24 founders hatch together and many starve in the first
  minute; hawks add a few deaths, pushing the population to 3-8 adults. Then 2-4 adults sit "ready" for minutes with almost no
  births: mating needs a partner within mate_radius 90 px of the 800x600 arena, and selfing needs 20 s of UNBROKEN readiness
  (`_mate_wait` resets whenever energy dips below reproduction_energy). Hawk risk 0.012-0.02 and a 60 s ramp
  (`hawk_ramp_seconds`, kept for play) all gave 5-9 of 90. Untested fixes: ready adults seek each other; do not reset the
  selfing wait on a dip; stagger the founder hatch.
- Hawk default risk is 0.02 (was 0.006: color selection was weak). Color z: Grass +2.3, Sand +4.3, Rock +9.9; one Sand extinction in 10.
- Drift at N of 20-30 is large (sd 0.2-0.3 across seeds), so a trait must move the mean by 0.4-0.6 to count as 2 sd.
- Extinction at the invariant scale: food rows (no hawks) ~0 (0 of 90, seeds 11-40); hawk rows started from founders ~10% (see
  beetles bullet). Judge extinction rates on 30+ seeds: 10 seeds gave 1 of 30 hawk runs where the true rate is ~10%.
