extends Node2D

var environment: Node2D
@onready var spawn_button: Button = $UI/ControlPanel/VBoxContainer/ButtonRow/SpawnButton
@onready var pause_button: Button = $UI/ControlPanel/VBoxContainer/ButtonRow/PauseButton
@onready var population_label: Label = $UI/ControlPanel/VBoxContainer/PopulationLabel
@onready var generation_label: Label = $UI/ControlPanel/VBoxContainer/GenerationLabel
@onready var mode_option: OptionButton = $UI/ControlPanel/VBoxContainer/ModeOption
@onready var mutation_label: Label = $UI/ControlPanel/VBoxContainer/MutationLabel
@onready var mutation_slider: HSlider = $UI/ControlPanel/VBoxContainer/MutationSlider
@onready var allele_graph: Control = $UI/AlleleGraph
@onready var food_label: Label = $UI/ControlPanel/VBoxContainer/FoodLabel
@onready var food_slider: HSlider = $UI/ControlPanel/VBoxContainer/FoodSlider
@onready var habitat_option: OptionButton = $UI/ControlPanel/VBoxContainer/HabitatRow/HabitatOption
@onready var hawks_check: CheckButton = $UI/ControlPanel/VBoxContainer/HawksCheck
@onready var labels_check: CheckButton = $UI/ControlPanel/VBoxContainer/LabelsCheck
@onready var inspector: PanelContainer = $UI/Inspector

var organism_container: Node2D
var population_graph: Control

var organism_scene = preload("res://Scenes/Organism.tscn")
var current_generation: int = 1
var population_count: int = 0
var is_paused: bool = false

# Data tracking for graphs
var population_history: Array[float] = []
var time_points: Array[float] = []
var simulation_time: float = 0.0
var data_update_timer: float = 0.0
var data_update_interval: float = 1.0  # Update data every second

# Genetics v2: the one RNG for all genetics calls (seedable via EVO_SEED)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Births by kind, for the stats panel
var births: Dictionary = {"mating": 0, "self": 0, "clone": 0}
var extinct_at: float = -1.0
# Deaths by cause (Ecology.DEATH_*), shown under the births in the stats panel
var deaths: Dictionary = {"starved": 0, "eaten": 0, "hawk": 0}

const HAWK_STRIKE: GDScript = preload("res://Scripts/Environment/HawkStrike.gd")

# Screenshot gate (EVO_SHOT=<png>, optional EVO_MODE, EVO_SECONDS, EVO_SEED)
var _shot_path: String = ""
var _shot_seconds: float = 90.0
var _shot_pending: bool = false
var _inspect_in_shot: bool = false  # EVO_INSPECT=1: select an adult before the screenshot

func _ready():
	_read_env_settings()
	
	# Connect button signals
	spawn_button.pressed.connect(_on_spawn_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	_setup_genetics_controls()
	_setup_environment_controls()

	# Defer the initialization to ensure all nodes are ready
	call_deferred("_initialize_simulation")

func _process(delta):
	if !is_paused:
		simulation_time += delta
		data_update_timer += delta
		
		# Update data for graphs every second
		if data_update_timer >= data_update_interval:
			data_update_timer = 0.0
			update_population_data()
		
		if _shot_path != "" and !_shot_pending and simulation_time >= _shot_seconds:
			_shot_pending = true
			_save_screenshot_and_quit()


func _initialize_simulation():
	# Find the environment node
	environment = get_node("Environment")
	
	# Find the organism container
	organism_container = environment.get_node("OrganismContainer")
	inspector.organism_container = organism_container

	# Find the population graph
	population_graph = get_node("UI/GraphNode")
	
	if organism_container == null:
		print("Error: Could not find OrganismContainer")
		return
	
	if population_graph == null:
		print("Error: Could not find PopulationGraph")
		return
	
	# Spawn initial organisms
	spawn_initial_organisms()
	
	# Update UI
	update_ui()

func spawn_initial_organisms():
	# Spawn the founder batch (GameConfig.founder_count)
	for i in range(GameConfig.founder_count):
		spawn_organism()

func spawn_organism():
	if organism_container == null:
		print("Error: organism_container is null. Trying to find it again...")
		organism_container = environment.get_node("OrganismContainer")
		if organism_container == null:
			print("Error: Still cannot find OrganismContainer")
			return
	
	var organism = organism_scene.instantiate()
	organism.rng = rng
	organism.genotype = EvoGenetics.random_founder(rng)
	organism_container.add_child(organism)
	
	# Random position
	var random_x = randf_range(-300, 300)
	var random_y = randf_range(-200, 200)
	organism.position = Vector2(random_x, random_y)
	
	# Connect signals
	organism.organism_died.connect(_on_organism_died)
	organism.organism_reproduced.connect(_on_organism_reproduced)
	
	# Update population count
	population_count += 1
	update_ui()

func _on_spawn_button_pressed():
	spawn_organism()

func _on_pause_button_pressed():
	is_paused = !is_paused
	get_tree().paused = is_paused
	
	if is_paused:
		pause_button.text = "Resume"
	else:
		pause_button.text = "Pause"

func _on_organism_died(organism: Organism):
	population_count -= 1
	var cause: String = organism.death_cause
	deaths[cause] = int(deaths.get(cause, 0)) + 1
	if cause == Ecology.DEATH_HAWK:
		_spawn_hawk_cue(organism.position)
	if population_count <= 0 and extinct_at < 0.0:
		extinct_at = simulation_time
		print("EXTINCTION at t=", snappedf(simulation_time, 0.1), "s")
	update_ui()

func _spawn_hawk_cue(where: Vector2) -> void:
	var cue: Node2D = HAWK_STRIKE.new()
	environment.add_child(cue)
	cue.position = where

func _on_organism_reproduced(organism: Organism, offspring_genotype: Dictionary, kind: String):
	# Create offspring; `genome` (phenotype) is derived from the genotype in Organism._ready
	births[kind] = int(births.get(kind, 0)) + 1
	var offspring = organism_scene.instantiate()
	offspring.rng = rng
	offspring.genotype = offspring_genotype
	offspring.generation = organism.generation + 1
	offspring.position = organism.position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	
	# Set offspring energy to the reproduction cost (what parent paid)
	offspring.energy = organism.reproduction_cost
	
	organism_container.add_child(offspring)
	
	# Connect signals
	offspring.organism_died.connect(_on_organism_died)
	offspring.organism_reproduced.connect(_on_organism_reproduced)
	
	# Update population and generation
	population_count += 1
	if offspring.generation > current_generation:
		current_generation = offspring.generation
	
	update_ui()

func update_ui():
	# Verify actual organism count in scene tree
	var actual_count: int = 0
	if organism_container != null:
		for child: Node in organism_container.get_children():
			if not child.is_queued_for_deletion():
				actual_count += 1

	# Update labels (one number: the counter is exact now that die() queues the free first)
	population_label.text = "Population: " + str(population_count)
	generation_label.text = "Generation: " + str(current_generation)
	
	# Update the population graph
	if population_graph != null:
		population_graph.update_population(population_count)
	if allele_graph != null:
		allele_graph.set_births(births)
		allele_graph.set_deaths(deaths)

	# Debug: Print discrepancy if any
	if Organism.DEBUG and population_count != actual_count:
		print("WARNING: Population count mismatch! Counted: ", population_count, " Actual: ", actual_count)

func update_population_data():
	# Add current population and time to history
	population_history.append(float(population_count))
	time_points.append(simulation_time)
	
	# Keep only last 100 data points to prevent memory issues
	if population_history.size() > 100:
		population_history.pop_front()
		time_points.pop_front()
	
	# Update the population graph
	if population_graph != null:
		population_graph.update_population(population_count)
	
	# Allele frequencies, sampled on the same interval as the population graph
	if allele_graph != null:
		allele_graph.sample(get_live_genotypes())
		allele_graph.set_births(births)
		allele_graph.set_deaths(deaths)

# Drawing is now handled by the PopulationGraph node


# === GENETICS V2 ===

## Genotypes of every living organism (eggs included).
func get_live_genotypes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if organism_container == null:
		return out
	for child: Node in organism_container.get_children():
		var org: Organism = child as Organism
		if org != null and !org.is_queued_for_deletion():
			out.append(org.genotype)
	return out

func _read_env_settings() -> void:
	var seed_text: String = OS.get_environment("EVO_SEED")
	if seed_text.is_valid_int():
		rng.seed = seed_text.to_int()
		seed(seed_text.to_int())  # movement/AI randomness too, for repeatable runs
	else:
		rng.randomize()
	var mode_text: String = OS.get_environment("EVO_MODE").to_lower()
	if mode_text == "asexual":
		GameConfig.reproduction_mode = GameConfig.ReproductionMode.ASEXUAL
	elif mode_text == "sexual":
		GameConfig.reproduction_mode = GameConfig.ReproductionMode.SEXUAL
	# Environment controls from env vars (screenshot gate and quick experiments)
	match OS.get_environment("EVO_HABITAT").to_lower():
		"grass":
			GameConfig.habitat = Ecology.Habitat.GRASS
		"sand":
			GameConfig.habitat = Ecology.Habitat.SAND
		"rock":
			GameConfig.habitat = Ecology.Habitat.ROCK
	if OS.get_environment("EVO_HAWKS") != "":
		GameConfig.hawks_on = OS.get_environment("EVO_HAWKS") == "1"
	if OS.get_environment("EVO_LABELS") != "":
		GameConfig.show_labels = OS.get_environment("EVO_LABELS") == "1"
	if OS.get_environment("EVO_FOOD_INTERVAL").is_valid_float():
		GameConfig.food_spawn_interval = OS.get_environment("EVO_FOOD_INTERVAL").to_float()
	_inspect_in_shot = OS.get_environment("EVO_INSPECT") == "1"
	_shot_path = OS.get_environment("EVO_SHOT")
	if _shot_path != "":
		var secs: String = OS.get_environment("EVO_SECONDS")
		if secs.is_valid_float():
			_shot_seconds = secs.to_float()
		# Fast-forward through the engine clock so timers, AI and graphs all keep pace
		Engine.time_scale = 4.0

func _setup_genetics_controls() -> void:
	mode_option.clear()
	mode_option.add_item("Sexual (mating)", GameConfig.ReproductionMode.SEXUAL)
	mode_option.add_item("Asexual (clones)", GameConfig.ReproductionMode.ASEXUAL)
	mode_option.select(mode_option.get_item_index(GameConfig.reproduction_mode))
	mode_option.item_selected.connect(_on_mode_selected)
	mutation_slider.min_value = 0.0
	mutation_slider.max_value = 0.2
	mutation_slider.step = 0.005
	mutation_slider.value = GameConfig.mutation_rate
	mutation_slider.value_changed.connect(_on_mutation_changed)
	_update_mutation_label()

## Environment controls: food, ground, hawks, labels. They write GameConfig and apply at once.
func _setup_environment_controls() -> void:
	food_slider.min_value = 0.0
	food_slider.max_value = 1.0
	food_slider.step = 0.01
	food_slider.set_value_no_signal(Ecology.slider_from_food_interval(GameConfig, GameConfig.food_spawn_interval))
	food_slider.value_changed.connect(_on_food_changed)
	_update_food_label()
	habitat_option.clear()
	for habitat: int in Ecology.Habitat.values():
		habitat_option.add_item(Ecology.habitat_name(habitat), habitat)
	habitat_option.select(habitat_option.get_item_index(GameConfig.habitat))
	habitat_option.item_selected.connect(_on_habitat_selected)
	hawks_check.set_pressed_no_signal(GameConfig.hawks_on)
	hawks_check.toggled.connect(_on_hawks_toggled)
	labels_check.set_pressed_no_signal(GameConfig.show_labels)
	labels_check.toggled.connect(_on_labels_toggled)
	# The Environment child is ready before this node reads EVO_* settings, so re-apply them now
	var env_node: Node = get_node("Environment")
	env_node.apply_habitat()
	env_node.set_food_interval(GameConfig.food_spawn_interval)

func _on_food_changed(value: float) -> void:
	var interval: float = Ecology.food_interval_from_slider(GameConfig, value)
	if environment != null:
		environment.set_food_interval(interval)
	else:
		GameConfig.food_spawn_interval = interval
	_update_food_label()

func _update_food_label() -> void:
	food_label.text = "Food: " + Ecology.food_word(GameConfig.food_spawn_interval)

func _on_habitat_selected(index: int) -> void:
	var habitat: int = habitat_option.get_item_id(index)
	if environment != null:
		environment.set_habitat(habitat)
	else:
		GameConfig.habitat = habitat

func _on_hawks_toggled(on: bool) -> void:
	GameConfig.hawks_on = on

func _on_labels_toggled(on: bool) -> void:
	GameConfig.show_labels = on
	for node: Node in get_tree().get_nodes_in_group("organisms"):
		var org: Organism = node as Organism
		if org != null:
			org.set_labels_visible(on)

func _on_mode_selected(index: int) -> void:
	# Applies to future births only
	GameConfig.reproduction_mode = mode_option.get_item_id(index) as GameConfig.ReproductionMode

func _on_mutation_changed(value: float) -> void:
	GameConfig.mutation_rate = value
	_update_mutation_label()

func _update_mutation_label() -> void:
	mutation_label.text = "Mutation: %d%%" % int(round(GameConfig.mutation_rate * 100.0))

func _save_screenshot_and_quit() -> void:
	if _inspect_in_shot:
		for child: Node in organism_container.get_children():
			var org: Organism = child as Organism
			if org != null and org.current_state == "adult" and not org.is_queued_for_deletion():
				inspector.select(org)
				break
		await get_tree().process_frame
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(_shot_path)
	print("EVO_SHOT saved ", _shot_path, " err=", err, " t=", snappedf(simulation_time, 0.1),
			" pop=", population_count, " births=", births)
	get_tree().quit(0 if err == OK else 1)
