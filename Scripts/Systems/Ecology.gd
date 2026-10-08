class_name Ecology
extends RefCounted
## Pure, testable ecology rules (trade-offs and environment). All numbers live in GameConfig;
## every function that needs them takes the config node (the GameConfig autoload) as `cfg`
## so tests can call these without naming the autoload as an identifier.

enum Habitat { GRASS, SAND, ROCK }

## Lizard color that blends in with each habitat.
const CAMOUFLAGE_COLOR: Dictionary = {
	Habitat.GRASS: "green",
	Habitat.SAND: "brown",
	Habitat.ROCK: "gray",
}

const HABITAT_NAMES: Dictionary = {
	Habitat.GRASS: "Grass",
	Habitat.SAND: "Sand",
	Habitat.ROCK: "Rock",
}

const HABITAT_COLORS: Dictionary = {
	Habitat.GRASS: Color(0.2, 0.42, 0.2),
	Habitat.SAND: Color(0.62, 0.5, 0.3),
	Habitat.ROCK: Color(0.45, 0.45, 0.48),
}

const DEATH_STARVED: String = "starved"
const DEATH_EATEN: String = "eaten"
const DEATH_HAWK: String = "hawk"
const DEATH_OLD_AGE: String = "old_age"


## Plant meals per second a lizard of this metabolism needs to just break even at full size
## (drain / (meal multiplier x meal energy)). Must be ordered low < medium < high.
static func break_even_intake(cfg: Node, metabolism: String) -> float:
	var rates: Dictionary = cfg.energy_depletion_rates
	var drain: float = float(rates.get(metabolism, 0.0))
	var meal: float = float(cfg.food_energy_value) * meal_multiplier(cfg, metabolism, false)
	return drain / maxf(meal, 0.0001)


## Seconds of life after hatching: lifespan_seconds times a random factor from the lizard's rng.
static func roll_lifespan(cfg: Node, rng: RandomNumberGenerator) -> float:
	var spread: float = float(cfg.lifespan_spread)
	return float(cfg.lifespan_seconds) * rng.randf_range(1.0 - spread, 1.0 + spread)


## True if there is room for a new egg (live = eggs + juveniles + adults; cap <= 0 means no cap).
static func can_lay(cfg: Node, live_count: int) -> bool:
	var cap: int = int(cfg.space_cap)
	return cap <= 0 or live_count < cap


## Multiplier on the energy of a plant meal: metabolism pays off, cannibals digest plants poorly.
static func meal_multiplier(cfg: Node, metabolism: String, cannibal: bool) -> float:
	var table: Dictionary = cfg.meal_multiplier_by_metabolism
	var mult: float = float(table.get(metabolism, 1.0))
	if cannibal:
		mult *= float(cfg.cannibal_plant_efficiency)
	return mult


## Extra energy per second for being fast, scaled by body size like the metabolism drain.
static func speed_upkeep(cfg: Node, speed: String, body_scale: float) -> float:
	var table: Dictionary = cfg.speed_upkeep_by_speed
	return float(table.get(speed, 0.0)) * body_scale


static func camouflage_color(habitat: int) -> String:
	return str(CAMOUFLAGE_COLOR.get(habitat, ""))


static func is_camouflaged(color: String, habitat: int) -> bool:
	return color == camouflage_color(habitat)


## Chance per second that a hawk catches one lizard (0 when hawks are off).
static func hawk_risk(cfg: Node, camouflaged: bool) -> float:
	if not bool(cfg.hawks_on):
		return 0.0
	var risk: float = float(cfg.hawk_risk)
	if camouflaged:
		risk *= float(cfg.hawk_camouflage_factor)
	return risk


static func habitat_color(habitat: int) -> Color:
	return HABITAT_COLORS.get(habitat, Color(0.2, 0.3, 0.2)) as Color


static func habitat_name(habitat: int) -> String:
	return str(HABITAT_NAMES.get(habitat, "Grass"))


## Food slider position (0 = scarce, 1 = plenty) <-> seconds between food spawns.
static func food_interval_from_slider(cfg: Node, value: float) -> float:
	return lerpf(float(cfg.food_interval_scarce), float(cfg.food_interval_plenty), clampf(value, 0.0, 1.0))


static func slider_from_food_interval(cfg: Node, interval: float) -> float:
	var lo: float = float(cfg.food_interval_scarce)
	var hi: float = float(cfg.food_interval_plenty)
	return clampf((interval - lo) / (hi - lo), 0.0, 1.0)


static func food_word(interval: float) -> String:
	if interval >= 0.8:
		return "scarce"
	if interval >= 0.5:
		return "low"
	if interval >= 0.3:
		return "normal"
	return "plenty"
