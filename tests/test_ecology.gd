extends SceneTree
## Ecology: meal-energy multipliers, speed upkeep, camouflage table, hawk risk, food slider mapping,
## plus the genotype label used by the inspector.

var _passed: int = 0
var _failed: int = 0
var _cfg: Node


func _init() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + label)


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _run() -> void:
	await get_root().ready
	_cfg = get_root().get_node("/root/GameConfig")
	_test_meal_multiplier()
	_test_speed_upkeep()
	_test_camouflage()
	_test_hawk_risk()
	_test_food_slider()
	_test_labels()
	_test_break_even()
	_test_lifespan()
	_test_space_cap()
	_test_satiety()
	_test_bugs()
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_meal_multiplier() -> void:
	var low: float = float(_cfg.meal_multiplier_by_metabolism["low"])
	var med: float = float(_cfg.meal_multiplier_by_metabolism["medium"])
	var high: float = float(_cfg.meal_multiplier_by_metabolism["high"])
	_check(low < med and med < high, "meal energy rises with metabolism")
	_check(_near(med, 1.0), "medium metabolism gets a normal meal")
	_check(_near(Ecology.meal_multiplier(_cfg, "low", false), low), "low metabolism multiplier")
	_check(_near(Ecology.meal_multiplier(_cfg, "high", false), high), "high metabolism multiplier")
	var eff: float = float(_cfg.cannibal_insect_efficiency)
	_check(eff < 1.0, "cannibals get less energy from tiny insects")
	_check(_near(Ecology.meal_multiplier(_cfg, "medium", true), eff), "cannibal x medium = efficiency")
	_check(_near(Ecology.meal_multiplier(_cfg, "high", true), high * eff), "cannibal x high stacks")
	_check(_near(Ecology.meal_multiplier(_cfg, "bogus", false), 1.0), "unknown metabolism falls back to 1")


func _test_speed_upkeep() -> void:
	_check(_near(Ecology.speed_upkeep(_cfg, "slow", 1.0), 0.0), "slow lizards pay no upkeep")
	var med: float = Ecology.speed_upkeep(_cfg, "medium", 1.0)
	var fast: float = Ecology.speed_upkeep(_cfg, "fast", 1.0)
	_check(med > 0.0 and fast > med, "upkeep grows with speed")
	_check(_near(Ecology.speed_upkeep(_cfg, "fast", 0.5), fast * 0.5), "upkeep scales with body size")
	_check(_near(Ecology.speed_upkeep(_cfg, "bogus", 1.0), 0.0), "unknown speed pays nothing")


func _test_camouflage() -> void:
	# 3 habitats x 3 colors: only the matching color is camouflaged
	var expected: Dictionary = {
		Ecology.Habitat.GRASS: "green",
		Ecology.Habitat.SAND: "brown",
		Ecology.Habitat.ROCK: "gray",
	}
	for habitat: int in expected.keys():
		for color: String in ["green", "brown", "gray"]:
			_check(Ecology.is_camouflaged(color, habitat) == (color == str(expected[habitat])),
					"camouflage %s on %s" % [color, Ecology.habitat_name(habitat)])
	_check(not Ecology.is_camouflaged("green", 99), "unknown habitat camouflages nothing")


func _test_hawk_risk() -> void:
	var saved_on: bool = bool(_cfg.hawks_on)
	_cfg.hawks_on = false
	_check(_near(Ecology.hawk_risk(_cfg, false), 0.0), "no risk with hawks off")
	_check(_near(Ecology.hawk_risk(_cfg, true), 0.0), "no risk with hawks off (camouflaged)")
	_cfg.hawks_on = true
	var saved_presence: float = float(_cfg.hawk_presence)
	_cfg.hawk_presence = 1.0
	var open: float = Ecology.hawk_risk(_cfg, false)
	var hidden: float = Ecology.hawk_risk(_cfg, true)
	_check(_near(open, float(_cfg.hawk_risk)), "exposed lizard faces the full hawk risk")
	_check(_near(hidden, open * float(_cfg.hawk_camouflage_factor)), "camouflage scales the risk")
	_check(hidden < open, "camouflaged lizards are safer")
	# Hawks arrive gradually: no risk at first, half way at half the ramp, full after it
	var ramp: float = float(_cfg.hawk_ramp_seconds)
	_check(ramp > 0.0, "hawks ramp in by default")
	_cfg.hawk_presence = 0.0
	_check(_near(Ecology.hawk_risk(_cfg, false), 0.0), "no hawk risk the moment hawks are switched on")
	var p: float = Ecology.hawk_presence_step(_cfg, 0.0, ramp * 0.5)
	_check(_near(p, 0.5), "presence is half way after half the ramp")
	_cfg.hawk_presence = p
	_check(_near(Ecology.hawk_risk(_cfg, false), open * 0.5), "half presence = half risk")
	_check(_near(Ecology.hawk_presence_step(_cfg, p, ramp), 1.0), "presence caps at 1")
	_cfg.hawks_on = false
	_check(_near(Ecology.hawk_presence_step(_cfg, 0.7, 1.0), 0.0), "hawks off resets presence")
	_cfg.hawk_presence = saved_presence
	_cfg.hawks_on = saved_on


func _test_food_slider() -> void:
	_check(_near(Ecology.food_interval_from_slider(_cfg, 0.0), float(_cfg.food_interval_scarce)), "slider 0 = scarce")
	_check(_near(Ecology.food_interval_from_slider(_cfg, 1.0), float(_cfg.food_interval_plenty)), "slider 1 = plenty")
	_check(_near(Ecology.food_interval_from_slider(_cfg, 5.0), float(_cfg.food_interval_plenty)), "slider clamps")
	var back: float = Ecology.slider_from_food_interval(_cfg, Ecology.food_interval_from_slider(_cfg, 0.4))
	_check(_near(back, 0.4), "slider mapping round-trips")
	_check(Ecology.food_word(0.35) == "normal", "default interval reads as normal")
	_check(Ecology.food_word(0.25) == "plenty" and Ecology.food_word(1.0) == "scarce", "ends read plenty and scarce")


func _test_break_even() -> void:
	# The metabolism trade-off only works if thrifty lizards need the fewest meals to break even
	var low: float = Ecology.break_even_intake(_cfg, "low")
	var med: float = Ecology.break_even_intake(_cfg, "medium")
	var high: float = Ecology.break_even_intake(_cfg, "high")
	_check(low > 0.0, "break-even intake is positive")
	_check(low < med and med < high, "break-even intake ordered low < medium < high (%.4f %.4f %.4f)" % [low, med, high])
	_check(_near(med, float(_cfg.energy_depletion_rates["medium"]) / float(_cfg.food_energy_value)), "medium break-even = drain / meal")


func _test_satiety() -> void:
	# An insect meal that would overflow max_energy is skipped by adults, never by juveniles
	var meal: float = float(_cfg.food_energy_value)
	var top: float = float(_cfg.max_energy)
	var was_on: bool = _cfg.satiety_enabled
	_cfg.satiety_enabled = true
	var ready: float = float(_cfg.reproduction_energy)
	_check(not Ecology.is_full(_cfg, "adult", top - meal, "medium", false), "adult with room for a whole meal eats")
	_check(not Ecology.is_full(_cfg, "adult", ready - 1.0, "medium", false), "adult below breeding readiness always eats")
	_check(Ecology.is_full(_cfg, "adult", maxf(ready, top - meal + 1.0), "medium", false), "ready adult that would overflow is full")
	_check(not Ecology.is_full(_cfg, "juvenile", top, "medium", false), "juveniles always eat")
	_cfg.satiety_enabled = false
	_check(not Ecology.is_full(_cfg, "adult", top, "medium", false), "satiety off: full adults still eat")
	_cfg.satiety_enabled = was_on


func _test_bugs() -> void:
	# Bugs are too big for eggs and juveniles; only adults eat them
	_check(Ecology.can_eat_bug("adult"), "adults can eat bugs")
	_check(not Ecology.can_eat_bug("juvenile"), "juveniles can't eat bugs")
	_check(not Ecology.can_eat_bug("egg"), "eggs can't eat bugs")
	var low: float = Ecology.bug_meal(_cfg, "low")
	var med: float = Ecology.bug_meal(_cfg, "medium")
	var high: float = Ecology.bug_meal(_cfg, "high")
	_check(low < med and med < high, "bug meal ordered low < medium < high")
	_check(_near(med, float(_cfg.bug_energy_value)), "medium bug meal = bug_energy_value (no cannibal penalty)")
	_check(float(_cfg.bug_energy_value) > float(_cfg.food_energy_value), "a beetle is worth more than an insect")


func _test_lifespan() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var lo: float = float(_cfg.lifespan_seconds) * (1.0 - float(_cfg.lifespan_spread))
	var hi: float = float(_cfg.lifespan_seconds) * (1.0 + float(_cfg.lifespan_spread))
	var in_range: bool = true
	var smallest: float = INF
	var largest: float = -INF
	for i: int in range(500):
		var life: float = Ecology.roll_lifespan(_cfg, rng)
		in_range = in_range and life >= lo - 0.0001 and life <= hi + 0.0001
		smallest = minf(smallest, life)
		largest = maxf(largest, life)
	_check(in_range, "lifespan stays within 0.8-1.2 of lifespan_seconds")
	_check(largest - smallest > 0.5 * (hi - lo), "lifespans vary between lizards")
	_check(Ecology.DEATH_OLD_AGE == "old_age", "old age death cause name")


func _test_space_cap() -> void:
	var saved_cap: int = int(_cfg.space_cap)
	_cfg.space_cap = 35
	_check(Ecology.can_lay(_cfg, 0), "can lay in an empty arena")
	_check(Ecology.can_lay(_cfg, 34), "can lay just below the cap")
	_check(not Ecology.can_lay(_cfg, 35), "cannot lay at the cap")
	_check(not Ecology.can_lay(_cfg, 80), "cannot lay above the cap")
	_cfg.space_cap = 0
	_check(Ecology.can_lay(_cfg, 500), "cap 0 means no cap")
	_cfg.space_cap = saved_cap


func _test_labels() -> void:
	var genotype: Dictionary = {
		"metabolism": ["m", "M"], "speed": ["S", "s"], "growth_rate": ["g", "g"],
		"color": ["Cy", "Cb"], "cannibal": ["k", "K"],
	}
	_check(EvoGenetics.genotype_label(genotype) == "Mm Ss gg CbCy Kk", "genotype label: " + EvoGenetics.genotype_label(genotype))
