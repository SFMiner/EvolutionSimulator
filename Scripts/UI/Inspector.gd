extends PanelContainer
## Click a lizard to see its genes, traits, energy and state in a small box next to it.
## Click empty ground to close it. Lives in the (always-processing) UI layer so it works while paused.

const PICK_RADIUS_MIN: float = 16.0
const PICK_RADIUS_PER_SCALE: float = 26.0
const BOX_OFFSET: Vector2 = Vector2(28.0, -50.0)

## Set by SimulationManager.
var organism_container: Node2D = null

var _label: Label
var _target: Organism = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * click.position
	select(pick_at(world))


## Nearest living lizard under a world position, or null.
func pick_at(world: Vector2) -> Organism:
	if organism_container == null:
		return null
	var best: Organism = null
	var best_d: float = INF
	for node: Node in organism_container.get_children():
		var org: Organism = node as Organism
		if org == null or org.is_queued_for_deletion():
			continue
		var reach: float = maxf(PICK_RADIUS_MIN, PICK_RADIUS_PER_SCALE * org.scale.x)
		var d: float = org.position.distance_to(world)
		if d <= reach and d < best_d:
			best_d = d
			best = org
	return best


func select(org: Organism) -> void:
	_target = org
	if _target == null:
		visible = false
		return
	visible = true
	refresh()


func selected() -> Organism:
	return _target


func _process(_delta: float) -> void:
	if _target == null:
		return
	if not is_instance_valid(_target) or _target.is_queued_for_deletion():
		select(null)
		return
	refresh()


func refresh() -> void:
	var genome: Dictionary = _target.genome
	var camo: bool = Ecology.is_camouflaged(str(genome.get("color", "")), GameConfig.habitat)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Genes: " + EvoGenetics.genotype_label(_target.genotype))
	lines.append("Metabolism: %s" % str(genome.get("metabolism", "")))
	lines.append("Speed: %s" % str(genome.get("speed", "")))
	lines.append("Growth: %s" % str(genome.get("growth_rate", "")))
	lines.append("Color: %s%s" % [str(genome.get("color", "")), " (camouflaged here)" if camo else ""])
	lines.append("Cannibal: %s" % ("yes" if bool(genome.get("cannibal", false)) else "no"))
	lines.append("Energy: %d   State: %s" % [int(round(_target.energy)), _target.current_state])
	if _target.lifespan > 0.0:
		lines.append("Age: %d s of %d" % [int(_target.age), int(round(_target.lifespan))])
	else:
		lines.append("Age: not hatched yet")
	_label.text = "\n".join(lines)
	# Follow the lizard on screen, kept inside the window
	var on_screen: Vector2 = _target.get_global_transform_with_canvas().origin
	# Zoomed in, the lizard can scroll out of the arena view: hide the box (keep the selection) until it returns
	visible = ZoomCamera.ARENA_SCREEN.has_point(on_screen)
	var screen: Vector2 = on_screen + BOX_OFFSET
	var view: Vector2 = get_viewport().get_visible_rect().size
	var box: Vector2 = get_combined_minimum_size()
	size = box
	position = Vector2(clampf(screen.x, 4.0, view.x - box.x - 4.0), clampf(screen.y, 4.0, view.y - box.y - 4.0))
