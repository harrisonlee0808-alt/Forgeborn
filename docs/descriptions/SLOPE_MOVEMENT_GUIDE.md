# Slope Movement Implementation Guide

## 1. How Slope Movement Should Work (Plain Language)

**The Core Concept:**
When the player walks on a slope, they should move along the slope's surface, not through it. Think of it like walking up a ramp in real life—your feet stay on the ramp, and your body naturally follows the angle.

**Key Behaviors:**
- **Uphill (ascending)**: Player moves slower horizontally (subtle speed reduction), stays glued to the slope surface
- **Downhill (descending)**: Player moves at normal speed, no bouncing or jitter, smooth descent
- **Transitions**: Moving from flat→slope or slope→flat should feel seamless, no sudden position corrections
- **Grounded**: Player should never have micro-airtime on slopes—they're always "stuck" to the surface when on floor

**What Makes It Feel Good:**
- The player's horizontal speed naturally adjusts based on slope angle
- No visual "popping" or position snapping
- Movement feels intentional and controlled, not floaty
- Pixel-perfect rendering is maintained (final positions snap to pixels, but calculations can use sub-pixels)

## 2. Recommended Collision Setup

### For Static Slopes (Current Implementation)

**Option A: CollisionPolygon2D (Recommended for smooth slopes)**
```
StaticBody2D (slope)
  └─ CollisionPolygon2D
      └─ Polygon with 4 vertices forming a ramp
          Example: [(0, 0), (100, 0), (100, -20), (0, -20)]
          This creates a 20-pixel high ramp over 100 pixels (≈11.3° slope)
```

**Option B: Rotated RectangleShape2D (Simpler, but less flexible)**
```
StaticBody2D (slope)
  └─ CollisionShape2D
      └─ RectangleShape2D (rotated to desired angle)
```

**Best Practice:**
- Use CollisionPolygon2D for slopes—it's more flexible and handles transitions better
- Keep polygon vertices pixel-aligned (snap to 4px grid to match tile size)
- For shallow slopes (15-30°), use longer polygons (200-400px) for smooth traversal
- For steeper slopes (30-45°), shorter polygons work fine

### CharacterBody2D Settings

```gdscript
floor_stop_on_slope = false      # Critical: allows movement up slopes
floor_constant_speed = false     # Allows natural speed variation
floor_snap_length = 6.0          # Dynamic (see implementation)
floor_max_angle = deg_to_rad(45) # Maximum walkable slope angle
safe_margin = 0.5                # Small margin for edge cases
max_slides = 6                   # Allow multiple slide attempts
```

## 3. Step-by-Step Implementation Plan

### Phase 1: Detect Slope State
1. After `move_and_slide()`, check if player is on floor
2. Get floor normal using `get_floor_normal()`
3. Calculate slope angle from normal
4. Determine if moving uphill or downhill based on input direction vs normal

### Phase 2: Adjust Floor Snap (Critical)
1. **Uphill**: Enable floor snap (6-8px) to keep player glued to slope
2. **Downhill**: Disable floor snap (0px) to prevent bouncing/jitter
3. **In Air/Jumping**: Always disable floor snap

### Phase 3: Project Velocity Along Slope
1. Calculate tangent direction along slope (perpendicular to normal)
2. Project current velocity onto tangent
3. Apply speed multiplier based on slope angle and direction
4. Reconstruct velocity vector along slope surface

### Phase 4: Handle Transitions
1. Detect when transitioning from flat→slope or slope→flat
2. Smoothly adjust floor snap and velocity projection
3. Avoid sudden position corrections

### Phase 5: Pixel-Perfect Final Position
1. After all calculations, snap final position to pixel grid
2. This maintains pixel-perfect rendering while allowing smooth sub-pixel calculations

## 4. Example GDScript Implementation

### Core Slope Detection and Movement

```gdscript
func _physics_process(delta: float):
    # ... existing gravity, jump, input handling ...
    
    var input_x = get_input_direction()
    var want_move = abs(input_x) > 0.0
    var on_floor = is_on_floor()
    var is_jumping = velocity.y < 0  # Moving upward = jumping
    
    # Get floor normal (Vector2.UP if not on floor)
    var floor_normal = get_floor_normal() if on_floor else Vector2.UP
    
    # Calculate slope angle
    var slope_angle = 0.0
    var on_slope = false
    if on_floor:
        # Angle from vertical (0 = flat, PI/2 = vertical wall)
        slope_angle = acos(clamp(floor_normal.dot(Vector2.UP), -1.0, 1.0))
        on_slope = slope_angle > 0.01 and slope_angle < floor_max_angle
    
    # Determine movement direction relative to slope
    var moving_uphill = false
    var moving_downhill = false
    if on_slope and want_move:
        # Uphill: input direction opposes normal.x (moving against the slope)
        # Downhill: input direction aligns with normal.x (moving with the slope)
        moving_uphill = (input_x * floor_normal.x < 0.0)
        moving_downhill = (input_x * floor_normal.x > 0.0)
    
    # Dynamic floor snap: ONLY when moving uphill and not jumping
    if moving_uphill and not is_jumping:
        floor_snap_length = 6.0  # Tune: 4-8px for your scale
    else:
        floor_snap_length = 0.0  # Disable snap downhill and in air
    
    # Calculate horizontal velocity
    if on_floor:
        if want_move:
            # Base target speed
            var target_speed = input_x * MAX_SPEED
            
            # Apply speed multiplier based on slope
            if on_slope:
                target_speed *= get_slope_speed_multiplier(slope_angle, moving_uphill)
            
            # Accelerate toward target
            velocity.x = move_toward(velocity.x, target_speed, ACCELERATION * delta)
        else:
            # Apply friction
            velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
    else:
        # Air control (unchanged)
        if want_move:
            velocity.x = move_toward(velocity.x, input_x * MAX_SPEED, AIR_ACCELERATION * delta)
        else:
            velocity.x = move_toward(velocity.x, 0, AIR_FRICTION * delta)
    
    # Apply movement
    move_and_slide()
    
    # Pixel-perfect final position
    global_position = global_position.round()
```

### Speed Multiplier Function

```gdscript
func get_slope_speed_multiplier(slope_angle: float, is_uphill: bool) -> float:
    if not is_uphill:
        # Downhill: slight speed boost (gravity assists)
        # Very subtle - max 5% faster at 45°
        return 1.0 + (slope_angle / deg_to_rad(45.0)) * 0.05
    else:
        # Uphill: speed reduction (climbing takes effort)
        # Subtle but noticeable - max 15% slower at 45°
        return 1.0 - (slope_angle / deg_to_rad(45.0)) * 0.15
```

### Advanced: Project Velocity Along Slope Surface

```gdscript
func handle_slope_movement(input_x: float, floor_normal: Vector2, delta: float):
    if input_x == 0.0:
        # No input: apply friction along slope
        var slope_tangent = Vector2(-floor_normal.y, floor_normal.x)
        var current_speed_along_slope = velocity.dot(slope_tangent)
        var new_speed = move_toward(current_speed_along_slope, 0.0, FRICTION * delta)
        velocity = slope_tangent * new_speed
        return
    
    # Calculate tangent direction along slope (perpendicular to normal)
    var slope_tangent = Vector2(-floor_normal.y, floor_normal.x)
    if input_x < 0:
        slope_tangent = -slope_tangent  # Reverse for left movement
    
    # Calculate speed multiplier
    var slope_angle = acos(clamp(floor_normal.dot(Vector2.UP), -1.0, 1.0))
    var is_uphill = (input_x * floor_normal.x < 0.0)
    var speed_mult = get_slope_speed_multiplier(slope_angle, is_uphill)
    
    # Target velocity along slope
    var target_speed_along_slope = MAX_SPEED * speed_mult
    var target_velocity = slope_tangent * target_speed_along_slope
    
    # Accelerate toward target
    var current_speed_along_slope = velocity.dot(slope_tangent)
    var new_speed = move_toward(current_speed_along_slope, target_speed_along_slope, ACCELERATION * delta)
    
    # Project velocity onto slope surface
    velocity = slope_tangent * new_speed
```

## 5. Common Mistakes to Avoid

### ❌ Mistake 1: Always Using Floor Snap
**Problem:** Setting `floor_snap_length` to a constant value causes bouncing/jitter when descending slopes.
**Solution:** Dynamically adjust floor snap—enable only when moving uphill, disable when descending or in air.

### ❌ Mistake 2: Manually Adjusting Y Position
**Problem:** Code like `global_position.y -= climb_amount` creates visual popping and breaks pixel-perfect rendering.
**Solution:** Let `move_and_slide()` handle vertical movement. Only adjust velocity, never directly modify position (except final pixel snap).

### ❌ Mistake 3: Ignoring Floor Normal
**Problem:** Assuming all floors are flat and using only horizontal velocity.
**Solution:** Always check `get_floor_normal()` and project movement along the slope surface.

### ❌ Mistake 4: Speed Multipliers That Are Too Extreme
**Problem:** Making uphill movement 50% slower feels punishing and breaks flow.
**Solution:** Keep speed adjustments subtle (10-15% max reduction uphill, 5% max boost downhill).

### ❌ Mistake 5: Not Handling Transitions
**Problem:** Player "pops" when moving from flat ground to slope or vice versa.
**Solution:** Smoothly transition floor snap and velocity projection over 1-2 frames.

### ❌ Mistake 6: Applying Slope Logic in Air
**Problem:** Slope movement code runs while jumping, causing weird mid-air behavior.
**Solution:** Always check `is_on_floor()` before applying slope-specific logic.

### ❌ Mistake 7: Pixel Snapping Before move_and_slide()
**Problem:** Snapping position to pixels before physics calculations causes jitter.
**Solution:** Do all calculations with sub-pixel precision, then snap final position to pixels AFTER `move_and_slide()`.

### ❌ Mistake 8: Using Stair-Step Collision for Slopes
**Problem:** Creating slopes from multiple small horizontal segments causes jittery movement.
**Solution:** Use continuous CollisionPolygon2D shapes for smooth slopes.

## 6. Testing Checklist

- [ ] Player smoothly walks up shallow slopes (15-20°) without jumping
- [ ] Player smoothly walks down slopes without bouncing or jitter
- [ ] Speed feels slightly reduced when ascending, normal when descending
- [ ] No visual "popping" when transitioning flat→slope or slope→flat
- [ ] Player stays grounded on slopes (no micro-airtime)
- [ ] Jumping works normally on slopes (not affected by slope logic)
- [ ] Pixel-perfect rendering maintained (no sub-pixel blur)
- [ ] Works at chunk boundaries (if applicable)
- [ ] Very steep slopes (>45°) become non-walkable as expected

## 7. Tuning Values

**Floor Snap Length:**
- 4px: Very tight, may cause issues on fast movement
- 6px: Recommended starting point
- 8px: More forgiving, but may feel "sticky"

**Speed Multipliers:**
- Uphill reduction: 0.10-0.15 (10-15% slower)
- Downhill boost: 0.03-0.05 (3-5% faster)

**Slope Angle Limits:**
- 15-30°: Easy traversal, minimal speed reduction
- 30-40°: Moderate difficulty, noticeable speed reduction
- 40-45°: Challenging, significant speed reduction
- >45°: Non-walkable (requires jumping)

## Priority: Correct Feel > Realism > Simplicity

Remember: The goal is movement that feels intentional and grounded, not physically accurate. If a subtle "cheat" makes the game feel better, use it.

