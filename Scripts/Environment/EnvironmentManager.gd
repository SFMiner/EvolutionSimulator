extends Node2D

@onready var food_spawn_timer: Timer = $FoodSpawnTimer
@onready var food_container: Node2D = $FoodContainer

var food_scene = preload("res://Scenes/Food.tscn")
var spawn_area_size: Vector2 = Vector2(800, 600)

func _ready():
	# Set up food spawn timer
	food_spawn_timer.wait_time = 2.0  # Hardcoded for now
	food_spawn_timer.timeout.connect(_on_food_spawn_timer_timeout)
	food_spawn_timer.start()
	
	# Spawn initial food to prevent starvation
	spawn_initial_food()

func spawn_initial_food():
	# Spawn 5 food items at the start to prevent initial starvation
	for i in range(5):
		spawn_food()
	print("Spawned 5 initial food items")

func _on_food_spawn_timer_timeout():
	spawn_food()

func spawn_food():
	var food = food_scene.instantiate()
	food_container.add_child(food)
	
	# Random position within spawn area
	var random_x = randf_range(-spawn_area_size.x/2, spawn_area_size.x/2)
	var random_y = randf_range(-spawn_area_size.y/2, spawn_area_size.y/2)
	food.position = Vector2(random_x, random_y)
