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
	var eff: float = float(_cfg.cannibal_plant_efficiency)
	_check(eff < 1.0, "cannibals digest plants worse")
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
	var open: float = Ecology.hawk_risk(_cfg, false)
	var hidden: float = Ecology.hawk_risk(_cfg, true)
	_check(_near(open, float(_cfg.hawk_risk)), "exposed lizard faces the full hawk risk")
	_check(_near(hidden, open * float(_cfg.hawk_camouflage_factor)), "camouflage scales the risk")
	_check(hidden < open, "camouflaged lizards are safer")
	_cfg.hawks_on = saved_on


func _test_food_slider() -> void:
	_check(_near(Ecology.food_interval_from_slider(_cfg, 0.0), float(_cfg.food_interval_scarce)), "slider 0 = scarce")
	_check(_near(Ecology.food_interval_from_slider(_cfg, 1.0), float(_cfg.food_interval_plenty)), "slider 1 = plenty")
	_check(_near(Ecology.food_interval_from_slider(_cfg, 5.0), float(_cfg.food_interval_plenty)), "slider clamps")
	var back: float = Ecology.slider_from_food_interval(_cfg, Ecology.food_interval_from_slider(_cfg, 0.4))
	_check(_near(back, 0.4), "slider mapping round-trips")
	_check(Ecology.food_word(0.35) == "normal", "default interval reads as normal")
	_check(Ecology.food_word(0.25) == "plenty" and Ecology.food_word(1.0) == "scarce", "ends read plenty and scarce")


func _test_labels() -> void:
	var genotype: Dictionary = {
		"metabolism": ["m", "M"], "speed": ["S", "s"], "growth_rate": ["g", "g"],
		"color": ["Cy", "Cb"], "cannibal": ["k", "K"],
	}
	_check(EvoGenetics.genotype_label(genotype) == "Mm Ss gg CbCy Kk", "genotype label: " + EvoGenetics.genotype_label(genotype))
