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
- **Color**: Visual trait that affects camouflage (green/brown/gray)

### User Interface
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
- **Green dots**: Food items
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
4. **Death**: Occurs when energy reaches zero

### Energy System
- Energy depletes every second based on metabolism trait
- Low metabolism: 1.0 energy/second
- Medium metabolism: 2.0 energy/second  
- High metabolism: 3.0 energy/second
- Eating food restores 30 energy
- Maximum energy is 100

### Reproduction
- Adults with 80+ energy can reproduce
- Reproduction costs 20 energy points
- Sexual (default): the nearest other ready adult within 90 px is the mate; the offspring is a cross of both parents' genes. The initiator pays 20 energy, the partner 5.
- No mate nearby: keep the energy and retry; after 20 s of waiting the organism self-fertilizes.
- Asexual (toggle): a clone of the parent, with mutation.
- Mutation: 5% per allele per gamete (or per clone copy), adjustable 0-20% in the UI

### Food System
- Green food items spawn every 2 seconds
- Random positions within the environment
- Organisms detect food within 32-pixel radius
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
- [ ] Mate-seeking movement (out of scope by design)
- [ ] Speed-up control in the UI (only pause exists; the gate uses `Engine.time_scale`)

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

var food_spawn_interval = 2.0
var max_organisms = 50
var reproduction_energy = 80
var reproduction_mode = ReproductionMode.SEXUAL  # or ASEXUAL
var mutation_rate = 0.05
var mate_radius = 90.0
```

## Testing

### Smoke Test Protocol
1. Run simulation for 2 minutes at 4x speed
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
