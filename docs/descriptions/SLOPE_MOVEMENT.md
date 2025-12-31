# Slope Movement System Design & Implementation

## 1. Conceptual Explanation: How Slope Movement Should Work

### Core Principle: Project Velocity Along the Slope Surface

When a player walks on a slope, they don't move purely horizontally or vertically. Instead, their movement follows the slope's surface. Think of it like this:

- **On flat ground**: Player moves horizontally at full speed
- **On upward slope**: Player moves along the slope surface, which means:
  - Horizontal component is slightly reduced (climbing takes effort)
  - Vertical component follows the slope angle (naturally moves up)
- **On downward slope**: Player moves along the slope surface:
  - Horizontal component may slightly increase (gravity assists)
  - Vertical component follows the slope angle (naturally moves down)

### Key Behaviors:

1. **Grounded Detection**: The player must stay "glued" to the slope when grounded. This means:
   - `is_on_floor()` should return true when on a slope
   - The player should not experience micro-airtime between frames
   - `get_floor_normal()` gives us the slope's perpendicular direction

2. **Velocity Projection**: Instead of applying horizontal velocity and letting gravity pull down, we:
   - Calculate desired movement direction (input direction along slope)
   - Project velocity along the slope surface
   - Let `move_and_slide()` handle the physics, but we guide it correctly

3. **Speed Modulation**: 
   - Ascending: Slightly reduce effective speed (e.g., 85-95% of max speed)
   - Descending: Maintain or slightly increase speed (gravity assists)
   - This should be subtle, not punishing

4. **Transition Handling**:
   - Flat → Slope: Player naturally transitions without snapping
   - Slope → Flat: Player continues smoothly without bouncing
   - Slope → Air: Player leaves the slope naturally when jumping or falling off edge

## 2. Recommended Collision Setup for Slopes

### Current System (Rectangular Tiles)
Your current system uses `RectangleShape2D` for terrain, which creates stair-stepped collisions. This won't work for slopes.

### Recommended: CollisionPolygon2D for Slopes

For slopes, use `CollisionPolygon2D` with a polygon that matches the slope's surface:

```
StaticBody2D (Slope)
├── CollisionPolygon2D
│   └── Polygon: [top_left, top_right, bottom_right, bottom_left]
│       (Creates a diagonal surface)
└── Visual (ColorRect or Sprite)
```

**Important**: 
- Polygon vertices should be pixel-aligned (per SPEC.md requirements)
- The polygon should have a slight thickness (not just a line) to ensure reliable collision
- Use 4 vertices for a simple slope, more for curved surfaces

### Hybrid Approach (Recommended for Your Game)

Since you have both flat tiles and slopes:

1. **Flat terrain**: Keep using `RectangleShape2D` (current system)
2. **Slopes**: Use `CollisionPolygon2D` with diagonal polygons
3. **Transitions**: Ensure slopes connect smoothly to flat terrain

### Example Slope Creation:

```gdscript
# In cave_generator.gd or terrain builder
func create_slope(start_pos: Vector2, end_pos: Vector2, thickness: float = 4.0):
    var body = StaticBody2D.new()
    body.position = (start_pos + end_pos) / 2.0
    
    var collision = CollisionPolygon2D.new()
    var polygon = PackedVector2Array()
    
    # Create a diagonal rectangle (slope surface)
    var direction = (end_pos - start_pos).normalized()
    var perpendicular = Vector2(-direction.y, direction.x) * thickness / 2.0
    
    polygon.append(start_pos - body.position + perpendicular)
    polygon.append(start_pos - body.position - perpendicular)
    polygon.append(end_pos - body.position - perpendicular)
    polygon.append(end_pos - body.position + perpendicular)
    
    collision.polygon = polygon
    body.add_child(collision)
    
    return body
```

## 3. Step-by-Step Implementation Plan

### Phase 1: Detect Slope Angle and Normal
1. After `move_and_slide()`, check if player is on floor
2. Get floor normal using `get_floor_normal()`
3. Calculate slope angle from normal
4. Determine if slope is walkable (within `floor_max_angle`)

### Phase 2: Project Movement Along Slope
1. Calculate desired movement direction (input-based)
2. Project this direction onto the slope plane
3. Apply speed modulation based on slope angle
4. Set velocity before `move_and_slide()`

### Phase 3: Ensure Grounded State
1. Use `floor_snap_length` to help player stick to slopes
2. After movement, verify player is still on floor
3. If not, apply small correction to maintain contact

### Phase 4: Handle Transitions
1. Detect when transitioning between flat and slope
2. Smoothly adjust movement parameters
3. Prevent snapping or bouncing

### Phase 5: Pixel-Perfect Alignment
1. After all movement calculations, snap position to pixel grid
2. Ensure this doesn't break slope contact
3. Verify visual stability

## 4. GDScript Implementation

### Detecting Slope Angle

```gdscript
func get_slope_info() -> Dictionary:
    if not is_on_floor():
        return {"on_slope": false, "angle": 0.0, "normal": Vector2.UP}
    
    var floor_normal = get_floor_normal()
    var slope_angle = acos(floor_normal.dot(Vector2.UP))
    
    return {
        "on_slope": slope_angle > 0.01,  # Not perfectly flat
        "angle": slope_angle,
        "normal": floor_normal
    }
```

### Projecting Movement Along Slope

```gdscript
func project_velocity_along_slope(desired_velocity: Vector2, slope_normal: Vector2) -> Vector2:
    # Project desired velocity onto the slope plane
    # The slope plane is perpendicular to the normal
    
    # Remove component perpendicular to slope (this would push into/away from slope)
    var perpendicular_component = desired_velocity.dot(slope_normal) * slope_normal
    var projected_velocity = desired_velocity - perpendicular_component
    
    return projected_velocity
```

### Speed Modulation Based on Slope Angle

```gdscript
func get_slope_speed_multiplier(slope_angle: float, is_ascending: bool) -> float:
    if not is_ascending:
        # Descending: slight speed boost (gravity assists)
        return 1.0 + (slope_angle / deg_to_rad(45.0)) * 0.1  # Up to 10% faster
    else:
        # Ascending: slight speed reduction (climbing takes effort)
        return 1.0 - (slope_angle / deg_to_rad(45.0)) * 0.15  # Up to 15% slower
```

### Complete Slope Movement Integration

```gdscript
func _physics_process(delta: float):
    # ... existing gravity, jump, input handling ...
    
    var input_dir = 0.0
    if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
        input_dir -= 1.0
    if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
        input_dir += 1.0
    
    # Handle movement
    if is_on_floor():
        var slope_info = get_slope_info()
        
        if slope_info.on_slope:
            # On a slope - project movement along slope surface
            var desired_direction = Vector2(input_dir, 0.0)
            
            # Determine if ascending or descending
            var is_ascending = slope_info.normal.y < 0.9  # Normal points up when ascending
            var speed_mult = get_slope_speed_multiplier(slope_info.angle, is_ascending)
            
            # Project desired direction onto slope plane
            var slope_tangent = Vector2(-slope_info.normal.y, slope_info.normal.x)
            var projected_direction = slope_tangent * input_dir
            
            # Apply speed with modulation
            var target_speed = projected_direction * MAX_SPEED * speed_mult
            velocity.x = move_toward(velocity.x, target_speed.x, ACCELERATION * delta)
            velocity.y = move_toward(velocity.y, target_speed.y, ACCELERATION * delta)
        else:
            # Flat ground - normal horizontal movement
            if input_dir != 0:
                velocity.x = move_toward(velocity.x, input_dir * MAX_SPEED, ACCELERATION * delta)
            else:
                velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
    else:
        # Air control (unchanged)
        if input_dir != 0:
            velocity.x = move_toward(velocity.x, input_dir * MAX_SPEED, AIR_ACCELERATION * delta)
        else:
            velocity.x = move_toward(velocity.x, 0, AIR_FRICTION * delta)
    
    # Apply movement
    move_and_slide()
    
    # Ensure we stay grounded on slopes (prevent micro-airtime)
    if is_on_floor():
        var floor_normal = get_floor_normal()
        # If we're moving along a slope, ensure we're properly positioned
        # move_and_slide() handles this, but we can add a small correction if needed
        pass  # Usually not needed if floor_snap_length is set correctly
    
    # Pixel-perfect snapping (after all movement)
    global_position = global_position.round()
```

## 5. Common Mistakes to Avoid

### ❌ Mistake 1: Applying Y-Velocity Manually
**Wrong**: `velocity.y = -some_value` when ascending
**Why**: This fights against `move_and_slide()` and causes jitter
**Correct**: Let `move_and_slide()` handle vertical movement based on slope contact

### ❌ Mistake 2: Snapping Position Before move_and_slide()
**Wrong**: Snap position, then call `move_and_slide()`
**Why**: Breaks slope contact detection
**Correct**: Call `move_and_slide()` first, then snap position

### ❌ Mistake 3: Using Rectangular Collision for Slopes
**Wrong**: Using `RectangleShape2D` rotated for slopes
**Why**: Creates stair-stepped collision, not smooth slopes
**Correct**: Use `CollisionPolygon2D` with diagonal polygons

### ❌ Mistake 4: Ignoring Floor Normal
**Wrong**: Only checking `is_on_floor()` without considering slope angle
**Why**: Can't differentiate between flat and sloped surfaces
**Correct**: Always check `get_floor_normal()` to get slope information

### ❌ Mistake 5: Over-Correcting Position
**Wrong**: Manually adjusting position after every frame to "stick" to slope
**Why**: Causes jitter and breaks natural movement
**Correct**: Trust `move_and_slide()` with proper `floor_snap_length` and `floor_max_angle`

### ❌ Mistake 6: Not Handling Transitions
**Wrong**: Abruptly changing movement behavior when entering/exiting slopes
**Why**: Causes snapping, bouncing, or getting stuck
**Correct**: Smoothly transition movement parameters

### ❌ Mistake 7: Speed Modulation Too Aggressive
**Wrong**: Reducing speed by 50% when ascending
**Why**: Feels punishing and breaks game flow
**Correct**: Subtle reduction (10-15% max) that feels natural

### ❌ Mistake 8: Not Setting floor_max_angle Correctly
**Wrong**: Using default or too-small angle limit
**Why**: Player can't walk on moderate slopes
**Correct**: Set `floor_max_angle = deg_to_rad(45)` or higher for your game

## 6. Integration with Your Current System

### Current State Analysis:
- You're using `RectangleShape2D` for terrain (tile-based)
- You have step climbing logic (1-tile steps)
- You have `floor_max_angle = deg_to_rad(30)` set
- Movement is pixel-perfect with position snapping

### Recommended Integration Path:

1. **Keep step climbing** for discrete 1-tile steps (your current system works)
2. **Add slope support** for continuous surfaces (new system)
3. **Prioritize slope detection** over step detection when both are possible
4. **Maintain pixel-perfect behavior** by snapping after all movement

### Modified Player Movement Logic:

```gdscript
# In _physics_process, after input handling:

if is_on_floor():
    var slope_info = get_slope_info()
    
    if slope_info.on_slope and slope_info.angle < floor_max_angle:
        # Use slope movement (continuous surface)
        # ... slope movement code from section 4 ...
    elif input_dir != 0:
        # Check for step climbing (discrete steps)
        # ... your existing step climbing code ...
    else:
        # Flat ground, no input
        velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
```

This ensures slopes take priority over step climbing, which is correct since slopes are continuous surfaces.

## 7. Testing Checklist

- [ ] Player walks up shallow slopes (15-20°) smoothly
- [ ] Player walks up moderate slopes (30-35°) with slight speed reduction
- [ ] Player walks down slopes without bouncing or jitter
- [ ] Player transitions from flat to slope smoothly
- [ ] Player transitions from slope to flat smoothly
- [ ] Player can jump from slopes normally
- [ ] Player falls off slope edges naturally (no sticking)
- [ ] No sub-pixel jitter or camera blur
- [ ] Movement feels grounded and intentional
- [ ] Speed modulation is subtle, not punishing

## 8. Performance Considerations

- `get_floor_normal()` is called every frame - this is fine, it's optimized
- Slope detection adds minimal overhead
- CollisionPolygon2D is efficient for simple slopes (4 vertices)
- For many slopes, consider batching collision shapes or using TileMap with custom collision

## 9. Future-Proofing for Chunk System

When implementing chunk-based terrain:
- Ensure slope polygons span chunk boundaries correctly
- Test transitions between chunks with slopes
- Consider caching slope information per chunk
- Verify pixel-perfect behavior at chunk edges

