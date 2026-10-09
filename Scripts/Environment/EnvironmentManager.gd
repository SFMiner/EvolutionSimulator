extends Node2D

@onready var food_spawn_timer: Timer = $FoodSpawnTimer
@onready var food_container: Node2D = $FoodContainer

var food_scene = preload("res://Scenes/Food.tscn")
var spawn_area_size: Vector2 = Vector2(800, 600)
var bug_container: Node2D = null
var bug_spawn_timer: Timer = null

func _ready():
	# Bugs: container and spawn timer are built in code
	bug_container = Node2D.new()
	bug_container.name = "BugContainer"
	add_child(bug_container)
	bug_spawn_timer = Timer.new()
	bug_spawn_timer.name = "BugSpawnTimer"
	bug_spawn_timer.wait_time = GameConfig.food_spawn_interval * GameConfig.bug_spawn_ratio
	bug_spawn_timer.timeout.connect(spawn_bug)
	add_child(bug_spawn_timer)
	bug_spawn_timer.start()

	# Set up food spawn timer
	food_spawn_timer.wait_time = GameConfig.food_spawn_interval
	food_spawn_timer.timeout.connect(_on_food_spawn_timer_timeout)
	food_spawn_timer.start()
	apply_habitat()
	
	# Spawn initial food to prevent starvation
	spawn_initial_food()
	if GameConfig.bugs_enabled:
		for i in range(GameConfig.bug_initial):
			spawn_bug()

## Habitat control: store it in GameConfig and recolor the arena.
func set_habitat(habitat: int) -> void:
	GameConfig.habitat = habitat
	apply_habitat()

func apply_habitat() -> void:
	$Background.color = Ecology.habitat_color(GameConfig.habitat)

## Food control: seconds between food spawns, applied immediately.
func set_food_interval(seconds: float) -> void:
	GameConfig.food_spawn_interval = seconds
	food_spawn_timer.wait_time = seconds
	bug_spawn_timer.wait_time = seconds * GameConfig.bug_spawn_ratio

## Adds one wandering bug at a random spot, unless bugs are off or the container is full.
func spawn_bug() -> void:
	if not GameConfig.bugs_enabled:
		return
	var live: int = 0
	for child: Node in bug_container.get_children():
		if not child.is_queued_for_deletion():
			live += 1
	if live >= GameConfig.bug_max:
		return
	var bug: Bug = Bug.new()
	bug_container.add_child(bug)
	bug.position = Vector2(
			randf_range(-spawn_area_size.x / 2.0, spawn_area_size.x / 2.0),
			randf_range(-spawn_area_size.y / 2.0, spawn_area_size.y / 2.0))

func spawn_initial_food():
	# Spawn a few food items at the start to prevent initial starvation
	for i in range(GameConfig.food_initial):
		spawn_food()
	if Organism.DEBUG:
		print("Spawned ", GameConfig.food_initial, " initial food items")

func _on_food_spawn_timer_timeout():
	spawn_food()

func spawn_food():
	if food_container.get_child_count() >= GameConfig.food_max:
		return
	var food = food_scene.instantiate()
	food_container.add_child(food)
	
	# Random position within spawn area
	var random_x = randf_range(-spawn_area_size.x/2, spawn_area_size.x/2)
	var random_y = randf_range(-spawn_area_size.y/2, spawn_area_size.y/2)
	food.position = Vector2(random_x, random_y)
