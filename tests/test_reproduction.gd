extends SceneTree
## Organism reproduction hooks: proximity mating, partner cost, self-fertilization, cloning.
## Organism is not named as a type here: its script uses the GameConfig autoload, which does not
## exist yet when this script compiles. Needs the GameConfig autoload (bound via get_node, autoloads are not identifiers here).

var _passed: int = 0
var _failed: int = 0
var _config: Node
var _events: Array = []


func _init() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + label)


func _run() -> void:
	await get_root().ready
	_config = get_root().get_node("/root/GameConfig")
	await _test_mating()
	await _test_out_of_range_then_self()
	await _test_asexual()
	await _test_energy_hawks_tags()
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _on_repro(org: Node, genotype: Dictionary, kind: String) -> void:
	_events.append({"org": org, "genotype": genotype, "kind": kind})


func _make(pos: Vector2, genotype: Dictionary, seed_value: int) -> Node:
	var scene: PackedScene = load("res://Scenes/Organism.tscn")
	var org: Node = scene.instantiate()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	org.rng = rng
	org.genotype = genotype
	org.position = pos
	get_root().add_child(org)
	org.current_state = "adult"
	org.energy = 90.0
	org.organism_reproduced.connect(_on_repro)
	# Timers would tick the energy and growth on their own; this test drives reproduce() directly
	org.energy_timer.stop()
	org.growth_timer.stop()
	return org


func _cleanup(orgs: Array) -> void:
	for o: Node in orgs:
		o.queue_free()
	_events.clear()
	await process_frame


func _test_mating() -> void:
	_config.reproduction_mode = 0  # SEXUAL
	_config.mutation_rate = 0.0
	var a: Node = _make(Vector2(0, 0), {"speed": ["S", "S"]}, 1)
	var b: Node = _make(Vector2(40, 0), {"speed": ["s", "s"]}, 2)
	_check(a.find_mate() == b, "nearest ready adult found within radius")
	a.reproduce()
	_check(_events.size() == 1 and _events[0]["kind"] == "mating", "mating event emitted")
	if _events.size() == 1:
		var kid: Dictionary = _events[0]["genotype"]
		_check(kid["speed"] == ["S", "s"], "SS x ss gives Ss")
	_check(is_equal_approx(a.energy, 70.0), "initiator pays egg cost 20")
	_check(is_equal_approx(b.energy, 85.0), "partner pays 5")
	await _cleanup([a, b])


func _test_out_of_range_then_self() -> void:
	_config.reproduction_mode = 0
	_config.mutation_rate = 0.0
	var a: Node = _make(Vector2(0, 0), {"speed": ["S", "s"]}, 3)
	var far: Node = _make(Vector2(500, 0), {"speed": ["s", "s"]}, 4)
	var young: Node = _make(Vector2(20, 0), {"speed": ["s", "s"]}, 5)
	young.current_state = "juvenile"
	_check(a.find_mate() == null, "no partner out of range or not adult")
	var waits: int = int(_config.self_fertilize_after)
	for i: int in range(waits - 1):
		a.reproduce()
	_check(_events.is_empty() and is_equal_approx(a.energy, 90.0), "keeps energy and retries while waiting")
	a.reproduce()
	_check(_events.size() == 1 and _events[0]["kind"] == "self", "self-fertilizes after the wait")
	_check(is_equal_approx(a.energy, 70.0), "self-fertilization pays the egg cost")
	await _cleanup([a, far, young])


func _test_asexual() -> void:
	_config.reproduction_mode = 1  # ASEXUAL
	_config.mutation_rate = 0.0
	var a: Node = _make(Vector2(0, 0), {"speed": ["S", "s"]}, 6)
	var b: Node = _make(Vector2(10, 0), {"speed": ["s", "s"]}, 7)
	a.reproduce()
	_check(_events.size() == 1 and _events[0]["kind"] == "clone", "clone event emitted")
	if _events.size() == 1:
		_check(_events[0]["genotype"]["speed"] == ["S", "s"], "clone copies genotype at mutation 0")
	_check(is_equal_approx(b.energy, 90.0), "no partner cost when cloning")
	_config.reproduction_mode = 0
	await _cleanup([a, b])


func _test_energy_hawks_tags() -> void:
	_config.reproduction_mode = 1
	# Energy drain: low metabolism + slow = 1/s; high metabolism + fast = 3 + fast upkeep
	var calm: Node = _make(Vector2(0, 0), {"metabolism": ["m", "m"], "speed": ["s", "s"]}, 8)
	var racer: Node = _make(Vector2(300, 0), {"metabolism": ["M", "M"], "speed": ["S", "S"]}, 9)
	calm.scale = Vector2.ONE  # _make leaves the egg scale; drain is scaled by body size
	racer.scale = Vector2.ONE
	calm.energy = 50.0
	racer.energy = 50.0
	calm._on_energy_timer_timeout()
	racer._on_energy_timer_timeout()
	_check(is_equal_approx(calm.energy, 49.0), "low metabolism + slow drains 1 per second")
	var fast_upkeep: float = float(_config.speed_upkeep_by_speed["fast"])
	_check(is_equal_approx(racer.energy, 50.0 - 3.0 - fast_upkeep), "high metabolism + fast drains 3 plus the speed upkeep")
	# Labels: hidden by default, whole-number energy, metabolism tag works (scene node was misspelled)
	_check(not calm.get_node("Label").visible and not calm.gene_tags.visible, "labels are hidden by default")
	racer.energy = 36.9999999701977
	calm.set_labels_visible(true)
	racer.set_labels_visible(true)
	_check(racer.get_node("Label").text == "37", "energy label shows a whole number: " + racer.get_node("Label").text)
	_check(racer.gene_tags.get_node("metabolism").text == "H", "metabolism tag shows H for high")
	_check(calm.gene_tags.get_node("metabolism").text == "L", "metabolism tag shows L for low")
	_check(racer.gene_tags.get_node("color").text != "", "color tag is filled in")
	_check(racer.gene_tags.get_node("speed").text == "H" and racer.gene_tags.get_node("growth_rate").text != "", "speed and growth tags are filled in")
	# Hawks: a certain hit kills the lizard and records the cause
	var saved_risk: float = float(_config.hawk_risk)
	var died: Array = []
	racer.organism_died.connect(func(o: Node) -> void: died.append(o))
	_config.hawks_on = true
	_config.hawk_risk = 1.0
	racer.energy = 90.0
	racer._on_energy_timer_timeout()
	_check(died.size() == 1 and racer.death_cause == "hawk", "a hawk strike kills with cause hawk")
	_config.hawks_on = false
	_config.hawk_risk = saved_risk
	_config.reproduction_mode = 0
	await _cleanup([calm, racer])
