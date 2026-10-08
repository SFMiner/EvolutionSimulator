# Trait Trade-offs, Environment Controls and Display Fixes (spec)

Goal: every heritable trait except growth rate should have a real cost **and** a real benefit, and
the **environment** decides which side wins. Students change one environment control and watch the
direction of selection flip, so selection is clearly tied to the environment. Growth rate stays
as the "balanced trade-off" example, and is documented as such. Builds on `fb31c7a` (tuned ecology)
and `Docs/Genetics v2 - Diploid + Mating.md`.

All new numbers go in `GameConfig` (single source of truth). Starting values below are guesses;
tune them with `tests/experiment_selection.gd` until the acceptance table passes.

## Phase A: Trade-offs

### Environment controls (new, in GameConfig + UI)
| Control | Values | Effect |
|---|---|---|
| Food | slider, "Scarce" to "Plenty"; maps to `food_spawn_interval` about 1.0 s to 0.25 s (default stays 0.35) | how many meals there are |
| Habitat | Grass / Sand / Rock | background color of the arena: green / brown / gray |
| Hawks | Off / On (default Off) | predation that favors camouflage |

Changes apply immediately. Put them in the empty space of the right panel under the mutation slider.
Plain short labels for middle-schoolers.

### Per trait
- **Metabolism** (low/medium/high): high metabolism still drains more per second (1/2/3), but now
  gets **more energy per meal** (multiplier, start low 0.7 / medium 1.0 / high 1.4 applied to
  `food_energy_value` and juvenile meal energy). Expected: **plenty of food → `M` rises; scarce → `m` rises.**
- **Speed** (slow/medium/fast): add an **upkeep drain** for moving (start slow 0 / medium +0.4 /
  fast +0.9 per second, scaled by body size like metabolism). Fast still reaches food first.
  Expected: **scarce food (competition) → `S` rises; plenty → `s` rises or neutral.** If it tunes out
  the other way round, that's fine; report which way and make the README say what actually happens.
- **Cannibal** (kk): cannibals get **less energy from plant food** (start 0.6x). Prey energy stays as
  it is. Expected: **plenty → `K` rises; scarce and crowded → `k` rises.**
- **Color** (brown/green/gray): **camouflage against hawks**. An organism is camouflaged when its
  color matches the habitat (green on Grass, brown on Sand, gray on Rock). With Hawks On, each
  organism (juvenile or adult, not eggs) has a per-second chance of being caught: `hawk_risk`
  (start 0.01/s) times 0.25 if camouflaged. Hawk kills go through `die()`, with a short visible cue
  (e.g. a dark shadow or "X" flash, tween-based; no `await create_timer`, see Gamedev CLAUDE.md).
  Cannibals also find camouflaged prey less often (halve their detection of camouflaged prey) if this
  is easy to add; skip it if not. Use the shared SimulationManager RNG for hawk rolls.
  Expected: **Hawks On + Grass → `Cg` rises; Sand → `Cb` rises; Rock → `Cy` rises (slowly, recessive);
  Hawks Off → drift.**
- **Growth rate:** unchanged; keep as the balanced-trade-off example.

Births/deaths stats: count deaths by cause (starved / eaten by cannibal / hawk) and show them under
"Births so far" (e.g. "Deaths: starved 40 · eaten 6 · hawks 12").

### Acceptance (experiment script, 10 seeds x 600 s, sexual mode; asexual 5 seeds as a spot check)
Extend `tests/experiment_selection.gd` with env vars for the new controls (`EXP_FOOD_INTERVAL` exists;
add `EXP_HABITAT`, `EXP_HAWKS`). Report mean end frequency and the sd across seeds; "rises" means the
mean moves at least 2 sd (of the seed spread) away from the start in the stated direction.
| Run | Must show |
|---|---|
| Plenty (interval 0.25) | `M` rises; `K` rises |
| Scarce (interval ~0.8, pick so the population survives) | `m` rises; `k` rises; report `S` |
| Default (0.35) | NOT every locus fixes within 5 min: at least metabolism or speed stays between 0.15 and 0.85 at 300 s in the mean |
| Hawks On, Grass / Sand / Rock | `Cg` / `Cb` / `Cy` rises respectively (Rock: report even if slower) |
| Hawks Off | color stays within drift (as now) |
Population: no extinction in any default or Plenty run; the Scarce and Hawks runs must not go extinct
in more than 1 of 10 seeds (lower `hawk_risk` if they do). Report populations as before.

If an expectation can't be met by tuning numbers, stop tuning that trait and report what happens
and why, instead of adding more mechanics.

### Tests (fast suites)
- `EvoGenetics`-style unit tests for the pure parts: meal-energy multiplier by metabolism and cannibal,
  speed upkeep, camouflage match table (3 habitats x 3 colors), hawk risk with/without camouflage. Put the
  pure functions somewhere testable (e.g. a small `Scripts/Systems/Ecology.gd` with static functions)
  rather than inline in `Organism.gd`.
- Smoke test still passes in both modes; add one short run with Hawks On.

## Phase B: Display fixes (pre-existing problems; do after Phase A passes)
1. **Energy labels:** show whole numbers (no `36.9999999701977`). Hide the per-organism energy
   label and gene tags by default; add a "Show labels" checkbox (off). At 70+ lizards they are an
   unreadable pile.
2. **Gene tags:** the scene node is misspelled `metbolism`, so the metabolism tag never updates; fix
   the node name (and any reference). The color tag must show too. Check all five tags work with labels on.
3. **Inspect one lizard:** clicking a lizard shows a small info box (genotype in allele letters, e.g.
   `Mm Ss gg CbCy Kk`, the phenotype words, energy, state). Clicking empty space closes it. This
   replaces needing labels on everything.
4. **Population counter:** shows "Population: 53 (Actual: 54)". Find the off-by-one, fix it at the
   source, and show one number.
5. **Food art:** food uses the Godot placeholder icon. Draw a simple food item in code (e.g. a small
   green leaf or berry via `_draw`), no new image assets.
6. **Layout:** the left panel overlaps the arena by about 24 px; make the arena and panels not overlap
   at the project's window size.
7. Remove or gate the debug `print`s in the per-frame and per-tick paths (Organism, OrganismAI, Food):
   they also slow the experiment ~6x. Keep a single `const DEBUG := false` style switch if useful.

## Done when
Editor scan clean; `tests/run_all_tests.sh` passes 3 times in a row; headless `--quit-after 600`
clean with exit 0; screenshots: default, Hawks On + Sand after 300 s, and labels-on + inspector;
README "Selection pressures" table and checklist updated; project CLAUDE.md updated. No commit.
