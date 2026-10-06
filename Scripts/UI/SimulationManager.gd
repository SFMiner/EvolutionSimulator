extends Node2D

var environment: Node2D
@onready var spawn_button: Button = $UI/ControlPanel/VBoxContainer/SpawnButton
@onready var pause_button: Button = $UI/ControlPanel/VBoxContainer/PauseButton
@onready var population_label: Label = $UI/ControlPanel/VBoxContainer/PopulationLabel
@onready var generation_label: Label = $UI/ControlPanel/VBoxContainer/GenerationLabel

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

func _ready():
	# Connect button signals
	spawn_button.pressed.connect(_on_spawn_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	
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


func _initialize_simulation():
	# Find the environment node
	environment = get_node("Environment")
	
	# Find the organism container
	organism_container = environment.get_node("OrganismContainer")
	
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
	# Spawn 5 organisms to start
	for i in range(5):
		spawn_organism()

func spawn_organism():
	if organism_container == null:
		print("Error: organism_container is null. Trying to find it again...")
		organism_container = environment.get_node("OrganismContainer")
		if organism_container == null:
			print("Error: Still cannot find OrganismContainer")
			return
	
	var organism = organism_scene.instantiate()
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
	print("Organism died. Population: ", population_count)
	update_ui()

func _on_organism_reproduced(organism: Organism, offspring_genome: Dictionary):
	# Create offspring
	var offspring = organism_scene.instantiate()
	offspring.genome = offspring_genome
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
	
	print("Organism reproduced. Population: ", population_count, " Generation: ", current_generation)
	update_ui()

func update_ui():
	# Verify actual organism count in scene tree
	var actual_count = 0
	if organism_container != null:
		actual_count = organism_container.get_child_count()
	
	# Update labels
	population_label.text = "Population: " + str(population_count) + " (Actual: " + str(actual_count) + ")"
	generation_label.text = "Generation: " + str(current_generation)
	
	# Update the population graph
	if population_graph != null:
		population_graph.update_population(population_count)
	
	# Debug: Print discrepancy if any
	if population_count != actual_count:
		print("WARNING: Population count mismatch! Counted: ", population_count, " Actual: ", actual_count)

func update_population_data():
	# Add current population and time to history
	population_history.append(float(population_count))
	time_points.append(simulation_time)
	
	# Debug: Print population data occasionally
	if randf() < 0.1:  # 10% chance each update
		print("Data update - Population: ", population_count, " History size: ", population_history.size(), " Time: ", simulation_time)
		if population_history.size() > 1:
			print("  Population change: ", population_history[-2], " -> ", population_history[-1])
	
	# Keep only last 100 data points to prevent memory issues
	if population_history.size() > 100:
		population_history.pop_front()
		time_points.pop_front()
	
	# Update the population graph
	if population_graph != null:
		population_graph.update_population(population_count)

# Drawing is now handled by the PopulationGraph node
