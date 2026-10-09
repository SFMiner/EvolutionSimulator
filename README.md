# Evolution Simulator

A simple evolution simulation built in Godot 4.5 that demonstrates natural selection through a population of organisms with inheritable traits.

## Project Overview

This simulator creates a sandbox environment where organisms (lizards) hatch, grow, search for food, reproduce, and die. Each organism has genetic traits that affect their survival and reproduction, leading to observable evolution over generations.

## Features

### Core Systems (Phase 1 - Complete)
- **Organism Lifecycle**: Egg → Juvenile → Adult → Death with visual scaling
- **Energy System**: Organisms lose energy over time and gain energy by eating food
- **Genetics & Mutation**: diploid genes (allele pairs with dominance) via the Genome Engine, plus mutation
- **Food System**: Food spawns periodically and can be consumed by organisms
- **Reproduction**: Adults with enough energy reproduce by proximity mating (default) or by cloning (20 energy egg cost)
- **Population Tracking**: Real-time population and generation counters
- **Visual Animation System**: Spritesheet-based animations with directional movement

### Genetic Traits
- **Metabolism**: Affects energy depletion rate (low/medium/high)
- **Speed**: Affects movement speed (slow/medium/fast)
- **Growth Rate**: Affects time to reach adulthood (slow/normal/fast)
- **Color**: Camouflage (green/brown/gray): a lizard whose color matches the ground is caught far less often by hawks
- **Cannibal**: Eats lizards at most half its size, but gets less energy from tiny insects (it is built for big prey; beetles still give it the full meal)

### User Interface
- **Environment controls** (right panel): Food slider (Scarce to Plenty), Ground (Grass / Sand / Rock), Hawks (off / on), Show labels
- **Inspector**: click a lizard to see its genes (e.g. `Mm Ss gg CbCy Kk`), traits, energy and state; click empty ground to close
- **Population Counter**: Shows current number of organisms
- **Generation Counter**: Shows the highest generation reached
- **Spawn Button**: Manually spawn new organisms
- **Pause/Resume**: Control simulation speed

## Installation & Setup

### Prerequisites
- Godot 4.5 (beta) or later
- Windows 10/11 (tested on Windows 10.0.26100)

### Quick Start
1. Open Godot 4.5
2. Import the project by selecting the `project.godot` file
3. Press F5 or click "Play" to run the simulation
4. Watch organisms hatch, grow, move, eat, and reproduce!

### Manual Setup (if needed)
If the autoload doesn't work automatically:
1. Go to Project → Project Settings → Autoload
2. Add `Scripts/Systems/GameConfig.gd` as "GameConfig"

### What You'll See
- **Small white eggs**: Eggs (stationary, 20% scale)
- **Growing yellow lizards**: Juveniles (moving, gradually scaling from 20% to 100%)
- **Full-sized colored lizards**: Adults (green/brown/gray based on genetics, 100% scale)
- **Tiny red-orange insects (ants)**: Food items, each facing a random direction (drawn in code)
- **Brown beetles**: Large prey about hatchling size, worth 60 energy (an insect is 30). Only adults can eat them. They crawl at 10 px/s (`GameConfig.bug_speed`). Everything is drawn at half size (`GameConfig.body_size`, 0.5); ecology numbers are unchanged
- **Animated movement**: Lizards walk with directional animations
- **Right panel**: Population and generation counters

## Project Structure

```
evolution-simulator/
├── Docs/                          # Project documentation
│   ├── implementation-plan.md     # Detailed development plan
│   ├── Phase 1 MVP -- Evolution Simulator.md
│   ├── Phase 1 MVP – Development Checklist.md
│   └── Lightweight & Modular Recommendations.md
├── Scenes/                        # Godot scene files
│   ├── Main.tscn                 # Main simulation scene
│   ├── Environment.tscn          # Environment with food spawning
│   ├── Organism.tscn             # Individual organism scene
│   └── Food.tscn                 # Food item scene
├── Scripts/                       # GDScript files
│   ├── Systems/
│   │   └── GameConfig.gd         # Configuration singleton
│   ├── Organisms/
│   │   └── Organism.gd           # Organism behavior and genetics
│   ├── Environment/
│   │   ├── EnvironmentManager.gd # Food spawning and environment
│   │   └── Food.gd               # Food behavior
│   └── UI/
│       └── SimulationManager.gd  # Main simulation controller
├── Assets/                        # Art assets (placeholder)
├── UI/                           # UI assets
├── Data/                         # Data files
└── project.godot                 # Godot project file
```

## How It Works

### Organism Lifecycle
1. **Egg Stage**: Organisms start as eggs (white sprites, 20% scale, stationary)
2. **Juvenile Stage**: After growth timer, become juveniles (yellow sprites, gradually scaling from 20% to 100%, animated movement)
3. **Adult Stage**: After second growth timer, become adults (colored based on genetics, 100% scale, animated movement)
4. **Death**: Occurs when energy reaches zero, when a cannibal or hawk catches the lizard, or at old age

### Energy System
- Energy depletes every second based on metabolism trait
- Low metabolism: 1.0 energy/second
- Medium metabolism: 2.0 energy/second  
- High metabolism: 3.0 energy/second
- Eating food restores 30 energy times the metabolism multiplier (low 0.7, medium 1.0, high 1.4), times 0.6 for cannibals. Break-even meals per second (drain / multiplier / 30) are ordered low 0.048 < medium 0.067 < high 0.071, so thrifty lizards need the fewest meals (tested in `test_ecology.gd`)
- Old age: each lizard lives `lifespan_seconds` (150) x a random 0.8-1.2 from hatching (eggs do not age, not heritable), then dies of old age
- Fast lizards pay an extra upkeep per second (slow 0, medium 3.5, fast 7.5 energy per second, scaled by body size; on top of the 1-3 metabolism drain)
- With Hawks on, each juvenile or adult has a 2% per second chance of being caught, 5% of that when its color matches the ground
- Maximum energy is 100

### Reproduction
- Adults with 80+ energy can reproduce
- Space cap (`GameConfig.space_cap`, default 0 = no limit; Space slider 15-60 plus a "No limit" notch at the right end): when set, while eggs + juveniles + adults >= the cap, no new eggs are laid (no mating, selfing or cloning: "no room for new nests"). Lowering the slider never kills anyone
- Reproduction costs 20 energy points
- Sexual (default): the nearest other ready adult within 90 px is the mate; the offspring is a cross of both parents' genes. The initiator pays 20 energy, the partner 5.
- No mate nearby: keep the energy and retry; after 20 s of waiting the organism self-fertilizes.
- Asexual (toggle): a clone of the parent, with mutation.
- Mutation: 5% per allele per gamete (or per clone copy), adjustable 0-20% in the UI

### Food System
- Food (tiny insects) spawns every 0.35 seconds by default (`GameConfig.food_spawn_interval`, the Food slider changes it from 1.0 s to 0.25 s), capped at 150 alive (`food_max`); 30 items are placed at the start (`food_initial`)
- Random positions within the environment
- Organisms detect food within a 200-pixel radius (scaled by their size)
- Organisms move toward detected food
- Food disappears when consumed

## Current Status

### ✅ Completed (Phase 1 MVP)
- [x] Project setup and folder structure
- [x] Organism lifecycle system (Egg → Juvenile → Adult → Death)
- [x] Energy and resource system with metabolism-based depletion
- [x] Genetics and mutation system (4 traits with inheritance)
- [x] Food spawning system with detection and consumption
- [x] Basic UI with population and generation tracking
- [x] Pause/resume functionality
- [x] Manual organism spawning
- [x] Basic movement AI system (wander + food seeking)
- [x] Complete simulation loop with natural selection
- [x] Visual scaling system (eggs start small, gradual growth to adulthood)
- [x] Spritesheet-based animation system with directional movement
- [x] Reproduction energy cost system (20 energy per reproduction)
- [x] Visual feedback for food consumption and organism states

### 🎯 Phase 1 Goals Achieved
✅ **Minimum working evolutionary loop**: Organisms hatch, grow, move, eat, reproduce, and die with inheritable traits affecting survival
✅ **Observable natural selection**: High metabolism organisms die faster without sufficient food
✅ **Trait inheritance**: Offspring inherit parent traits with 10% mutation chance per trait
✅ **Population dynamics**: Population fluctuates based on food availability and organism survival

### Genetics v2 (spec: `Docs/Genetics v2 - Diploid + Mating.md`)
- [x] Genome Engine vendored in `addons/genome/` (never edit; re-sync with `tools/sync_genome.sh`)
- [x] `EvoGenetics`: 5 loci (metabolism, speed, growth_rate, color, cannibal) with dominance
- [x] `organism.genotype` (diploid) with `organism.genome` kept as the expressed phenotype
- [x] Founder cannibal rate matched to the old 20% (p_k = sqrt(0.2)); color split matched to thirds
- [x] Proximity mating, self-fertilization fallback, cloning toggle
- [x] One seedable RNG in SimulationManager (`EVO_SEED`); single `GameConfig.mutation_rate`
- [x] Reproduction-mode toggle and mutation slider (0-0.2)
- [x] Allele-frequency graph with locus selector, genotype counts and birth stats
- [x] Tests in `tests/` (genetics, reproduction hooks, sim smoke) and `tests/run_all_tests.sh`
- [x] Screenshot gate `EVO_SHOT`
- [x] Ecology tuned for selection: 24 founders, food 0.35 s / cap 150, ecology numbers centralized in `GameConfig`; before the trade-offs population settled ~70-80; with them it settles ~30 at the default food (no space limit: Plenty ~40, Scarce ~22)
- [x] `tests/experiment_selection.gd`: seeded multi-run allele-frequency experiment + frame-time benchmark (see CLAUDE.md)
- [x] `Organism.die()` guard against double death (population counter was undercounting)
- [x] Trade-offs and environment (spec: `Docs/Trade-offs and Environment.md`): metabolism pays more per meal, speed has an upkeep, cannibals get less energy from tiny insects, color is camouflage against hawks
- [x] Environment controls: Food slider, Ground (Grass / Sand / Rock), Hawks on/off; deaths counted by cause (starved / eaten / hawks)
- [x] `Ecology.gd` holds the pure rules; `tests/test_ecology.gd` tests them
- [x] Display fixes: labels hidden by default ("Show labels" checkbox), whole-number energy, metabolism tag fixed, click-to-inspect box, one population number, food drawn in code, arena and panels no longer overlap (window 1200x648), debug prints gated by `DEBUG`
- [x] Space cap, old age and the metabolism retune (spec: `Docs/Space and Life History.md`): Space slider (15-60 plus "No limit", the default), "Population: n" or "n / cap", old-age deaths, inspector age, break-even ordering test, capped smoke run, `EXP_SPACE` / `EXP_LIFESPAN`
- [x] Speed is a real trade-off (2026-10-09): upkeep 0 / 3.5 / 7.5 makes fast `S` rise at Plenty (0.75), stay polymorphic at Default (0.48) and fall at Scarce (0.16). With the old upkeep (0.9) fast won everywhere. Metabolism now also moves with food as a side effect (see "Selection pressures")
- [x] Color flips with the environment (Hawks on, default risk 0.02: the color matching the ground rises; z +2.3 on Grass, +4.3 on Sand, +9.9 on Rock)
- [x] Extinction: 0 of 10 in every measured sexual row except Sand with hawks (1 of 10) and 0 of 5 asexual (1x-equivalent run, see below); the earlier 1-4 of 10 came from the broken 4x time scale
- [x] Time-scale invariant simulation: `GameConfig.set_sim_speed(scale)` raises the physics tick rate with the time scale; 1x, 4x and 8x measured equivalent (`tests/test_time_scale.gd`)
- [ ] Mate-seeking movement (out of scope by design)
- [ ] Speed-up control in the UI (only pause exists; the gate uses `GameConfig.set_sim_speed`)

### Selection pressures (measured at 1x-equivalent, i.e. `set_sim_speed(8)` on a verified time-scale-invariant simulation; sexual mode, 10 seeds x 600 sim-s per row; mean allele frequency at the end, start about 0.5 for M/S/K; z = (end - start) / sd across seeds; see CLAUDE.md for how to rerun)
| Trait | Cost / benefit in the code | Result |
|---|---|---|
| Metabolism | high drains 3/s vs low 1/s; a meal is worth x0.7 / 1.0 / 1.4 (low / medium / high); no space limit, lifespan 150 s | With the heavy speed upkeep (below) metabolism also follows food, a side effect (the earlier thrifty-everywhere result came with upkeep 0.9): Plenty `M` 0.49 to 0.78 (z +2.7), Default 0.55 (z +0.2, neutral), Scarce 0.5 s 0.26 (z -1.2). Where food is plentiful the big eater wins; where it is scarce the thrifty `m` leans ahead. Asexual (5 seeds): Plenty `M` 0.90 (z +6.2), Default 0.83 (z +2.2), Scarce 0.85 (z +1.7), so asexual favours `M` everywhere |
| Speed | fast 60 px/s vs slow 20; upkeep 0 / 3.5 / 7.5 energy per second (times body size) | A real trade-off that depends on food: sexual `S` Plenty 0.51 to 0.75 (z +2.0), Default 0.48 (z -0.1, polymorphic; 0.55 at 300 s), Scarce 0.5 s 0.16 (z -2.6, slow `s` rises). With hawks on, speed is neutral (0.40-0.51). Asexual (5 seeds): 0.75 Plenty, 0.63 Default, 0.46 Scarce. Why: fast lizards win races for food, but pay upkeep every second whether or not they eat; the race is worth it only when food is plentiful. Tuning history: upkeep 0.9 to 3 left fast on top everywhere (0.90-0.96); the flip needs a fast upkeep near 7 (6 gave fast at Plenty and about neutral at Scarce, 8 gave slow at Default and Scarce) |
| Growth rate | fast hatches in 4 s and needs 3 meals; slow gets 2x juvenile energy per meal but needs 8 | Slow-growing `g` leans ahead with no space limit: `G` 0.20 at Plenty (z -2.1), 0.18 Default (z -1.7), 0.33 Scarce 0.5 s (z -0.7). Asexual `G` 0.08 Plenty (z -18), 0.06 Default (z -7.2), 0.25 Scarce (z -2.1). Treat it as a lean, not a flip |
| Color | camouflage against hawks: risk 2%/s (default), x0.05 when the color matches the ground | The color matching the ground rises, and the effect grows with the hawk risk. At the default 0.02 (10 seeds): Grass `Cg` 0.24 to 0.73 (z +2.3), Sand `Cb` 0.19 to 0.77 (z +4.3), Rock `Cy` 0.59 to 0.97 (z +9.9). Earlier at risk 0.006 / 0.01 (before the speed retune): Grass +1.8 / +1.9, Sand +1.3 / +3.3, Rock +0.4 / +1.2, so a weaker hawk is hard to see through drift. Hawks off (Default): drift (`Cb` +0.3, `Cg` +0.4, `Cy` -0.7 z) |
| Cannibal | eats organisms <= half its size for their energy; x0.6 energy from tiny insects (not from beetles) | `K` (non-cannibal) rises everywhere: Plenty 0.76 (z +2.4), Default 0.84 (z +3.0), Scarce 0.5 s 0.85 (z +3.6); hawks runs z +1.7 to +2.8. Cannibals are never favored |

Populations (2nd-half mean, no space limit): Plenty 17, Default 15, Scarce 0.5 s 16, hawks rows 15-16 (the 3.5 / 7.5 speed upkeep costs a lot of energy, so populations are about half of the old 27 at Default; the number barely depends on food now, but insect meals per lizard-second do: 0.25 at Plenty, 0.21 Default, 0.13 Scarce). Asexual (5 seeds): Plenty 29, Default 25, Scarce 21. Extinctions: 0 of 10 in every sexual row (Default, Plenty, Scarce 0.5 s, hawks on Grass / Rock at risk 0.02) except Sand with hawks (1 of 10), and 0 of 5 asexual. The sd and z are across seeds, so z moves between repeats. Numbers from before 2026-10-08 were measured at a non-invariant 4x time scale and no longer apply.

What to teach with it:
1. Speed is a trade-off that depends on food: fast `S` rises at Plenty, slow `s` rises at Scarce, and the Default food keeps both (polymorphic). Fast lizards win the race for food but pay upkeep every second.
2. Color flips with the environment (hawks plus the ground color); the default hawk risk of 0.02 makes it clear (z +2 to +10).
3. Metabolism also follows food now, weakly (Plenty favours `M`, Scarce leans `m`); the effect is smaller than for speed, so use speed as the headline lesson.
4. Cannibals (`K` rises) and fast growth (`g` leans ahead) are never favored; they teach that not every trait pays.
5. The Space slider is the carrying capacity. It is optional (the default is no limit); capping it mainly changes the population size.
6. Populations are small (about 15) and drift is large; compare several runs or seeds before concluding, and use Asexual mode for cleaner trends.

### 🔄 Next Steps (Phase 2)
- Camera controls for observation (pan/zoom)
- Data visualization (population graphs)
- Movement system improvements
- Enhanced visual effects and polish
- Sound effects and audio feedback

### 📋 Future Phases
- **Phase 3**: Multiple environments and organisms
- **Phase 4**: Advanced genetics and selection pressures
- **Phase 5**: Player interaction modes
- **Phase 6**: Data analysis and statistics
- **Phase 7**: Visual polish and optimization

## Configuration

Key parameters can be adjusted in `Scripts/Systems/GameConfig.gd`:

```gdscript
var energy_depletion_rates = {
	"low": 1.0,
	"medium": 2.0, 
	"high": 3.0
}

var founder_count = 24
var food_spawn_interval = 0.35
var food_max = 150
var food_initial = 30
var reproduction_energy = 80
var reproduction_mode = ReproductionMode.SEXUAL  # or ASEXUAL
var mutation_rate = 0.05
var mate_radius = 90.0

# Trade-offs and environment
var meal_multiplier_by_metabolism = {"low": 0.7, "medium": 1.0, "high": 1.4}
var space_cap = 0                   # 0 = no cap (default)
var lifespan_seconds = 150.0        # times a random 0.8-1.2 per lizard
var speed_upkeep_by_speed = {"slow": 0.0, "medium": 3.5, "fast": 7.5}
var cannibal_insect_efficiency = 0.6
var hawk_risk = 0.02                # per second, when hawks are on
var hawk_camouflage_factor = 0.05   # risk multiplier when the color matches the ground
var food_interval_scarce = 1.0
var food_interval_plenty = 0.25
```

## Testing

### Smoke Test Protocol
1. Run simulation for 2 minutes at 4x speed (`set_sim_speed`)
2. Verify organisms hatch, grow, eat, reproduce, and die
3. Check that traits affect survival (high metabolism organisms die faster)
4. Confirm population and generation counters update correctly
5. Test pause/resume functionality

### Expected Behaviors
- Population should fluctuate as organisms die and reproduce
- High metabolism organisms should die more quickly without sufficient food
- Color traits should be visible and inherited
- Generation counter should increase as new organisms are born

## Development Notes

- Built for Godot 4.5 beta - some syntax may differ from stable versions
- Uses hardcoded values instead of autoload for simplicity
- Spritesheet-based animations with lizard sprites
- Modular design allows easy extension of systems

## Contributing

This is an educational project. Feel free to:
- Report bugs or issues
- Suggest improvements
- Add new features following the modular design
- Improve documentation

## License

Educational project - feel free to use and modify for learning purposes.
