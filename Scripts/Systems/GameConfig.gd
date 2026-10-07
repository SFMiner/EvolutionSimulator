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
var food_initial: int = 5
var max_organisms = 50
var reproduction_energy = 80
var max_energy = 100
var food_energy_value = 30

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

# Helper function to get random array element
func get_random_element(array: Array):
	if array.size() > 0:
		return array[randi() % array.size()]
	return null
