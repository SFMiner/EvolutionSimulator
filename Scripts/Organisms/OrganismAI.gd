extends Node

@onready var organism: Organism = get_parent()
@onready var sprite: Sprite2D = organism.get_node("Sprite2D")

var movement_speeds = {
	"slow": 20,
	"medium": 40,
	"fast": 60
}

var current_direction: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var is_seeking_food: bool = false
var detected_food: Node2D = null

func _ready():
	# Start with random direction
	current_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	change_direction()

func _physics_process(delta):
	if organism.current_state == "egg":
		return
	
	# Get current speed based on genome
	var speed = movement_speeds[organism.genome.speed]
	
	# Move towards target or in current direction
	var direction: Vector2
	if is_seeking_food:
		# Move directly toward food target
		direction = (target_position - organism.position).normalized()
	else:
		# Move toward random target
		var target = organism.position + current_direction * 100
		direction = (target - organism.position).normalized()
	
	# Move organism
	organism.position += direction * speed * delta
	
	# Play movement animation
	organism.play_movement_animation(direction)
	
	# Debug: Print direction and speed occasionally
	if randf() < 0.01:  # 1% chance each frame
		var seeking_text = " (seeking food)" if is_seeking_food else ""
		print("AI moving: direction=", direction, " speed=", speed, " state=", organism.current_state, seeking_text)
	
	# Check if we've reached the target
	if organism.position.distance_to(target_position) < 10:
		if is_seeking_food:
			# We've reached the food target, try to consume it
			if detected_food != null and detected_food.has_method("consume"):
				var distance_to_food = organism.position.distance_to(detected_food.position)
				if distance_to_food < 5:  # Very close to food
					print("Organism is very close to food, attempting consumption...")
					# Call the organism's food detection method to handle consumption
					organism._on_food_detected(detected_food)
		else:
			# We've reached a random target, change direction
			change_direction()
	
	# Keep organism within bounds
	keep_in_bounds()

func change_direction():
	# Stop current movement animation
	organism.stop_movement_animation()
	
	# Random new direction
	current_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# Set new target position
	var random_distance = randf_range(50, 150)
	target_position = organism.position + current_direction * random_distance

func keep_in_bounds():
	var bounds = Vector2(400, 300)
	var pos = organism.position
	
	if abs(pos.x) > bounds.x:
		organism.position.x = sign(pos.x) * bounds.x
		change_direction()
	
	if abs(pos.y) > bounds.y:
		organism.position.y = sign(pos.y) * bounds.y
		change_direction()

func set_food_target(food: Node2D):
	detected_food = food
	target_position = food.position
	is_seeking_food = true
	
	# Calculate direction directly toward food
	var direction_to_food = (food.position - organism.position).normalized()
	current_direction = direction_to_food
	
	print("AI now seeking food at position: ", food.position, " direction: ", direction_to_food)

func clear_food_target():
	detected_food = null
	is_seeking_food = false
	organism.stop_movement_animation()
	change_direction()
