extends Node2D
class_name Organism

signal organism_died(organism)
signal organism_reproduced(organism, offspring_genome)

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionBody/CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var state_machine: Node = $StateMachine
@onready var ui: Node2D = $UI
@onready var energy_timer: Timer = $EnergyTimer
@onready var growth_timer: Timer = $GrowthTimer
@onready var ai: Node = $AI
@onready var growth_progress_timer: Timer = $GrowthProgressTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var genome: Dictionary = {}
var energy: float = 100.0
var current_state: String = "egg"
var generation: int = 1
var growth_progress: float = 0.0  # 0.0 to 1.0 for gradual growth during juvenile phase

# Hardcoded values for now
var energy_depletion_rates = {
	"low": 1.0,
	"medium": 2.0,
	"high": 3.0
}

var growth_timers = {
	"slow": 10.0,
	"normal": 7.0,
	"fast": 4.0
}

var reproduction_energy = 80
var reproduction_cost = 20  # Energy cost to reproduce
var max_energy = 100
var mutation_chance = 0.1
var food_energy_value = 30

func _ready():
	print("Organism _ready() called at position: ", position)
	# Initialize genome if not set
	if genome.is_empty():
		genome = generate_random_genome()
	
	# Set initial scale for egg
	scale = Vector2(0.2, 0.2)
	
	# Set initial egg frame
	sprite.frame = 0
	
	# Initialize energy - eggs start with exactly the reproduction cost (20 energy)
	if current_state == "egg":
		energy = 20  # Eggs start with the energy their parent paid
	
	# Set up timers
	energy_timer.wait_time = 1.0
	energy_timer.timeout.connect(_on_energy_timer_timeout)
	energy_timer.start()
	
	growth_timer.wait_time = growth_timers[genome.growth_rate]
	growth_timer.timeout.connect(_on_growth_timer_timeout)
	growth_timer.start()
	
	# Growth progress timer no longer needed - juveniles grow by eating
	
	# Apply genome effects
	apply_genome_effects()
	
	# Set up detection area
	detection_area.body_entered.connect(_on_food_detected)
	print("Organism detection area set up, waiting for food...")

func generate_random_genome() -> Dictionary:
	var metabolism_options = ["low", "medium", "high"]
	var speed_options = ["slow", "medium", "fast"]
	var growth_options = ["slow", "normal", "fast"]
	var color_options = ["green", "brown", "gray"]
	
	return {
		"metabolism": metabolism_options[randi() % metabolism_options.size()],
		"speed": speed_options[randi() % speed_options.size()],
		"growth_rate": growth_options[randi() % growth_options.size()],
		"color": color_options[randi() % color_options.size()]
	}

func apply_genome_effects():
	# Apply color tint
	var color_tint = Color.WHITE
	match genome.color:
		"green":
			color_tint = Color(0.5, 1.0, 0.5)
		"brown":
			color_tint = Color(0.6, 0.4, 0.2)
		"gray":
			color_tint = Color(0.7, 0.7, 0.7)
	
	sprite.modulate = color_tint

func _on_energy_timer_timeout():
	# Eggs don't lose energy
	if current_state == "egg":
		return
	
	# Deplete energy based on metabolism and scale
	var base_depletion_rate = energy_depletion_rates[genome.metabolism]
	var scale_factor = scale.x  # Use X scale as the scaling factor
	var scaled_depletion_rate = base_depletion_rate * scale_factor
	
	energy -= scaled_depletion_rate
	$Label.text = str(energy)
	
	# Debug: Show scaling energy costs occasionally
	if randf() < 0.1:  # 10% chance each energy tick
		print("Energy depletion: base=", base_depletion_rate, " scale=", scale_factor, " total=", scaled_depletion_rate, " remaining=", energy)
	
	# Check for death
	if energy <= 0:
		die()
	
	# Check for reproduction
	if energy >= reproduction_energy and current_state == "adult":
		reproduce()

func _on_growth_timer_timeout():
	# Only eggs hatch automatically - juveniles grow by eating
	match current_state:
		"egg":
			current_state = "juvenile"
			growth_progress = 0.0  # Start at 0.2 scale
			# Stop egg animation and prepare for movement
			animation_player.stop()
			update_sprite()
			print("Egg hatched! Ready for movement animations")
		# Juveniles no longer grow automatically - they grow by eating

func _on_growth_progress_timeout():
	# This function is no longer used - juveniles grow by eating
	pass

func play_movement_animation(direction: Vector2):
	# Play movement animation with rotation based on direction
	if current_state == "egg":
		return  # Eggs don't move
	
	# Calculate rotation angle from direction vector
	var angle = direction.angle()
	
	# Add 90-degree offset to fix orientation (so they face forward, not sideways)
	angle += PI / 2
	
	# Set the sprite rotation to face the movement direction
	sprite.rotation = angle
	
	# Play the move animation if it's not already playing	
	if animation_player.current_animation != "move":
		animation_player.play("move")
#		print("Playing move animation, rotation: ", rad_to_deg(angle), " degrees")
		print("Playing move animation, rotation: ", sprite.rotation, " degrees")

func stop_movement_animation():
	# Stop movement animation
	if current_state != "egg":
		animation_player.stop()

func update_sprite():
	# Update sprite based on current state
	# Scale and color based on growth stage
	match current_state:
		"egg":
			sprite.modulate = Color.WHITE
			scale = Vector2(0.2, 0.2)  # Small eggs
			animation_player.play("egg")
		"juvenile":
			sprite.modulate = Color.YELLOW
			# Gradual scaling from 0.2 to 1.0 based on growth progress
			var juvenile_scale = 0.2 + (growth_progress * 0.8)  # 0.2 to 1.0
			scale = Vector2(juvenile_scale, juvenile_scale)
			# Set sprite to lizard frame (not egg frame) and prepare for movement
			sprite.frame = 1  # Use lizard frame instead of egg frame
			# Don't stop animation here - let movement system handle it
		"adult":
			apply_genome_effects()
			scale = Vector2(1.0, 1.0)  # Full size adults
			# Set sprite to lizard frame and prepare for movement
			sprite.frame = 1  # Use lizard frame
			# Don't stop animation here - let movement system handle it

func _on_food_detected(body: Node2D):
	if body.has_method("consume") and current_state != "egg":
		# Calculate distance to food
		var distance = position.distance_to(body.position)
		
		# Calculate detection probability based on distance
		# 100% at 0 distance, 95% at 10 pixels, -0.5% per pixel after that
		var detection_chance = max(0, 100 - (distance * 0.5))
		
		# Only attempt detection if we're not already seeking this food
		if ai.has_method("is_seeking_food") and ai.is_seeking_food and ai.detected_food == body:
			return  # Already seeking this food, don't re-detect
		
		# Roll for detection
		if randf() * 100 < detection_chance:
			print("Organism detected food at distance: ", distance, " (", detection_chance, "% chance)")
			
			# Tell AI to seek this food
			if ai.has_method("set_food_target"):
				ai.set_food_target(body)
			
			# Check if we're close enough to consume (when directly on top)
			if distance < 5:  # Much smaller consumption radius
				# Consume the food
				body.consume()
				
				# Handle energy and growth based on state
				if current_state == "juvenile":
					# Growth rate affects energy gain vs growth speed
					var energy_gain: float
					var scale_increase: float
					
					match genome.growth_rate:
						"slow":
							energy_gain = 20.0
							scale_increase = 0.1
						"normal":
							energy_gain = 15.0
							scale_increase = 0.2
						"fast":
							energy_gain = 10.0
							scale_increase = 0.3
						_:
							energy_gain = 15.0  # Default fallback
							scale_increase = 0.2
					
					# Apply energy gain and growth
					energy += energy_gain
					energy = min(energy, max_energy)
					
					# Grow based on growth rate trait
					growth_progress += scale_increase / 0.8  # Normalize to 0.8 range (0.2 to 1.0)
					growth_progress = min(growth_progress, 1.0)
					
					# Update scale
					var juvenile_scale = 0.2 + (growth_progress * 0.8)
					scale = Vector2(juvenile_scale, juvenile_scale)
					
					# Check if ready to become adult
					if growth_progress >= 1.0:
						current_state = "adult"
						update_sprite()
						print("Juvenile became adult!")
					
					print("Juvenile ate food! Energy: ", energy, " Growth progress: ", growth_progress, " Scale: ", juvenile_scale, " (Growth rate: ", genome.growth_rate, ")")
				else:
					# Adults get full energy
					energy += food_energy_value
					energy = min(energy, max_energy)
					print("Adult ate food! Energy: ", energy)
				
				# Visual feedback - briefly change color
				var original_color = sprite.modulate
				sprite.modulate = Color.YELLOW
				await get_tree().create_timer(0.2).timeout
				sprite.modulate = original_color
				
				# Clear food target after eating
				if ai.has_method("clear_food_target"):
					ai.clear_food_target()
		else:
			print("Organism missed food at distance: ", distance, " (", detection_chance, "% chance)")

func die():
	organism_died.emit(self)
	queue_free()

func reproduce():
	# Check if we have enough energy to reproduce
	if energy < reproduction_cost:
		return
	
	# Create offspring genome with potential mutations
	var offspring_genome = genome.duplicate()
	
	# Apply mutations to each trait
	var metabolism_options = ["low", "medium", "high"]
	var speed_options = ["slow", "medium", "fast"]
	var growth_options = ["slow", "normal", "fast"]
	var color_options = ["green", "brown", "gray"]
	
	if randf() < mutation_chance:
		offspring_genome["metabolism"] = metabolism_options[randi() % metabolism_options.size()]
	if randf() < mutation_chance:
		offspring_genome["speed"] = speed_options[randi() % speed_options.size()]
	if randf() < mutation_chance:
		offspring_genome["growth_rate"] = growth_options[randi() % growth_options.size()]
	if randf() < mutation_chance:
		offspring_genome["color"] = color_options[randi() % color_options.size()]
	
	# Emit reproduction signal
	organism_reproduced.emit(self, offspring_genome)
	
	# Deduct reproduction cost
	energy -= reproduction_cost
	print("Organism reproduced! Energy cost: ", reproduction_cost, ", Remaining energy: ", energy)
