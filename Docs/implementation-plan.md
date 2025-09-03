# Evolution Simulator MVP - Implementation Plan

## Phase 1: Foundation (Days 1-3)

### Milestone 1.1: Project Setup
- Create Godot 4.5 project with folder structure
- Configure project settings (2D, resolution, physics)
- Import placeholder sprites (colored circles/squares)
- Create main scene structure

### Milestone 1.2: Organism Scene Architecture
```
Organism (Node2D)
├── Sprite2D (visual representation)
├── CollisionShape2D (for food detection)
├── Area2D (detection radius)
├── StateMachine (Node - manages lifecycle)
└── UI (Node2D - health bar, debug info)
```

### Milestone 1.3: State Machine Implementation
Create GDScript state machine with:
- States: Egg, Juvenile, Adult, Dead
- Transition timers
- Basic sprite switching per state
- State change signals

**Deliverable**: Organism that transitions through lifecycle stages on timer

## Phase 2: Core Mechanics (Days 4-7)

### Milestone 2.1: Energy System
- Add energy variable and depletion timer
- Create energy bar display
- Implement death on zero energy
- Test energy consumption rates

### Milestone 2.2: Movement System
- Implement basic wander behavior
- Add collision with walls (bounce)
- Smooth movement with acceleration
- Speed variation based on trait (placeholder)

### Milestone 2.3: Food System
- Create Food scene (collectible)
- Implement food spawner with timer
- Add collision detection for eating
- Energy restoration on consumption

**Deliverable**: Organisms that move, lose energy, eat food, and die

## Phase 3: Genetics (Days 8-10)

### Milestone 3.1: Genome Data Structure
```gdscript
var genome = {
	"metabolism": "medium",  # low/medium/high
	"speed": "medium",       # slow/medium/fast
	"growth_rate": "normal", # slow/normal/fast
	"color": "brown"         # green/brown/gray
}
```

### Milestone 3.2: Trait Effects Implementation
- Connect metabolism to energy depletion rate
- Connect speed to movement velocity
- Connect growth_rate to stage timers
- Apply color tint to sprite

### Milestone 3.3: Inheritance & Mutation
- Create reproduction trigger (energy threshold)
- Implement egg spawning with parent's genome
- Add mutation chance per trait
- Test trait passing across generations

**Deliverable**: Organisms with functional genetics affecting behavior

## Phase 4: Environment & AI (Days 11-13)

### Milestone 4.1: Environment Setup
- Create bounded play area
- Implement camera with boundaries
- Add background (for camouflage system)
- Create environment manager for food spawning

### Milestone 4.2: Improved AI
- Implement food detection radius
- Add seek behavior when food detected
- Smooth transition between wander/seek
- Priority system for multiple food items

### Milestone 4.3: Optimization
- Object pooling for food items
- Organism count limits
- Performance profiling
- LOD system for off-screen organisms

**Deliverable**: Complete simulation environment with smart organisms

## Phase 5: Observation Interface (Days 14-16)

### Milestone 5.1: Camera Controls
- WASD/Arrow key panning
- Mouse wheel zoom (with limits)
- Smooth camera movement
- Focus shortcuts (center view)

### Milestone 5.2: Simulation Controls
- Pause/resume functionality
- Speed control (1x, 2x, 4x, 8x)
- Visual speed indicator
- Keyboard shortcuts

### Milestone 5.3: HUD Implementation
- Control hints panel
- Current stats display (population, generation)
- Selected organism info
- Debug toggle for detailed stats

**Deliverable**: Fully controllable observation interface

## Phase 6: Data & Visualization (Days 17-19)

### Milestone 6.1: Data Collection
- Population tracking array
- Birth/death event logging
- Generation tracking per organism
- Trait distribution calculator

### Milestone 6.2: Graph System
- Create line graph for population
- Implement rolling time window
- Add axis labels and grid
- Real-time update system

### Milestone 6.3: Statistics Display
- Birth/death counters
- Average generation display
- Trait distribution bars
- Peak population tracker

**Deliverable**: Complete data visualization system

## Phase 7: Polish & Testing (Days 20-21)

### Milestone 7.1: Visual Polish
- Replace placeholder art
- Add particle effects (birth, death)
- Smooth animations for state changes
- Visual feedback for eating

### Milestone 7.2: Balance Testing
- Adjust energy consumption rates
- Fine-tune food spawn rates
- Balance reproduction thresholds
- Verify trait advantages are observable

### Milestone 7.3: Stability Testing
- Long-run simulation tests (30+ minutes)
- Edge case handling (0 population, overpopulation)
- Save/load system (if time permits)
- Performance optimization

**Final Deliverable**: Polished, stable MVP ready for classroom testing

## Code Architecture Guidelines

### Modular System Design
Each system should be a separate scene/script that can be:
- Tested independently
- Reused for different organism types
- Extended without breaking other systems

### Key Scripts Structure
```
Scripts/
├── Organisms/
│   ├── Organism.gd (base class)
│   ├── StateMachine.gd
│   ├── Genome.gd
│   └── OrganismAI.gd
├── Environment/
│   ├── EnvironmentManager.gd
│   ├── FoodSpawner.gd
│   └── Food.gd
├── UI/
│   ├── SimulationControls.gd
│   ├── DataVisualizer.gd
│   └── CameraController.gd
└── Systems/
    ├── EnergySystem.gd
    ├── ReproductionSystem.gd
    └── MutationSystem.gd
```

### Testing Checklist
- [ ] 10+ minute simulation without crashes
- [ ] Observable natural selection (3-5 generations)
- [ ] All traits visibly affect survival
- [ ] UI controls responsive at all speeds
- [ ] Graph accurately reflects population
- [ ] 30-50 organisms maintain 60 FPS

## Risk Mitigation

**Performance Issues**
- Start with 10-20 organisms, scale up gradually
- Implement organism pooling early
- Use signals sparingly, prefer direct references

**Scope Creep**
- Freeze feature list after Phase 1
- Save "nice-to-have" features for Phase 2
- Focus on core loop before polish

**Testing Time**
- Test each milestone before proceeding
- Keep debug UI accessible throughout
- Document bugs for post-MVP fixes
