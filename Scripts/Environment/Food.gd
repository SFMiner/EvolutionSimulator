extends Node2D

signal food_consumed(food)

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	print("Food _ready() called at position: ", position)
	# Set up collision detection using the existing CollisionShape2D
	var area = Area2D.new()
	area.add_child(collision_shape.duplicate())
	add_child(area)
	
	# Connect to body entered signal
	area.body_entered.connect(_on_body_entered)
	print("Food Area2D set up, waiting for collisions...")

func _on_body_entered(body: Node2D):
	print("Food detected body: ", body.name, " (", body.get_class(), ")")
	
	# The body is the CharacterBody2D, but we need the parent Organism node
	var organism = body.get_parent()
	print("Organism parent: ", organism.name, " (", organism.get_class(), ")")
	
	if organism.has_method("_on_food_detected"):
		print("Organism has _on_food_detected method, calling it...")
		# Notify the organism, let it handle consumption
		organism._on_food_detected(self)
	else:
		print("Organism does not have _on_food_detected method")

func consume():
	print("Food being consumed and destroyed!")
	food_consumed.emit(self)
	queue_free()
