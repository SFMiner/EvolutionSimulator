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

# A small berry with a leaf, drawn in code (no image asset)
func _draw() -> void:
	draw_circle(Vector2(0, 1), 6.0, Color(0.75, 0.1, 0.15))
	draw_circle(Vector2(-2, -1), 2.0, Color(1.0, 0.55, 0.55))
	var leaf: PackedVector2Array = PackedVector2Array([
		Vector2(0, -5), Vector2(3, -9), Vector2(8, -8), Vector2(5, -4)])
	draw_colored_polygon(leaf, Color(0.2, 0.7, 0.2))
