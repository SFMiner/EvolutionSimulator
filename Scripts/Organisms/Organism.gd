extends Node2D
class_name Organism

## Set true to get the per-tick / per-frame debug prints (they also slow experiments about 6x).
const DEBUG: bool = false

signal organism_died(organism)
## kind is "mating", "self" or "clone"; offspring_genotype is engine-shape {locus: [a, b]}.
signal organism_reproduced(organism, offspring_genotype, kind)

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $Sprite2D/CollisionBody/CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var state_machine: Node = $StateMachine
@onready var ui: Node2D = $UI
@onready var energy_timer: Timer = $EnergyTimer
@onready var growth_timer: Timer = $GrowthTimer
@onready var ai: Node = $AI
@onready var growth_progress_timer: Timer = $GrowthProgressTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var gene_tags: HBoxContainer = $gene_tags

# Cooldown for cannibal prey seeking after reproduction
var prey_seek_cooldown_active: bool = false
var _prey_seek_timer: Timer

## Diploid genes (source of truth, inherited). `genome` below is the expressed phenotype.
var genotype: Dictionary = {}
var genome: Dictionary = {}
## Set by SimulationManager (the one seedable RNG); fallback is made lazily.
var rng: RandomNumberGenerator = null
var _mate_wait: float = 0.0  # seconds spent ready with no partner in range
var energy: float = 100.0
var current_state: String = "egg"
## Why this lizard died (Ecology.DEATH_*); set in die().
var death_cause: String = ""
var generation: int = 1
## Eggs this lizard would have laid (only counted when GameConfig.eggs_count_only is on).
var eggs_laid: int = 0
## Seconds lived since hatching, and the lifespan rolled at hatch (0 until then; eggs don't age).
var age: float = 0.0
var lifespan: float = 0.0
var growth_progress: float = 0.0  # 0.0 to 1.0 for gradual growth during juvenile phase

# Tables and ecology numbers come from GameConfig (single source of truth)
var energy_depletion_rates = GameConfig.energy_depletion_rates

var growth_timers = GameConfig.growth_timers

var reproduction_energy = GameConfig.reproduction_energy
var reproduction_cost: float = GameConfig.egg_cost  # Energy cost to reproduce (egg)
var max_energy = GameConfig.max_energy
var food_energy_value = GameConfig.food_energy_value

func _ready():
	if DEBUG:
		print("Organism _ready() called at position: ", position)
	add_to_group("organisms")
	# Initialize genotype if not set, then derive the expressed genome (phenotype) from it
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if genotype.is_empty():
		genotype = EvoGenetics.random_founder(rng)
	genome = EvoGenetics.to_genome(genotype)
	
	# Smaller bodies: sprite (and its collision body child) plus label offsets only. Root `scale` is game logic.
	sprite.scale *= GameConfig.body_size
	$Label.position *= GameConfig.body_size
	gene_tags.position *= GameConfig.body_size

	# Set initial scale for egg
	scale = Vector2(0.2, 0.2)
	
	# Set initial egg frame
	sprite.frame = 0
	
	# Initialize prey seek cooldown timer
	_prey_seek_timer = Timer.new()
	_prey_seek_timer.one_shot = true
	add_child(_prey_seek_timer)
	_prey_seek_timer.timeout.connect(_on_prey_seek_cooldown_timeout)
	
	# Initialize energy - eggs start with exactly the energy their parent paid (GameConfig.egg_cost)
	if current_state == "egg":
		energy = GameConfig.egg_cost
	
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

	# Update visible gene tags
	update_gene_tags()
	
	# Set up detection area
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	if DEBUG:
		print("Organism detection area set up, waiting for food...")
	set_labels_visible(GameConfig.show_labels)

func _find_organism_ancestor(node: Node) -> Organism:
	var n: Node = node
	var depth := 0
	while n != null and depth < 6:
		if n is Organism:
			return n as Organism
		n = n.get_parent()
		depth += 1
	return null

func _resolve_food_from_body(body: Node2D) -> Node2D:
	# Returns the Food node if present, else null
	if body != null and body.has_method("consume"):
		return body
	var p = body.get_parent() if body != null else null
	if p != null and p.has_method("consume"):
		return p
	return null

func _on_detection_area_body_entered(body: Node2D):
	# If we're already seeking something valid, don't flip targets
	if ai.has_method("is_seeking_food") and ai.is_seeking_food and ai.detected_food != null:
		return
	
	# Prefer prey if cannibal and not in cooldown
	if GameConfig.cannibalism_enabled and genome.get("cannibal", false) and !prey_seek_cooldown_active and current_state != "egg":
		var other :=_find_organism_ancestor(body)
		if other != null and other != self and other.scale.x <= scale.x * 0.5:
			if ai.has_method("set_food_target"):
				ai.set_food_target(other)
			return
	
	# Otherwise target food (detection-only)
	var food_node = _resolve_food_from_body(body)
	if food_node != null and ai.has_method("set_food_target"):
		ai.set_food_target(food_node)
		return

# --- Utility: approximate collision radius for contact checks ---
func _radius_from_shape(shape: Shape2D, scale_factor: float) -> float:
	if shape == null:
		return 8.0 * scale_factor
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius * scale_factor
	elif shape is RectangleShape2D:
		var ext = (shape as RectangleShape2D).extents
		return max(ext.x, ext.y) * scale_factor
	elif shape is CapsuleShape2D:
		var cap := shape as CapsuleShape2D
		return max(cap.radius, cap.height * 0.5) * scale_factor
	else:
		return 8.0 * scale_factor

func _find_collision_shape_recursive(node: Node) -> CollisionShape2D:
	if node == null:
		return null
	if node is CollisionShape2D:
		return node as CollisionShape2D
	for child in node.get_children():
		var found = _find_collision_shape_recursive(child)
		if found != null:
			return found
	return null

func _get_first_collision_shape(node: Node) -> CollisionShape2D:
	if node == null:
		return null
	# Common direct paths
	if node.has_node("CollisionShape2D"):
		return node.get_node("CollisionShape2D") as CollisionShape2D
	if node.has_node("CollisionBody/CollisionShape2D"):
		return node.get_node("CollisionBody/CollisionShape2D") as CollisionShape2D
	if node.has_node("Sprite2D/CollisionBody/CollisionShape2D"):
		return node.get_node("Sprite2D/CollisionBody/CollisionShape2D") as CollisionShape2D
	# Fallback: recursive search through descendants
	return _find_collision_shape_recursive(node)

func _approx_collision_radius(node: Node2D) -> float:
	if node == null:
		return 8.0
	var cs = _get_first_collision_shape(node)
	var scale_factor = 1.0
	if node is Node2D:
		scale_factor = (node as Node2D).scale.x
	var the_shape: Shape2D = null
	if cs != null:
		the_shape = cs.shape
	return _radius_from_shape(the_shape, scale_factor)

func _shapes_overlap(a: Node2D, b: Node2D) -> bool:
	var a_cs = _get_first_collision_shape(a)
	var b_cs = _get_first_collision_shape(b)
	if a_cs != null and b_cs != null and a_cs.shape != null and b_cs.shape != null:
		return a_cs.shape.collide(a_cs.get_global_transform(), b_cs.shape, b_cs.get_global_transform())
	# Fallback to radii overlap
	var d = a.position.distance_to(b.position)
	return d <= (_approx_collision_radius(a) + _approx_collision_radius(b))

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

func _to_level_letter(value: String) -> String:
	match value:
		"low", "slow":
			return "L"
		"medium", "normal":
			return "M"
		"high", "fast":
			return "H"
		_:
			return ""

func _color_abbrev(value: String) -> String:
	match value:
		"green":
			return "Gn"
		"brown":
			return "B"
		"gray":
			return "Gy"
		_:
			return ""

func update_gene_tags():
	if gene_tags == null:
		return

	# Resolve labels by exact child names inside `gene_tags`
	var metabolism_label: Label = gene_tags.get_node_or_null("metabolism") as Label
	var speed_label: Label = gene_tags.get_node_or_null("speed") as Label
	var growth_label: Label = gene_tags.get_node_or_null("growth_rate") as Label
	var cannibal_label: Label = gene_tags.get_node_or_null("cannibal") as Label
	var color_label: Label = gene_tags.get_node_or_null("color") as Label

	# Map values to letters per spec
	var metabolism_text = _to_level_letter(str(genome.get("metabolism", "medium")))
	var speed_text = _to_level_letter(str(genome.get("speed", "medium")))
	var growth_text = _to_level_letter(str(genome.get("growth_rate", "normal")))
	var cannibal_text = "H" if bool(genome.get("cannibal", false)) else ""

	if metabolism_label != null:
		metabolism_label.text = metabolism_text
	if speed_label != null:
		speed_label.text = speed_text
	if growth_label != null:
		growth_label.text = growth_text
	if cannibal_label != null:
		cannibal_label.text = cannibal_text
	# Color shown as Gn/B/Gy
	if color_label != null:
		color_label.text = _color_abbrev(str(genome.get("color", "green")))

## Show or hide the energy number and gene tags (the "Show labels" checkbox).
func set_labels_visible(on: bool) -> void:
	$Label.visible = on
	gene_tags.visible = on
	if on:
		_update_energy_label()
		update_gene_tags()

func _update_energy_label() -> void:
	if $Label.visible:
		$Label.text = str(int(round(energy)))

func _on_energy_timer_timeout():
	# Eggs don't lose energy
	if current_state == "egg":
		return
	
	# Deplete energy based on metabolism and scale
	var base_depletion_rate = energy_depletion_rates[genome.metabolism]
	var scale_factor = scale.x  # Use X scale as the scaling factor
	var scaled_depletion_rate = base_depletion_rate * scale_factor
	# Fast lizards also pay an upkeep for moving (Ecology.speed_upkeep)
	scaled_depletion_rate += Ecology.speed_upkeep(GameConfig, str(genome.speed), scale_factor)

	energy -= scaled_depletion_rate
	_update_energy_label()

	# Hawks (environment control): a camouflaged lizard is caught less often
	if GameConfig.hawks_on and current_state != "egg":
		var camouflaged: bool = Ecology.is_camouflaged(str(genome.color), GameConfig.habitat)
		if rng.randf() < Ecology.hawk_risk(GameConfig, camouflaged):
			die(Ecology.DEATH_HAWK)
			return
	
	# Debug: Show scaling energy costs occasionally
	if DEBUG and randf() < 0.1:  # 10% chance each energy tick
		print("Energy depletion: base=", base_depletion_rate, " scale=", scale_factor, " total=", scaled_depletion_rate, " remaining=", energy)
	
	# Old age (lifespan is rolled at hatch; the tick is one second)
	if lifespan <= 0.0:
		lifespan = Ecology.roll_lifespan(GameConfig, rng)
	age += energy_timer.wait_time
	if age >= lifespan:
		die(Ecology.DEATH_OLD_AGE)
		return

	# Check for death
	if energy <= 0:
		die()
	
	# Check for reproduction
	if energy >= reproduction_energy and current_state == "adult":
		reproduce()
	else:
		_mate_wait = 0.0

func _on_growth_timer_timeout():
	# Only eggs hatch automatically - juveniles grow by eating
	match current_state:
		"egg":
			current_state = "juvenile"
			growth_progress = 0.0  # Start at 0.2 scale
			age = 0.0
			lifespan = Ecology.roll_lifespan(GameConfig, rng)
			# Stop egg animation and prepare for movement
			animation_player.stop()
			update_sprite()
			if DEBUG:
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
		if DEBUG:
			print("Playing move animation, rotation: ", sprite.rotation, " rad")

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

## True if this lizard is too full to eat an insect (Ecology.is_full); full lizards ignore insects.
func is_full() -> bool:
	return Ecology.is_full(GameConfig, current_state, float(energy), str(genome.metabolism), bool(genome.get("cannibal", false)))

func _on_food_detected(body: Node2D):
	# Beetles (Bug): energy-rich big prey for adults only; checked before the insect branch (Bug has consume() too)
	if body is Bug:
		if not Ecology.can_eat_bug(current_state):
			return
		var bug: Bug = body as Bug
		if bug.is_queued_for_deletion():
			return
		if not (ai.is_seeking_food and ai.detected_food == bug):
			ai.set_food_target(bug)
		if not _shapes_overlap(self, bug):
			return
		bug.consume()
		energy = min(energy + Ecology.bug_meal(GameConfig, str(genome.metabolism)), max_energy)
		GameConfig.diag["bug_meals"] = int(GameConfig.diag["bug_meals"]) + 1
		ai.clear_food_target()
		var bug_original_color: Color = sprite.modulate
		sprite.modulate = Color.YELLOW
		var bug_flash: Tween = create_tween()
		bug_flash.tween_interval(0.2)
		bug_flash.tween_callback(func() -> void: sprite.modulate = bug_original_color)
		return

	if body.has_method("consume") and current_state != "egg" and not is_full():
		# Calculate true/approx distance (kept for logging/compat)
		var my_cs = _get_first_collision_shape(self)
		var food_cs = _get_first_collision_shape(body)
		var distance := 0.0
		if my_cs != null and food_cs != null and my_cs.shape != null and food_cs.shape != null:
			var overlapping: bool = my_cs.shape.collide(my_cs.get_global_transform(), food_cs.shape, food_cs.get_global_transform())
			if overlapping:
				distance = 0.0
			else:
				var center_distance = position.distance_to(body.position)
				var my_r = _approx_collision_radius(self)
				var food_r = _approx_collision_radius(body)
				var contact_epsilon = 3.0
				distance = max(0.0, center_distance - (my_r + food_r) - contact_epsilon)
		else:
			var center_distance = position.distance_to(body.position)
			var my_r = _approx_collision_radius(self)
			var food_r = _approx_collision_radius(body)
			var contact_epsilon = 3.0
			distance = max(0.0, center_distance - (my_r + food_r) - contact_epsilon)
		
		# Always set target on detection (first time)
		var already_targeting := false
		if ai.has_method("is_seeking_food"):
			already_targeting = ai.is_seeking_food and ai.detected_food == body
		if !already_targeting and ai.has_method("set_food_target"):
			ai.set_food_target(body)
		
		# Only consume when CollisionShapes actually overlap
		if !_shapes_overlap(self, body):
			return
		
		# Consume
		body.consume()
		GameConfig.diag["insect_meals"] = int(GameConfig.diag["insect_meals"]) + 1
		# Energy/growth handling remains unchanged below
		
		# Metabolism and cannibalism change how much an insect meal is worth (Ecology rules)
		var meal_mult: float = Ecology.meal_multiplier(GameConfig, str(genome.metabolism), bool(genome.get("cannibal", false)))

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
			energy += energy_gain * meal_mult
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
				if DEBUG:
					print("Juvenile became adult!")

			if DEBUG:
				print("Juvenile ate food! Energy: ", energy, " Growth progress: ", growth_progress, " Scale: ", juvenile_scale, " (Growth rate: ", genome.growth_rate, ")")
		else:
			# Adults get a full meal, adjusted by metabolism and cannibalism (see Ecology)
			energy += food_energy_value * meal_mult
			energy = min(energy, max_energy)
			if DEBUG:
				print("Adult ate food! Energy: ", energy)
		
		# Clear food target after eating
		if ai.has_method("clear_food_target"):
			ai.clear_food_target()

		# Visual feedback - briefly change color. A tween owned by this node dies with it; an awaited
		# SceneTreeTimer resumed on freed organisms and segfaulted Godot at quit.
		var original_color = sprite.modulate
		sprite.modulate = Color.YELLOW
		var flash: Tween = create_tween()
		flash.tween_interval(0.2)
		flash.tween_callback(func() -> void: sprite.modulate = original_color)
		# Stop here to avoid using a freed body reference
		return

	# If the body was freed (e.g., food consumed), skip further checks
	if !is_instance_valid(body):
		return

	# Cannibalism: detect and eat smaller organisms if trait enabled
	if GameConfig.cannibalism_enabled and genome.get("cannibal", false) and current_state != "egg":
		var other: Organism = null
		if body is Organism:
			other = body as Organism
		else:
			var p = body.get_parent() if body != null else null
			if p != null and p is Organism:
				other = p as Organism
		
		if other != null and other != self:
			# Only target organisms at 50% or less of self scale
			if other.scale.x <= scale.x * 0.5:
				# Eat only on CollisionShape overlap
				if !_shapes_overlap(self, other):
					return
				var gained = other.energy + 10.0 * other.scale.x
				energy = min(energy + gained, max_energy)
				var kill_key: String = "kill_" + str(other.current_state)
				if GameConfig.diag.has(kill_key):
					GameConfig.diag[kill_key] = int(GameConfig.diag[kill_key]) + 1
				other.die(Ecology.DEATH_EATEN)
				if DEBUG:
					print("Cannibal consumed lizard! +", gained, " energy -> ", energy)
				if ai.has_method("clear_food_target"):
					ai.clear_food_target()
				return

## `cause` is one of Ecology.DEATH_* and is read by SimulationManager for the death stats.
func die(cause: String = Ecology.DEATH_STARVED) -> void:
	# Guard: a cannibal's kill and a starvation tick can both call die() in one frame, which
	# emitted organism_died twice and made SimulationManager.population_count undercount.
	if is_queued_for_deletion():
		return
	death_cause = cause
	# Queue the free first: listeners that count the container's children (the population
	# label) ran while this lizard was still a child and saw one too many.
	queue_free()
	organism_died.emit(self)

## Eggs + juveniles + adults alive right now (the space cap counts these).
func live_count() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("organisms"):
		if not node.is_queued_for_deletion():
			count += 1
	return count

func is_ready_to_mate() -> bool:
	return current_state == "adult" and energy >= reproduction_energy and !is_queued_for_deletion()

## Nearest other ready adult within GameConfig.mate_radius, or null.
func find_mate() -> Organism:
	var best: Organism = null
	var best_d: float = GameConfig.mate_radius
	for node: Node in get_tree().get_nodes_in_group("organisms"):
		var other: Organism = node as Organism
		if other == null or other == self or !other.is_ready_to_mate():
			continue
		var d: float = position.distance_to(other.position)
		if d <= best_d:
			best_d = d
			best = other
	return best

## Called on the partner after a mating: small energy cost plus the same cooldown as the initiator.
func pay_mating_cost() -> void:
	energy -= GameConfig.partner_cost
	_start_reproduction_cooldown()
	_mate_wait = 0.0

func _start_reproduction_cooldown() -> void:
	# Start prey seek cooldown (only meaningful for cannibals)
	if genome.get("cannibal", false):
		prey_seek_cooldown_active = true
		_prey_seek_timer.start(2.0)

func reproduce() -> void:
	# Check if we have enough energy to reproduce
	if energy < reproduction_cost:
		return
	# Prototype hook: count the egg and pay for it, but spawn nothing
	if GameConfig.eggs_count_only:
		eggs_laid += 1
		energy -= reproduction_cost
		_start_reproduction_cooldown()
		return
	# Space cap: no room for new nests (no mating, selfing or cloning); keep the energy and wait
	if not Ecology.can_lay(GameConfig, live_count()):
		return

	var lib: GenomeLibrary = EvoGenetics.get_library()
	var rate: float = GameConfig.mutation_rate
	var offspring_genotype: Dictionary = {}
	var kind: String = "clone"
	
	if GameConfig.reproduction_mode == GameConfig.ReproductionMode.ASEXUAL:
		offspring_genotype = Genome.clone_with_mutation(lib, genotype, rng, rate)
	else:
		var mate: Organism = find_mate()
		if mate != null:
			offspring_genotype = Genome.cross(lib, genotype, mate.genotype, rng, rate)
			mate.pay_mating_cost()
			kind = "mating"
		else:
			# No partner in range: keep the energy and retry on the next check, unless we have
			# waited long enough, then self-fertilize so sparse populations survive.
			_mate_wait += energy_timer.wait_time
			if _mate_wait < GameConfig.self_fertilize_after:
				return
			offspring_genotype = Genome.cross(lib, genotype, genotype, rng, rate)
			kind = "self"
	_mate_wait = 0.0
	
	# Emit reproduction signal
	organism_reproduced.emit(self, offspring_genotype, kind)
	
	# Deduct reproduction cost
	energy -= reproduction_cost
	if DEBUG:
		print("Organism reproduced (", kind, ")! Energy cost: ", reproduction_cost, ", Remaining energy: ", energy)
	
	_start_reproduction_cooldown()

# Cooldown support
func _on_prey_seek_cooldown_timeout():
	prey_seek_cooldown_active = false

func can_seek_prey() -> bool:
	return !prey_seek_cooldown_active
