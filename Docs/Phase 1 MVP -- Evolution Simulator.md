### Core Goal

Build a simple, functioning simulation where one type of organism (start with lizards) hatches, grows, searches for food, and reproduces — with a few inheritable traits that mutate across generations. This establishes the **simulation loop** and lays the groundwork for later organisms (e.g., insects) that reuse the same systems.

---

### Systems Included in MVP

1. **Organism System (Baseline)**
    
    - Organism lifecycle states: **Egg → Juvenile → Adult → Death**.
        
    - Visuals: simple sprites for each stage (purchased assets or placeholders).
        
    - Basic health/energy meter.
        
2. **Genetics & Mutation System (Minimal)**
    
    - A **genome with 3–4 traits** to start:
        
        - **Metabolism** (energy use vs. gain).
            
        - **Growth Rate** (time to adulthood).
            
        - **Speed** (movement speed).
            
        - **Color** (affects camouflage in certain backgrounds).
            
    - Each trait has 2–3 possible alleles.
        
    - On reproduction, offspring inherit traits with a small chance of mutation (switching allele).
        
3. **Environment System (Minimal)**
    
    - One **single enclosure** environment.
        
    - Static background color (camouflage interacts with color trait).
        
    - Food sources (basic prey items, stationary or slow-moving).
        
4. **Resource/Nutrition System**
    
    - Organisms must find food to gain energy.
        
    - Energy depletes over time (faster with high metabolism, slower with low).
        
    - If energy = 0 → organism dies.
        
    - If energy threshold reached → adult lays eggs.
        
5. **AI System (Organisms)**
    
    - Basic movement AI: wander, detect food in a small radius, move toward food.
        
    - Eating increases energy.
        
6. **Player Mode (Observation only for MVP)**
    
    - Player can watch organisms move and interact.
        
    - Controls:
        
        - Pause/unpause.
            
        - Speed up/slow down simulation.
            
        - Camera: zoom in/out, pan around.
            
7. **Data/Tracking System (Minimal)**
    
    - Track **population over time**.
        
    - Track **number of births and deaths**.
        
    - Simple bar/line graph display.
        

---

### Simplifications for Phase 1

- Only **lizards** as the first test organism. Insects and others will use the same systems later.
    
- No player control of organisms (that comes in Phase 3).
    
- No multiple environments yet (just one).
    
- Traits affect survival in basic, obvious ways (e.g., fast metabolism burns energy too quickly without enough food).
    

---

### Development Order (Step-by-Step)

1. **Core Organism Lifecycle**
    
    - Sprites for egg/juvenile/adult.
        
    - State machine transitions (egg → juvenile → adult → death).
        
2. **Environment Setup**
    
    - Simple rectangular enclosure.
        
    - Food items that respawn at intervals.
        
3. **Energy & Resource System**
    
    - Energy depletes over time.
        
    - Eating food restores energy.
        
    - Reproduction if energy threshold is reached.
        
4. **Genetics & Traits (3–4 to start)**
    
    - Define alleles for metabolism, speed, growth rate, color.
        
    - Pass alleles to offspring with mutation chance.
        
5. **AI for Organisms**
    
    - Wander behavior.
        
    - Detect and move toward nearby food.
        
6. **Observation Mode UI**
    
    - Camera controls (pan, zoom).
        
    - Pause/resume.
        
    - Simulation speed toggle.
        
7. **Basic Data Visualization**
    
    - Display population over time graph.
        
    - Display births and deaths counters.
        

---

### Deliverable of Phase 1

A simple sandbox where lizards hatch, grow, move around, eat, reproduce, and die. Traits (metabolism, speed, growth rate, color) affect survival in basic ways. Players can observe populations rise and fall, with a simple graph tracking dynamics.

This provides the **minimum working evolutionary loop**, which you can later expand with:

- More traits (vision, patterns, agility).
    
- More environments (lighting, predators, enclosure size).
    
- More organisms (insects, others, reusing the same lifecycle/trait/AI framework).
    
- Additional modes (participation, sandbox).