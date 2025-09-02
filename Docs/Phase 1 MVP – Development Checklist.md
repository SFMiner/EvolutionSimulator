
### Step 1: Project Setup

-  Create a new Godot 4.5 project.
    
-  Set up project folders (Scenes, Scripts, Assets, UI, Data).
    
-  Import placeholder art (simple colored shapes or free assets for lizard, egg, food).
    

---

### Step 2: Organism Lifecycle

-  Create **Organism scene** with states: Egg → Juvenile → Adult → Death.
    
-  Implement a simple **state machine script** to handle lifecycle transitions.
    
-  Add timers or growth thresholds for moving between stages.
    
-  Basic sprite switching or scaling for each stage.
    

---

### Step 3: Energy & Resource System

-  Add **energy variable** to organisms.
    
-  Energy decreases over time.
    
-  Eating food increases energy.
    
-  If energy = 0 → trigger death state.
    
-  If energy ≥ reproduction threshold and organism is Adult → spawn egg(s).
    

---

### Step 4: Genetics & Mutation

-  Define a **Genome data structure** (e.g., dictionary with traits: metabolism, speed, growth, color).
    
-  Assign alleles at birth.
    
-  On reproduction, offspring inherit parent alleles with mutation chance.
    
-  Implement trait effects:
    
    - Metabolism → rate of energy loss.
        
    - Speed → movement speed.
        
    - Growth rate → time to adulthood.
        
    - Color → compare against environment background for camouflage effect (optional placeholder logic for MVP).
        

---

### Step 5: Environment & Food

-  Create **Environment scene** (rectangular enclosure).
    
-  Spawn **food items** at random positions at intervals.
    
-  Food disappears when eaten.
    

---

### Step 6: Organism AI

-  Implement basic **wander movement** (random direction changes).
    
-  Add simple **detection radius** for food.
    
-  If food detected → move toward food and eat it.
    
-  Otherwise → continue wandering.
    

---

### Step 7: Observation Mode (Player UI/Controls)

-  Add camera controls:
    
    - Zoom in/out.
        
    - Pan across environment.
        
-  Add simulation controls:
    
    - Pause/unpause button.
        
    - Speed toggle (1x, 2x, 4x).
        

---

### Step 8: Data Tracking & Visualization

-  Track population size over time.
    
-  Track number of births and deaths.
    
-  Display simple **line graph** for population over time.
    
-  Display **counters** for births and deaths.
    

---

### Step 9: Polish & Testing

-  Replace placeholder art with simple lizard/egg/food assets.
    
-  Playtest to ensure:
    
    - Organisms hatch, grow, reproduce, and die.
        
    - Traits affect survival in noticeable ways.
        
    - Graph updates correctly.
        
    - Simulation can run indefinitely without crashing.
        

---

### Deliverable for Phase 1 MVP

✅ A working sandbox simulation where lizards:

- Hatch, grow, eat, reproduce, and die.
    
- Inherit traits with mutations.
    
- Survive differently depending on those traits.
    
- Are observable by the player with basic camera controls and simple data graphs.