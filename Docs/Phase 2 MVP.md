# Evolution Simulator - Phase 2 MVP Definition

Phase 2 is about taking the **foundation from Phase 1** (organisms with lifecycle states) and giving them the **core survival loop**: energy → movement → food → death. This creates the first playable simulation cycle.

---

## Phase 2: Core Mechanics (Days 4-7)

### MVP Goal
Organisms that **move around the environment, consume food to survive, and die if they run out of energy**. This establishes the first closed gameplay loop.

---

### Milestone 2.1: Energy System
- Add `energy` variable to each organism.
- Implement passive energy depletion (timer-based).
- Create an energy bar above organisms (UI element).
- Death triggers when energy ≤ 0.

**Test Success**: Organisms slowly lose energy and disappear when empty.

---

### Milestone 2.2: Movement System
- Implement basic **wander behavior** (random directions).
- Add collision with walls (bounce/redirect).
- Smooth movement with acceleration/deceleration.
- Introduce simple **speed trait placeholder** (different speeds for variety).

**Test Success**: Organisms move around naturally instead of standing still.

---

### Milestone 2.3: Food System
- Create **Food scene** (simple sprite + Area2D).
- Implement **food spawner** with timer for random placement.
- Eating food restores energy on collision.
- Food disappears when eaten.

**Test Success**: Organisms collide with food, energy bar refills, and they live longer.

---

### Phase 2 Deliverable
A working simulation where:
- Organisms wander randomly.  
- Energy decreases over time.  
- Food spawns in the environment.  
- Organisms can eat food to survive.  
- Organisms die when energy is depleted.  

This MVP establishes the **core survival cycle**:  
**Eat → Move → Burn Energy → Die**  

---

## Phase 2 in the Bigger Picture
- **Sets up natural selection:** Organisms that move more efficiently survive longer.  
- **Prepares for Phase 3 (Genetics):** Traits like metabolism, speed, and growth can be tied into existing systems.  
- **Provides a classroom demo-ready loop:** Students can already watch survival dynamics (even without reproduction).  
