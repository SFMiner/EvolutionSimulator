# Godot 4.5 Changes & API Differences

This document tracks changes, deprecations, and new syntax in Godot 4.5 that differ from older versions.

## Text Rendering & Drawing

### ❌ **Removed/Changed in 4.5**
- `get_font("")` - No longer available for direct drawing
- `draw_string(font, position, text, alignment)` - Requires a font parameter

### ✅ **Alternatives in 4.5**
- Use `Label` nodes for text rendering instead of `draw_string()`
- For custom drawing, consider using `RichTextLabel` or `TextEdit` nodes
- Use `CanvasItem.draw_string()` only when you have a valid font resource

### **Example Migration**
```gdscript
# Old way (not available in 4.5)
draw_string(get_font(""), Vector2(100, 100), "Hello World")

# New way - Use Label nodes
var label = Label.new()
label.text = "Hello World"
label.position = Vector2(100, 100)
add_child(label)

# Or for custom drawing with font
var font = ThemeDB.fallback_font
draw_string(font, Vector2(100, 100), "Hello World")
```

## Array Methods

### ❌ **Removed/Changed in 4.5**
- `pick_random()` - No longer available

### ✅ **Alternatives in 4.5**
```gdscript
# Old way (not available in 4.5)
var random_element = array.pick_random()

# New way
var random_element = array[randi() % array.size()]
# or
var random_element = array[randi_range(0, array.size() - 1)]
```

## Signal Syntax

### ✅ **Current 4.5 Syntax**
```gdscript
# Signal declaration
signal organism_died(organism)

# Signal emission
organism_died.emit(self)

# Signal connection
organism.organism_died.connect(_on_organism_died)
```

## Node Access

### ✅ **Current 4.5 Syntax**
```gdscript
# @onready for child nodes
@onready var sprite: Sprite2D = $Sprite2D

# Manual node finding
var node = get_node("Path/To/Node")
var node = $Path/To/Node  # Shorthand
```

## Timer & Process

### ✅ **Current 4.5 Syntax**
```gdscript
# Timer setup
@onready var timer: Timer = $Timer
timer.wait_time = 1.0
timer.timeout.connect(_on_timer_timeout)
timer.start()

# Process function
func _process(delta: float):
    # Called every frame
    pass

# Physics process
func _physics_process(delta: float):
    # Called every physics frame
    pass
```

## Drawing Functions

### ✅ **Available in 4.5**
```gdscript
# Basic shapes
draw_rect(rect, color)
draw_circle(center, radius, color)
draw_line(start, end, color, width)

# Custom drawing
func _draw():
    # Drawing code here
    queue_redraw()  # Trigger redraw
```

## Resource Loading

### ✅ **Current 4.5 Syntax**
```gdscript
# Preload scenes
var scene = preload("res://Scenes/Organism.tscn")

# Load resources
var texture = load("res://Assets/texture.png")

# Instantiate scenes
var instance = scene.instantiate()
```

## Autoloads (Singletons)

### ✅ **Current 4.5 Setup**
```gdscript
# In project.godot
[autoload]
GameConfig="*res://Scripts/Systems/GameConfig.gd"

# In scripts
# Access directly by name
var config_value = GameConfig.some_value
```

## Known Issues & Workarounds

### **Font Rendering in Custom Drawing**
- **Problem**: `get_font("")` not available
- **Problem**: `ThemeDB.fallback_base_font` not available in 4.5
- **Workaround**: Use `Label` nodes or get font from theme
- **Alternative**: Use `ThemeDB.fallback_font` for basic text (only fallback available)

### **Random Array Selection**
- **Problem**: `pick_random()` removed
- **Workaround**: Use `array[randi() % array.size()]`
- **Alternative**: Use `randi_range(0, array.size() - 1)`

### **Text Drawing in _draw()**
- **Problem**: `draw_string()` requires font parameter
- **Workaround**: Use UI nodes instead of custom drawing
- **Alternative**: Create custom font resources

### **GDScript Ternary Operator**
- **Problem**: C-style ternary `a ? b : c` is not supported.
- **Error examples**: "Unexpected '?' in source"; "Expected end of statement after variable declaration".
- **Correct form**:
  ```gdscript
  var result = value_if_true if condition else value_if_false
  # Example replacement
  # var r = cs != null ? cs.shape : null  # INVALID
  var r = cs.shape if cs != null else null
  ```

## Best Practices for 4.5

1. **Use UI nodes for text** instead of custom drawing
2. **Prefer built-in methods** over deprecated ones
3. **Use @onready** for child node references
4. **Handle font requirements** explicitly when drawing text
5. **Use modern signal syntax** with `.connect()` and `.emit()`

## Testing & Validation

When implementing new features:
1. Test with Godot 4.5 specifically
2. Check console for deprecation warnings
3. Verify API calls exist in current version
4. Use alternative approaches when methods are removed

## Resources

- [Godot 4.5 Documentation](https://docs.godotengine.org/en/4.5/)
- [Migration Guide](https://docs.godotengine.org/en/4.5/tutorials/migrating/migrating_to_godot_4.html)
- [API Reference](https://docs.godotengine.org/en/4.5/classes/)
