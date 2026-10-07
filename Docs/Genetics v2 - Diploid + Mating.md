# Genetics v2: Diploid Genes and Proximity Mating (spec)

Goal: replace the single-value "genome" with real diploid genes (allele pairs with dominance) from
the shared Genome Engine. Add sexual reproduction by **proximity mating**, keeping cloning as a
toggle, so students can watch selection change **allele frequencies**, including recessive alleles
hiding in heterozygotes. Keeps the "lightweight" intent of `Lightweight & Modular
Recommendations.md`: no mate-seeking AI.

## Engine
- Vendor `addons/genome/` from `../genome-engine` with `bash tools/sync_genome.sh ../evolution-simulator`
  (run from genome-engine). Never edit the vendored copy.
- Engine API: `addons/genome/README.md`. Locus-id lists must be typed `Array[String]`.

## Genotype vs. the existing `genome` dict (compatibility rule)
- New: `organism.genotype: Dictionary` in engine shape `{locus_id: [allele, allele]}`.
- **Keep `organism.genome` as the expressed phenotype** in exactly today's shape and values
  (`metabolism` low/medium/high, `speed` slow/medium/fast, `growth_rate` slow/normal/fast,
  `color` green/brown/gray, `cannibal` bool). It is computed from `genotype` at birth. The ~35
  existing `genome` references (lookup tables, OrganismAI, UI tags) then keep working unchanged.

## Loci (define in one place, e.g. `Scripts/Genetics/EvoGenetics.gd`)
| Locus | Alleles | Dominance | Phenotype → `genome` value |
|---|---|---|---|
| metabolism | `M`, `m` | incomplete | MM high, Mm medium, mm low |
| speed | `S`, `s` | incomplete | SS fast, Ss medium, ss slow |
| growth_rate | `G`, `g` | incomplete | GG fast, Gg normal, gg slow |
| color | `Cb` > `Cg` > `Cy` | complete (hierarchy) | brown > green > gray (gray only as CyCy) |
| cannibal | `K`, `k` | complete | kk = cannibal (true); KK/Kk = false |

- Founders: `Genome.random_genotype` with allele weights. Pick cannibal weights so P(kk) matches
  today's founder cannibal probability (p_k = sqrt(old probability)). Use uniform weights for the
  other loci unless today's founder distribution differs; then match it and note that.
- Phenotype data entries carry `{"name": <the genome value string>}`; map `"true"`/`"false"` for cannibal to a bool.

## Reproduction
- `GameConfig` holds the single source of truth (today `Organism.mutation_chance` and
  `GameConfig.mutation_chance` can drift, so remove the duplicate):
  - `reproduction_mode`: `SEXUAL` (default) or `ASEXUAL`
  - `mutation_rate`: per allele per gamete (or per clone copy). Default 0.05, which is roughly
    today's 10% per-trait rate spread across two alleles.
  - `mate_radius` (px, default about 90) and the energy costs below.
- **ASEXUAL:** `Genome.clone_with_mutation(lib, genotype, rng, mutation_rate)`. Same timing and
  energy cost as today.
- **SEXUAL:** when an organism meets today's "ready to reproduce" conditions, find the nearest
  other ready adult within `mate_radius`. Use the existing spatial query or group iteration; no new
  movement AI. If one is found, the offspring is `Genome.cross(lib, a, b, rng, mutation_rate)`.
  The initiator pays today's egg cost (20), the partner pays a small cost (5), and both get
  today's reproduction cooldown. If no partner is in range, keep the energy and retry on the next
  check. **Prevent extinction-by-loneliness:** if a ready organism has found no partner for
  `self_fertilize_after` seconds (default 20), it self-fertilizes with
  `Genome.cross(lib, a, a, ...)`. Real organisms do this too, and it keeps sparse populations
  alive. Count matings, self-fertilizations and clones for the stats panel.
- Where reproduction happens (`Organism.reproduce()` emits `organism_reproduced(self,
  offspring_genome)`, then `SimulationManager._on_organism_reproduced` spawns): pass the
  **genotype** through instead and derive `genome` at spawn.
- RNG: one `RandomNumberGenerator` owned by SimulationManager (seedable, with an optional
  `EVO_SEED` env var), passed to all genetics calls. Remove global `randi()`/`randf()` from
  genetics paths. Movement and AI randomness may stay as it is.

## UI
- Reproduction-mode toggle (Sexual / Asexual) and a mutation-rate control (slider 0–0.2) in the
  existing UI. Changes apply to future births.
- **Allele-frequency graph:** extend `PopulationGraph` (or add a sibling panel) with a locus
  selector. It plots each allele's frequency (0–1) for the chosen locus over time, sampled on the
  population graph's interval. Also show the current genotype counts for that locus (e.g. "SS 12 ·
  Ss 20 · ss 5").
- Keep text short and plain (middle-school audience). Make it fit at the project's window size.

## Tests (`tests/`, `extends SceneTree`, headless, seeded)
- `EvoGenetics`: all genotype → `genome` mappings in the table (every pair, including the color
  hierarchy and cannibal kk); founder cannibal frequency is about the old rate over 10k samples.
- Crosses: Ss × Ss gives 1:2:1 speed classes (chi-square via `GenomeStats`); self-fertilization
  is legal; clone at mutation 0 is identical; mutation 1 always changes the allele.
- Allele-frequency helper (pure function over a list of genotypes) on hand-built populations.
- Headless sim smoke: seeded, about 60 simulated seconds per mode (SEXUAL, ASEXUAL). The population
  is still > 0 or extinction is reported clearly, there are no script errors, and births by mode are
  counted. If headless can't run the scene, use a short run with `--quit-after`.
- `tests/run_all_tests.sh` (same pattern as the other projects).

## Done when
Editor scan clean; tests pass; headless run clean; screenshot gate `EVO_SHOT=<png>` (optional
`EVO_MODE`, `EVO_SECONDS`) shows the graphs after a run; README checklist and a short CLAUDE.md
(vendoring rule, test command, the genotype/genome rule) are updated.
