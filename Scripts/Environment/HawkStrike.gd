extends Node2D
## Short visible cue where a hawk caught a lizard: a dark shadow and an X that fade out.
## The tween belongs to this node, so it follows pause and time scale and dies with the node.

const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const X_COLOR: Color = Color(0.1, 0.0, 0.0, 0.95)


func _ready() -> void:
	z_index = 5
	var fade: Tween = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 1.2).from(1.0)
	fade.tween_callback(queue_free)


func _draw() -> void:
	var shadow: PackedVector2Array = PackedVector2Array()
	for i: int in range(24):
		var angle: float = TAU * float(i) / 24.0
		shadow.append(Vector2(cos(angle) * 26.0, sin(angle) * 14.0))
	draw_colored_polygon(shadow, SHADOW_COLOR)
	draw_line(Vector2(-10, -10), Vector2(10, 10), X_COLOR, 4.0)
	draw_line(Vector2(-10, 10), Vector2(10, -10), X_COLOR, 4.0)
