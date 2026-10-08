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
- **Tests:** `GODOT=../Godot_v4.5-stable_win64.exe bash tests/run_all_tests.sh` (each suite is
  `../Godot_v4.5-stable_win64.exe --headless --path . --script tests/test_x.gd`). Test scripts must not
  name `Organism`/`SimulationManager` as types (autoloads are not identifiers when they compile); use
  `root.get_node("/root/GameConfig")` after `await get_root().ready`.
- **Screenshot gate (not headless):** `EVO_SHOT=<png> EVO_MODE=sexual|asexual EVO_SECONDS=90 EVO_SEED=n
  ../Godot_v4.5-stable_win64.exe --path .` runs at 4x time scale, saves the viewport, quits.
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
  Env: `EXP_SEEDS=1,2,3,4,5` `EXP_SECONDS=600` `EXP_MODES=sexual,asexual` `EXP_SCALE=4` and `EXP_FOOD_INTERVAL` /
  `EXP_FOOD_MAX` / `EXP_FOUNDERS` for variants (scarce food: `EXP_FOOD_INTERVAL=0.7`). `EXP_BENCH=50,100,300` runs the
  frame-time benchmark instead. Prints per-allele frequency (start, 25/50/75/100%, mean over seeds, sd, per-seed end).
  Read `EXP_OUT`, not stdout: the project's debug `print`s make piped/file output ~6x slower on Windows.
  Run several processes in parallel (one per mode/variant); 10 seeds x 600 s takes ~8 min per process.
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
  experiment report now prints plant meals per lizard-second (2nd half), cannibal kills by prey stage and deaths by cause.
  Finding (2026-10-07, 10 seeds, sexual): cannibals do NOT regulate the population; see the report for numbers.
- Experiment extras: `EXP_HABITAT=grass|sand|rock`, `EXP_HAWKS=1`, `EXP_HAWK_RISK`, `EXP_HAWK_FACTOR`, `EXP_CANNIBAL_EFF`,
  `EXP_UPKEEP=slow,med,fast`, `EXP_MEALMULT=low,med,high`, `EXP_FOOD_ENERGY`, `EXP_FOOD_INITIAL`, `EXP_TRACE=1` (population
  trace of extinct runs). The report prints sd and `z` = (end mean - start mean) / sd across seeds. It now takes ~1-2 min
  for 10 seeds x 600 s (prints gated off); 14 processes in parallel on a 16-core box is fine.
  Runs that share an output file append to it: kill old processes before rerunning with the same `EXP_OUT`.
- Why the environment effects are weaker than the spec guessed: food only sets the population SIZE (population is
  food-limited, ~45 at Plenty, ~30 default, ~20 Scarce), not how often one lizard eats (about one meal per 12 s at every
  level), so the break-even for metabolism barely moves with food. Drift at N of 20-30 is large (sd 0.2-0.3 across seeds),
  so a trait must move the mean by 0.4-0.6 to count as 2 sd. A real flip needs a population cap (`GameConfig.max_organisms`
  exists but is unused) so Plenty leaves food surplus; the spec said not to add mechanics, so that was not done.
- Extinction: ~3% of default runs and ~10% of hawk or Scarce runs go extinct (drift at small N, and fast lizards fixing
  the upkeep cost shrinks N). Scarce interval 0.5 is the lowest food level that mostly survives; 0.6-0.7 loses 15%.
