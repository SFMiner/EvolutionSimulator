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
  Tuned (24 founders, food every 0.35 s, cap 150) so the true population settles around 70-80 in both modes
  (range ~45-105 over 10 seeds x 600 s, no extinctions), up from 2-5 with 5 founders.
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
- Trait effects (see README "Selection pressures"): metabolism and speed are selected hard; growth_rate is a wash;
  color has no effect at all (use it as the neutral drift yardstick); cannibal shows at most a weak edge under scarcity.
