# Space Cap, Old Age and the Metabolism Retune (spec)

## Outcome (2026-10-08)
The metabolism allele did not flip with food, so we stopped trying. The space cap now defaults to no limit
(`space_cap` 0; the Space slider has a "No limit" notch and is an optional carrying capacity). Old age (150 s)
and the 0.7 / 1.0 / 1.4 meal values stay. Measured with no limit (sexual, 10 seeds x 600 s): `M` Scarce 0.5 s
0.49 to 0.18 (z -1.6), Default 0.37 (z -0.6), Plenty 0.46 (z -0.2); speed `S` rises with food (Plenty 0.88,
z +4.4); color flips with hawks plus ground (z +1.2 to +1.7). Why `M` stays level at Plenty: the population grows
until each lizard is back at break-even, and the type that needs the least food wins. Full table: README
"Selection pressures". The text below is the original plan, kept for the design.
(Update 2026-10-08: the results above were measured at a broken, non-invariant 4x time scale; the re-measured numbers are in the README.)

Builds on `8cec173` and `Docs/Trade-offs and Environment.md`. Goal: the metabolism allele must FLIP with
the environment (fast-living `M` wins when food is plentiful, thrifty `m` wins when it is scarce), the
classic "live fast vs. get by on little" trade-off.

## Why it does not flip now (measured, 2026-10-07)
The population is food-limited at every food level: all food is eaten, and the population grows until each
lizard gets about one meal per 10-12 s (its break-even). More food makes MORE lizards, not better-fed ones.
In a food-limited population the type with the lowest break-even intake wins:
break-even meals/s = drain / (multiplier x food_energy_value). With drain 1/2/3 and multipliers
0.55/1.0/1.9: low 0.061, medium 0.067, high 0.053. High is cheapest, so `M` wins everywhere.

## The fix (two parts, both needed)
1. **Metabolism retune.** Make low metabolism the cheapest to run: break-even must be ordered
   low < medium < high. Start from the original spec values 0.7 / 1.0 / 1.4 (break-even 0.048 / 0.067 / 0.071).
   High still gains energy fastest when meals are frequent: net gain is 42r - 3 vs 21r - 1 for r meals/s, so
   high beats low above r = 0.095. Keep this ordering invariant while tuning, and add a unit test for it in
   `tests/test_ecology.gd` (a pure `Ecology.break_even_intake(cfg, metabolism)` function).
2. **Space cap.** `GameConfig.space_cap` (start 35). When the live count (eggs + juveniles + adults, skip
   `is_queued_for_deletion()`) is at or above the cap, no new eggs are laid: no mating, no selfing, no
   cloning. Framed for students as "no room for new nests". Below the cap nothing changes. At Plenty the cap
   binds, so food piles up, each lizard eats more often, and `M` should win the race to refill after laying and
   to grow up. At Scarce the food limit (~20 lizards) is below the cap, so `m` should win.
3. **Old age** (needed so a capped population still turns over; without deaths nothing new hatches and
   selection stops). Each lizard gets a lifespan at hatch: `GameConfig.lifespan_seconds` (start 90) times a
   random factor 0.8-1.2 from the lizard's `rng`. It counts from hatching (eggs don't age). When it runs out the
   lizard dies with a new cause `Ecology.DEATH_OLD_AGE` ("old_age"). Not heritable. Tune it (60-150) so turnover
   is fast enough for selection to show within 600 s.

## UI
- Right panel, under the existing environment controls: a **Space** slider, 15 to 60 lizards, default
  `space_cap`, label like "Space: 35 lizards". Applies immediately (lowering it below the population just
  stops egg-laying until deaths bring it down; never kill lizards to fit).
- Population label: "Population: 34 / 35" (live / space).
- Deaths line gains old age: "Deaths: starved 40 · eaten 6 · hawks 12 · old age 30".
- Inspector shows age, e.g. "Age: 42 s of 95".

## Experiment
`tests/experiment_selection.gd`: add `EXP_SPACE` (cap; `0` = no cap, for comparison) and `EXP_LIFESPAN`.
Add old-age deaths to the report, and the fraction of time the population sits at the cap (2nd half).
Keep the diagnostic plant-meals-per-lizard-second line: at Plenty it should now rise well above the ~0.1
seen before; at Scarce it should stay near break-even. If it doesn't, the mechanism isn't working, so say so.

### Acceptance (10 seeds x 600 s, sexual; asexual 5 seeds as a spot check)
Same definitions as the trade-offs spec ("rises" = end mean at least 2 sd of the seed spread from start).
| Run | Must show |
|---|---|
| Plenty (0.25) | `M` rises; `K` rises |
| Scarce (pick an interval where population stays under the cap and survives; 0.5 was used before) | `m` rises; report `k`, `S` |
| Default (0.35) | at least metabolism or speed stays between 0.15 and 0.85 at 300 s in the mean |
| Hawks On, Grass / Sand / Rock | `Cg` / `Cb` / `Cy` rises (report even if weaker than before) |
| Hawks Off | color within drift |
Extinction: none in default or Plenty; at most 1 of 10 in Scarce and hawk runs.

Tuning knobs, in this order: `space_cap`, `lifespan_seconds`, the metabolism multipliers (within the
ordering invariant), the Scarce interval. If the metabolism flip still can't be met, stop and report what
happens and why (with the diagnostic numbers) rather than adding more mechanics.

## Tests and done-when
- `test_ecology.gd`: break-even ordering; old-age lifespan range; "can lay" is false at/above the cap.
- Smoke test: the invariant founders + births - deaths = population includes old age; add one short run
  with a low cap (e.g. 15) checking the live count never exceeds cap + eggs already laid in the same frame
  (i.e. stays <= cap after the first second).
- Editor scan clean; `tests/run_all_tests.sh` passes 3 times in a row; headless `--quit-after 600` exit 0.
- Screenshot at Plenty after 300 s showing the Space slider and "Population: n / cap".
- README "Selection pressures" table and checklist updated with measured results; project `CLAUDE.md`:
  replace the "Why the environment effects are weaker..." bullet with the new mechanism and numbers.
- No commit.
