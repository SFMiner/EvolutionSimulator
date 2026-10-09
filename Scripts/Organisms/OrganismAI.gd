extends Node

@onready var organism: Organism = get_parent()
@onready var sprite: Sprite2D = organism.get_node("Sprite2D")

var movement_speeds = GameConfig.movement_speeds

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
	
	# Validate current target
	if is_seeking_food and (detected_food == null or !is_instance_valid(detected_food)):
		clear_food_target()
	# A full lizard drops a plant target (prey targets are kept)
	if is_seeking_food and !(detected_food is Organism) and organism.is_full():
		clear_food_target()
	
	# Move towards target or in current direction
	var direction: Vector2
	if is_seeking_food:
		# Refresh target position to follow moving target
		if detected_food != null and is_instance_valid(detected_food):
			target_position = detected_food.position
		# Move directly toward target
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
	if Organism.DEBUG and randf() < 0.01:  # 1% chance each frame
		var seeking_text = " (seeking food)" if is_seeking_food else ""
		print("AI moving: direction=", direction, " speed=", speed, " state=", organism.current_state, seeking_text)
	
	# Check if we've reached the target
	if organism.position.distance_to(target_position) < 10:
		if is_seeking_food:
			# Close to target (food or prey). Reuse organism's handler for either case
			if detected_food != null:
				var distance_to_target = organism.position.distance_to(detected_food.position)
				if distance_to_target < 5:
					organism._on_food_detected(detected_food)
		else:
			# We've reached a random target, change direction
			change_direction()
	
	# Keep organism within bounds
	keep_in_bounds()
	
	# Proactive detection (set target only, without replacing an existing target)
	if organism.detection_area != null and !is_seeking_food:
		var chosen: Node2D = null
		# Prefer prey if cannibal
		if GameConfig.cannibalism_enabled and organism.genome.get("cannibal", false):
			var bodies = organism.detection_area.get_overlapping_bodies()
			var best_d = INF
			for b in bodies:
				var parent = b.get_parent()
				if parent != null and parent is Organism and parent != organism:
					var prey: Organism = parent as Organism
					if prey.scale.x <= organism.scale.x * 0.5:
						var d = organism.position.distance_to(prey.position)
						if d < best_d:
							best_d = d
							chosen = prey
		# If no prey selected, look for food areas
		if chosen == null and !organism.is_full():
			var areas = organism.detection_area.get_overlapping_areas()
			for a in areas:
				var candidate = a.get_parent()
				if candidate != null and candidate != organism and candidate.has_method("consume"):
					chosen = candidate
					break
		if chosen != null:
			set_food_target(chosen)

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
	
	if Organism.DEBUG:
		print("AI now seeking food at position: ", food.position, " direction: ", direction_to_food)

func clear_food_target():
	detected_food = null
	is_seeking_food = false
	organism.stop_movement_animation()
	change_direction()
