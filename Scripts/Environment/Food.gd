extends Node2D

signal food_consumed(food)

## Set true for the per-food debug prints (they also slow experiments a lot).
const DEBUG: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	if DEBUG:
		print("Food _ready() called at position: ", position)
	# Set up collision detection using the existing CollisionShape2D
	var area = Area2D.new()
	# Insects are stationary, so each gets one random facing (cosmetic only; the collision circle is round)
	rotation = randf() * TAU
	# Give this insect its own scaled shape (the scene's shared resource must not be mutated). The node's own
	# CollisionShape2D is what Organism._shapes_overlap reads, and the Area2D gets a duplicate of it.
	var circle: CircleShape2D = (collision_shape.shape as CircleShape2D).duplicate() as CircleShape2D
	circle.radius *= GameConfig.body_size
	collision_shape.shape = circle
	area.add_child(collision_shape.duplicate())
	add_child(area)

	# Connect to body entered signal
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	# The body is the CharacterBody2D, but we need the parent Organism node
	var organism = body.get_parent()

	if organism.has_method("_on_food_detected"):
		# Notify the organism, let it handle consumption
		organism._on_food_detected(self)

func consume():
	if DEBUG:
		print("Food being consumed and destroyed!")
	food_consumed.emit(self)
	queue_free()

# A tiny ant seen from above (head, thorax, abdomen, 6 legs, 2 antennae), drawn in code (no image asset).
# Faces +x; _ready gives the node a random rotation. Dark red-orange so it shows on grass, sand and rock
# and stays distinct from the brown beetle (Bug).
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(GameConfig.body_size, GameConfig.body_size))
	var body: Color = Color(0.6, 0.15, 0.05)
	# Legs: three pairs from the thorax
	for leg_x: float in [3.0, 0.5, -2.0]:
		draw_line(Vector2(1.0, 0.0), Vector2(leg_x, -5.5), body, 1.0)
		draw_line(Vector2(1.0, 0.0), Vector2(leg_x, 5.5), body, 1.0)
	# Antennae from the head
	draw_line(Vector2(7.0, -0.8), Vector2(10.0, -3.5), body, 1.0)
	draw_line(Vector2(7.0, 0.8), Vector2(10.0, 3.5), body, 1.0)
	# Body segments, head to abdomen
	draw_circle(Vector2(6.0, 0.0), 2.0, body)
	draw_circle(Vector2(1.5, 0.0), 2.2, body)
	draw_circle(Vector2(-4.0, 0.0), 3.2, body)
