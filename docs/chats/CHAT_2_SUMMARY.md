# Forgeborn Development Log - Cave Generation & Movement Systems

## Overview
This document summarizes the development work on cave generation, player movement, slope traversal, and step climbing systems for Forgeborn. The focus has been on creating organic, traversable cave systems with smooth, pixel-perfect movement that feels grounded and intentional.

## Major Systems Implemented

### 1. Cave Generation System

#### Initial Implementation
- **Large-scale organic caves**: Multi-layered noise generation using `FastNoiseLite`
- **Organic shapes**: Rounded walls and outcroppings using cellular automata smoothing
- **Safe spawn zones**: Algorithm to find and clear areas for player spawning
- **Boundaries**: Solid walls and floor to prevent infinite falling

#### Refinement: Small Caverns with Wormholes
- **Cavern-based generation**: 6-8 small, rounded caverns (30-60 tile radius)
- **Wormhole connections**: Procedural tunnels connecting caverns using Prim's algorithm
- **Minimum passage width**: Ensures all passages are at least 8 tiles (32px) wide for player traversal
- **Chunk-based loading**: Structured for future async chunk loading (200x200 tile chunks)

#### Current Parameters
```gdscript
TILE_SIZE = 4 pixels
CAVE_WIDTH = 600 tiles (2400 pixels)
CAVE_HEIGHT = 450 tiles (1800 pixels)
MIN_PASSAGE_WIDTH = 8 tiles (32 pixels)
```

### 2. Player Movement & Physics

#### Core Movement
- **Speed**: 180 px/s horizontal
- **Acceleration**: 1800 px/s²
- **Friction**: 2500 px/s² (high for responsive stopping)
- **Gravity**: 800 px/s²
- **Jump**: -350 px/s initial velocity

#### CharacterBody2D Settings
```gdscript
floor_stop_on_slope = false      # Critical for slope traversal
floor_constant_speed = false     # Allows natural speed variation
floor_snap_length = 0.0          # Dynamic (set based on movement)
floor_max_angle = 45°            # Maximum walkable slope angle
safe_margin = 0.5                # Small margin for edge cases
max_slides = 6                   # Allow multiple slide attempts
```

### 3. Slope Movement System

#### Design Philosophy
- **Continuous surfaces**: Slopes are smooth, not stair-stepped
- **Natural traversal**: Player walks up/down slopes without jumping
- **Speed adjustment**: Subtle speed reduction uphill (max 15%), slight boost downhill (max 5%)
- **Grounded feel**: Player stays "glued" to slope surface (no micro-airtime)
- **Pixel-perfect**: Final positions snap to pixels, calculations use sub-pixel precision

#### Implementation Details

**Dynamic Floor Snap:**
- **Uphill**: Floor snap enabled (6px) to keep player on slope
- **Downhill**: Floor snap disabled (0px) to prevent bouncing/jitter
- **In Air**: Always disabled

**Speed Multipliers:**
```gdscript
Uphill:   1.0 - (slope_angle / 45°) * 0.15  # Up to 15% slower
Downhill: 1.0 + (slope_angle / 45°) * 0.05  # Up to 5% faster
```

**Detection:**
- Uses `get_floor_normal()` to detect slope angle
- Determines uphill/downhill based on input direction vs. normal
- Only applies when `is_on_floor()` (never in air/jumping)

See `docs/SLOPE_MOVEMENT_GUIDE.md` for complete implementation guide.

### 4. Step Climbing System

#### Requirements
- Climb steps up to 1 tile (4 pixels) high when ascending
- Only from player's feet (bottom of collision shape)
- Smooth "lock on" movement, no jumping
- Only works when ascending, never when descending/falling/jumping

#### Implementation

**Detection Method:**
- Multiple raycasts at different heights (0, -0.5, -1, -1.5, -2px from feet)
- Checks ahead 24px for steps
- Finds lowest valid step (0.3px to 4px high)
- Fallback detection: Tests forward movement if primary raycasts miss

**Climbing:**
- Calculates upward velocity needed to reach step
- Accounts for gravity: `climb_distance * 40.0 + GRAVITY * delta * 3.0`
- Max climb velocity: 300 px/s
- Applied BEFORE `move_and_slide()` for reliable detection

**Key Code:**
```gdscript
# Detection happens before move_and_slide()
if is_on_floor() and input_dir != 0:
    # Multiple raycasts to find step
    # Calculate climb velocity
    step_climb_velocity = -min(required_velocity, 300.0)

# Apply before physics
if step_climb_velocity < 0:
    velocity.y = step_climb_velocity
```

### 5. Collision & Physics Fixes

#### Wall Collision
- Prevents player from moving into walls
- Checks collision normals after `move_and_slide()`
- Zeros horizontal velocity when pushing against horizontal walls

#### Floor Detection
- Improved `floor_snap_length` for better ground detection
- Dynamic snap based on movement direction (uphill vs. downhill)
- Prevents floating and ensures reliable ground contact

### 6. Camera & Viewport

#### Camera Settings
- **Zoom**: 3.5x (closer, more game-like perspective)
- **Smoothing**: Enabled (8.0 speed)
- **Bounds**: Matched to cave dimensions (±1200 x -1500 to 400)

#### Viewport
- **Size**: 3200x1800 pixels
- **Pixel-perfect**: All positions snap to integer pixels
- **Filtering**: Nearest-neighbor (no texture filtering)

### 7. Audio System

#### Implementation
- Simplified to use only available audio file (`crystal_chasm_ambient.ogg`)
- Multiple loading methods to handle import cache issues
- Graceful error handling with warnings
- Loop enabled in import settings

#### Current State
- Audio file exists and is valid (Ogg Vorbis, stereo, 44100 Hz)
- Import settings configured for looping
- System handles missing files gracefully

### 8. Interactables System

#### Procedural Placement
- Interactables generated in cave generator
- 4-6 interactables placed in different caverns (excluding spawn)
- Each has unique log entries added to game log when pressing 'E'
- Visual: Small gray squares (12x12px) with subtle glow

#### Removed from World Scene
- Old static interactables removed from `world.tscn`
- Particle effects removed
- All interactables now procedurally generated

## Technical Decisions

### Why Chunk-Based Structure?
- Future-proofing for larger worlds
- Better performance (can load/unload chunks)
- Easier to implement async generation later
- Currently processes all chunks synchronously but organized for chunk loading

### Why Multiple Raycasts for Steps?
- Single raycast can miss steps due to timing/position
- Multiple offsets catch steps at different positions
- Fallback detection ensures edge cases are handled
- More reliable than single-point detection

### Why Dynamic Floor Snap?
- Uphill: Need snap to stay on slope surface
- Downhill: No snap prevents bouncing/jitter
- In Air: No snap allows natural falling
- Creates smooth, natural movement feel

### Why Velocity-Based Step Climbing?
- More reliable than direct position manipulation
- Works with physics system naturally
- Smooth, predictable movement
- Easier to tune and debug

## Known Issues & Solutions

### Issue: Step Climbing Inconsistent
**Solution**: 
- Moved detection before `move_and_slide()`
- Multiple raycasts at different heights
- More aggressive velocity calculation
- Fallback detection method

### Issue: Player Moving Into Walls
**Solution**:
- Check collision normals after `move_and_slide()`
- Zero horizontal velocity when pushing against walls
- Only applies when input direction matches collision

### Issue: Floating Platforms
**Solution**:
- Modified `add_floors()` to only place floors connected to walls
- Checks that tile below is WALL, WALL_DARK, or FLOOR before placing

### Issue: Audio Not Playing
**Solution**:
- Multiple loading methods (direct load, ResourceLoader with cache ignore)
- Set loop=true in import file
- Graceful error handling

## File Structure

### Modified Files
- `scripts/cave_generator.gd` - Complete rewrite for cavern-based generation
- `scripts/player.gd` - Slope movement and step climbing implementation
- `scripts/world.gd` - Camera zoom and bounds updates
- `scripts/audio_manager.gd` - Simplified audio loading
- `world.tscn` - Removed static interactables and particles
- `player.tscn` - Player size adjustments
- `project.godot` - Viewport size increases

### New Files
- `docs/SLOPE_MOVEMENT_GUIDE.md` - Complete slope movement implementation guide
- `docs/DEVELOPMENT_LOG.md` - This file

### Deleted Files
- `scripts/lore_pickup.gd` (duplicate)
- `scenes/test_map.tscn` (replaced by procedural generation)
- `input.mp3` (unused test file)

## Testing Checklist

### Cave Generation
- [x] Caverns generate with organic shapes
- [x] Wormholes connect all caverns
- [x] Passages are wide enough for player (32px minimum)
- [x] No floating platforms
- [x] Safe spawn zone exists
- [x] Boundaries prevent infinite falling

### Player Movement
- [x] Smooth horizontal movement
- [x] Jumping works correctly
- [x] Wall collision prevents clipping
- [x] Pixel-perfect rendering maintained

### Slope Movement
- [x] Player walks up slopes without jumping
- [x] Player walks down slopes without bouncing
- [x] Speed adjusts subtly based on slope angle
- [x] Smooth transitions (flat↔slope)
- [x] No micro-airtime on slopes

### Step Climbing
- [x] Climbs 1-tile (4px) steps when ascending
- [x] Only works when on floor
- [x] Never applies when descending/falling/jumping
- [x] Smooth, reliable detection

### Audio
- [x] Audio loads and plays
- [x] Loops correctly
- [x] Graceful error handling

### Interactables
- [x] Procedurally placed in caves
- [x] Can be interacted with (E key)
- [x] Adds entries to game log
- [x] Visual feedback when collected

## Performance Notes

### Cave Generation
- Current: Synchronous generation of all chunks
- Future: Can be made async for larger worlds
- Optimization: Reduced smoothing passes, outcropping count
- Chunk size: 200x200 tiles balances performance and organization

### Movement
- Step detection: Multiple raycasts per frame (acceptable for small player)
- Slope detection: Single `get_floor_normal()` call (very efficient)
- Pixel snapping: Single `round()` call per frame (negligible cost)

## Future Improvements

### Cave Generation
- Async chunk loading as player moves
- More varied cavern shapes
- Biome-specific generation parameters
- Destructible terrain integration

### Movement
- Tune step climbing velocity for edge cases
- Add visual feedback for step climbing
- Consider shape casts instead of raycasts for steps
- Fine-tune slope speed multipliers based on playtesting

### Audio
- Add more biome audio files
- Implement audio fade transitions between biomes
- Add sound effects for interactions

## Key Learnings

1. **Step climbing requires detection BEFORE physics**: Detecting steps after `move_and_slide()` is unreliable
2. **Dynamic floor snap is critical**: Different snap values for uphill vs. downhill prevent jitter
3. **Multiple detection methods improve reliability**: Single raycast can miss, multiple raycasts catch edge cases
4. **Velocity-based movement feels better**: Direct position manipulation causes visual popping
5. **Pixel-perfect requires careful timing**: Snap positions AFTER all calculations, not during

## References

- `docs/SPEC.md` - Visual scale and terrain specifications
- `docs/GRAPHICS.md` - Visual language and lighting
- `docs/STORYLINE.md` - Game world and narrative context
- `docs/SLOPE_MOVEMENT_GUIDE.md` - Complete slope movement guide

