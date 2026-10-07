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
