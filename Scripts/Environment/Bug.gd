class_name Bug
extends Node2D
## A beetle: slow, energy-rich prey that only adult lizards can eat (Ecology.can_eat_bug).
## Built entirely in code: a wandering Node2D with an Area2D the lizards' bodies overlap.

signal bug_consumed(bug: Bug)

const BOUNDS: Vector2 = Vector2(400.0, 300.0)
const BODY_COLOR: Color = Color(0.32, 0.18, 0.08)
const HEAD_COLOR: Color = Color(0.18, 0.09, 0.04)
const LEG_COLOR: Color = Color(0.12, 0.06, 0.03)

## Optional shared RNG (the spawner passes the simulation's); a private one is made if absent.
var rng: RandomNumberGenerator = null
var _direction: Vector2 = Vector2.RIGHT
var _turn_left: float = 0.0
var _consumed: bool = false


func _ready() -> void:
	add_to_group("bugs")
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var area: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = GameConfig.bug_radius * GameConfig.body_size
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	_pick_direction()


func _physics_process(delta: float) -> void:
	_turn_left -= delta
	if _turn_left <= 0.0:
		_pick_direction()
	position += _direction * GameConfig.bug_speed * delta
	# Turn around at the arena edge
	if absf(position.x) > BOUNDS.x:
		position.x = signf(position.x) * BOUNDS.x
		_direction.x = -signf(position.x) * absf(_direction.x)
		rotation = _direction.angle()
	if absf(position.y) > BOUNDS.y:
		position.y = signf(position.y) * BOUNDS.y
		_direction.y = -signf(position.y) * absf(_direction.y)
		rotation = _direction.angle()


func _pick_direction() -> void:
	_direction = Vector2.from_angle(rng.randf_range(0.0, TAU))
	_turn_left = rng.randf_range(1.0, 3.0)
	rotation = _direction.angle()


func _on_body_entered(body: Node2D) -> void:
	# The body is the lizard's CharacterBody2D; its parent chain leads to the Organism
	var organism: Node = body.get_parent()
	if organism != null and not organism.has_method("_on_food_detected"):
		organism = organism.get_parent()
	if organism != null and organism.has_method("_on_food_detected"):
		organism._on_food_detected(self)


func consume() -> void:
	if _consumed:
		return
	_consumed = true
	bug_consumed.emit(self)
	queue_free()


# A beetle seen from above, facing +x (rotation turns it toward its movement). About 14 px long at body_size 0.5.
func _draw() -> void:
	var k: float = GameConfig.body_size * 2.0
	var body: PackedVector2Array = PackedVector2Array()
	for i: int in range(20):
		var angle: float = TAU * float(i) / 20.0
		body.append(Vector2(cos(angle) * 7.0 * k, sin(angle) * 4.5 * k))
	draw_colored_polygon(body, BODY_COLOR)
	var head: PackedVector2Array = PackedVector2Array()
	for i: int in range(12):
		var angle: float = TAU * float(i) / 12.0
		head.append(Vector2(7.0 * k + cos(angle) * 2.6 * k, sin(angle) * 2.6 * k))
	draw_colored_polygon(head, HEAD_COLOR)
	draw_line(Vector2(-6.5, 0.0) * k, Vector2(6.5, 0.0) * k, HEAD_COLOR, maxf(1.0, k * 0.8))
	for leg_x: float in [-3.5, 0.5, 4.0]:
		draw_line(Vector2(leg_x, 3.5) * k, Vector2(leg_x - 1.0, 7.0) * k, LEG_COLOR, 1.0)
		draw_line(Vector2(leg_x, -3.5) * k, Vector2(leg_x - 1.0, -7.0) * k, LEG_COLOR, 1.0)
