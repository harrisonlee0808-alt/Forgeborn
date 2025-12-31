# 2D Platformer Implementation

This document describes the 2D platformer gameplay functionality added to Forgeborn.

## Overview

The game now features:
- Platformer physics with gravity, jumping, and movement
- A premade test map with solid geometry
- An interaction system for objects
- Three core interactable types

## Test Map (`scenes/test_map.tscn`)

The test map includes:
- **Ground**: Solid floor (2000px wide)
- **Left/Right Walls**: Side boundaries
- **Platforms**: Three horizontal platforms at different heights
- **Slope**: One optional slope for testing

All geometry uses `StaticBody2D` with `CollisionShape2D` for simplicity. Visuals are `ColorRect` nodes using the world palette.

## Player Movement (`scripts/player.gd`)

### Platformer Physics
- **Gravity**: 980 units/sec²
- **Speed**: 120 units/sec horizontal
- **Jump Velocity**: -300 units/sec (upward)
- **Coyote Time**: 0.15 seconds (can jump briefly after leaving ground)
- **Jump Buffer**: 0.1 seconds (jump input remembered before landing)
- **Air Control**: 60% of ground speed

### Controls
- **A/D or Left/Right Arrow**: Move horizontally
- **Space or Enter**: Jump
- **E**: Interact with nearest interactable

### Pixel-Perfect Motion
Player position is snapped to pixel grid after each frame for pixel-perfect rendering.

## Interaction System

### Base Class (`scripts/interactables/interactable_base.gd`)
All interactables extend `InteractableBase` which provides:
- `interaction_range`: Detection distance (default 80px)
- `can_interact()`: Check if interaction is possible
- `interact(player)`: Override in child classes

Player automatically finds nearest interactable within range and interacts when E is pressed.

### Core Interactables

#### 1. Door (`scripts/interactables/door.gd`)
- Opens if `required_flag` is set in GameState
- Sets `open_flag` when opened
- Door is a `StaticBody2D` with collision that disables when opened
- Visual feedback: door fades to transparent

#### 2. Lore Pickup (`scripts/interactables/lore_pickup.gd`)
- Adds a log entry when interacted
- Sets flag: `collected_<pickup_id>`
- Visual feedback: sprite brightens slightly
- Can only be collected once

#### 3. Trigger Zone (`scripts/interactables/trigger_zone.gd`)
- Automatically triggers when player enters (no E key needed)
- Sets flags and can trigger consequences:
  - `hud_flicker`: Flickers HUD bars
  - `audio_fade`: Fades audio layers
  - `light_change`: Changes player light energy
- Only triggers once

## Code Structure

```
scripts/
├── player.gd              # Movement and interaction detection
├── world.gd               # Scene orchestration
├── game_state.gd          # Flags, counters, log
└── interactables/
    ├── interactable_base.gd   # Base class
    ├── door.gd                # Door/barrier
    ├── lore_pickup.gd         # Lore collection
    └── trigger_zone.gd        # Area triggers
```

## Map Replacement

The test map is a separate scene (`scenes/test_map.tscn`) that can be easily replaced:
- Map is instanced in `world.tscn` as a child of World
- Simply swap the scene instance or create a new map scene
- All interactables are separate from map geometry

## Testing

Current test map setup:
- Player starts at (0, 100)
- LorePickup1 at (-400, 80) - collect with E
- Door1 at (400, 200) - requires `collected_lore_01` flag
- TriggerZone1 at (0, -80) - triggers HUD flicker

## Notes

- All movement respects pixel-perfect rendering
- Interaction system is expandable - add new interactable types by extending `InteractableBase`
- Flags are set automatically based on player actions (no explicit morality UI)
- Map geometry is separate from behavior for easy replacement

