extends Node

# Easy to adjust without touching code
var energy_depletion_rates = {
	"low": 1.0,
	"medium": 2.0,
	"high": 3.0
}

var movement_speeds = {
	"slow": 20,
	"medium": 40,
	"fast": 60
}

var growth_timers = {
	"slow": 10.0,
	"normal": 7.0,
	"fast": 4.0
}

# === ECOLOGY (tuned so selection is visible; see CLAUDE.md "Ecology tuning") ===
## Organisms spawned at start (and the size of one "founder" batch).
var founder_count: int = 24
## Seconds between food spawns, and the hard cap on food items alive at once.
var food_spawn_interval: float = 0.35
var food_max: int = 150
## Food items placed at the start.
var food_initial: int = 30
var max_organisms = 50
var reproduction_energy = 80
var max_energy = 100
var food_energy_value = 30

# === TRADE-OFFS AND ENVIRONMENT (see Docs/Trade-offs and Environment.md) ===
## Food slider range: seconds between food spawns at "Scarce" and at "Plenty".
var food_interval_scarce: float = 1.0
var food_interval_plenty: float = 0.25
## Habitat (Ecology.Habitat: 0 grass, 1 sand, 2 rock) and the hawk switch.
var habitat: int = 0
var hawks_on: bool = false
## Chance per second that a hawk catches a lizard; multiplied by the factor when camouflaged.
var hawk_risk: float = 0.02
var hawk_camouflage_factor: float = 0.05
## Metabolism pays: insect meal energy is multiplied by this (applies to adult and juvenile meals).
## Invariant (tested): break-even intake drain / (multiplier x meal) is ordered low < medium < high.
var meal_multiplier_by_metabolism: Dictionary = {"low": 0.7, "medium": 1.0, "high": 1.4}
## Speed costs: extra energy per second (times body scale).
var speed_upkeep_by_speed: Dictionary = {"slow": 0.0, "medium": 3.5, "fast": 7.5}
## Cannibals are built for big prey, so they get less energy from tiny insects: multiplier on insect meal energy
## (lizard prey and beetle energy are unchanged).
var cannibal_insect_efficiency: float = 0.6
## Diagnostic switch: false stops all cannibal predation (kk lizards just eat insects).
var cannibalism_enabled: bool = true
## Full adults (ready to breed and an insect meal would overflow max_energy) ignore insects. OFF by default:
## measured 2026-10-09 (10 seeds x 600 s) it raised extinctions from 1 to 17 of 60 sexual runs and erased the
## speed flip; only Plenty and asexual populations grew. Experiment knob: EXP_SATIETY=1.
var satiety_enabled: bool = false
## Running counters for the selection experiment (insect meals, cannibal kills by prey stage).
var diag: Dictionary = {"insect_meals": 0, "bug_meals": 0, "kill_egg": 0, "kill_juvenile": 0, "kill_adult": 0}
## Draws lizards, insects and beetles at this fraction of the original size (sprites and collision shapes only).
## Root `scale`, speeds and sensing distances are unchanged.
var body_size: float = 0.5
# === BUGS (energy-rich prey that only adults can eat; rules in Ecology.can_eat_bug / bug_meal) ===
## Switch for the whole bug mechanic.
var bugs_enabled: bool = true
## Energy of one bug before the metabolism multiplier (an insect is 30).
var bug_energy_value: float = 60.0
## One bug spawns every food_spawn_interval * bug_spawn_ratio seconds, so the Food slider scales bugs too.
var bug_spawn_ratio: float = 8.0
## Most bugs alive at once.
var bug_max: int = 12
## Bug walking speed in px/s (slow lizards move 20). Measured 2026-10-09 (10 seeds x 600 s): 15 erased the Scarce speed
## trend (fast lizards catch more bugs); 5 and 10 kept it; 10 also kept the metabolism flip.
var bug_speed: float = 10.0
## Bug collision radius in px before body_size is applied.
var bug_radius: float = 14.0
## Bugs placed at the start.
var bug_initial: int = 3
# === SPACE AND LIFE HISTORY (see Docs/Space and Life History.md) ===
## No new eggs while eggs + juveniles + adults >= space_cap ("no room for new nests"). 0 = no cap.
var space_cap: int = 0
## Range of the Space slider; the notch above space_cap_max means "No limit" (space_cap = 0).
var space_cap_min: int = 15
var space_cap_max: int = 60
var space_slider_no_limit: int = 65
## Seconds from hatching to old age, times a random factor 1 +/- lifespan_spread (not heritable).
var lifespan_seconds: float = 150.0
var lifespan_spread: float = 0.2
## Show the per-lizard energy number and gene tags.
var show_labels: bool = false
# === PROTOTYPE HOOKS (strain-season prototype, tests/prototype_strains.gd; defaults keep normal play unchanged) ===
## false: SimulationManager spawns no founder batch (the prototype places its own lizards).
var spawn_founders: bool = true
## true: an egg-laying event only counts (Organism.eggs_laid) and pays the egg cost; nothing is spawned.
var eggs_count_only: bool = false

# --- Genetics v2: single source of truth for reproduction settings ---
enum ReproductionMode { SEXUAL, ASEXUAL }

var reproduction_mode: ReproductionMode = ReproductionMode.SEXUAL
## Chance per allele per gamete (sexual) or per clone copy (asexual) of mutating.
var mutation_rate: float = 0.05
## Max distance in px to a ready adult for proximity mating.
var mate_radius: float = 90.0
## Energy the initiating parent pays (the egg) and the partner pays.
var egg_cost: float = 20.0
var partner_cost: float = 5.0
## Seconds a ready organism waits for a partner before self-fertilizing.
var self_fertilize_after: float = 20.0

# === SIMULATION SPEED ===
## Fast-forward the simulation. Engine.time_scale alone makes every 1/60 s physics step cover `scale` times
## more time, so lizards jump over food and Area2D overlaps are sampled too rarely: the biology changes.
## Raising the physics tick rate with the scale keeps each step at 1/60 simulated seconds, so a fast run
## is the SAME simulation, only faster. Always use this instead of setting Engine.time_scale directly.
func set_sim_speed(scale: float) -> void:
	var s: float = maxf(scale, 1.0)
	Engine.time_scale = scale
	Engine.physics_ticks_per_second = int(round(60.0 * s))
	Engine.max_physics_steps_per_frame = maxi(8, int(ceil(s)) * 4)

# Helper function to get random array element
func get_random_element(array: Array):
	if array.size() > 0:
		return array[randi() % array.size()]
	return null
