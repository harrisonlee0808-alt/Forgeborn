# Forgeborn Vertical Slice Implementation

This document describes the minimal vertical slice implementation and how to run it.

## Overview

This vertical slice demonstrates the core mood and technical foundation of Forgeborn:
- Very dark caves with player-centered lighting
- Pixel-perfect rendering with a tiny player sprite
- Biome-based ambient audio (Crystal Chasm, placeholder audio file)
- Basic HUD showing Health and Charge (Charge drains over time)
- Automatic flag tracking system (flags set when player enters areas)

## Project Structure

```
Forgeborn/
├── project.godot          # Godot 4 project configuration
├── main.tscn             # Entry point scene
├── world.tscn            # Main game world scene
├── player.tscn           # Player character scene
├── hud.tscn              # HUD overlay scene
├── scripts/
│   ├── game_state.gd     # Autoload: Tracks flags, health, charge
│   ├── audio_manager.gd  # Autoload: Handles biome ambient audio
│   ├── player.gd         # Player movement and charge drain
│   ├── world.gd          # World setup and camera following
│   ├── hud.gd            # HUD display updates
│   └── area_trigger.gd   # Automatic flag setting on area entry
└── assets/
    ├── audio/            # Ambient audio files (placeholder)
    ├── sprites/          # Sprite assets (empty)
    └── textures/         # Texture assets (empty)
```

## Running the Project

1. Open the project in Godot 4.3 or later
2. Ensure `main.tscn` is set as the main scene (should be automatic)
3. Press F5 or click the "Play" button to run

### Controls

- **WASD** or **Arrow Keys**: Move player
- Movement is smooth, but camera snaps to pixel grid for pixel-perfect rendering

## Technical Implementation

### Pixel-Perfect Rendering

Configured in `project.godot`:
- `2d/snap/snap_2d_transforms_to_pixel=true`
- `2d/snap/snap_2d_vertices_to_pixel=true`
- `textures/canvas_textures/default_texture_filter=0` (nearest neighbor)
- `2d/smooth/sprite_frames_filtering=false`

Camera follows player with position smoothing, then snaps to integer pixels in `world.gd`.

### Lighting

- World background: Very dark blue-gray (`Color(0.05, 0.08, 0.12)`)
- Player has a `Light2D` with:
  - Energy: 1.5
  - Soft falloff (no custom texture yet, uses default)
  - Limited radius to create vulnerability feeling

### Player Character

- Size: 12×16px (ColorRect placeholder, neutral color)
- Positioned to be ~5-10% of screen height
- Movement speed: 100 pixels/second
- Has collision shape for physics

### HUD System

- Health bar: Shows current health (starts at 100)
- Charge bar: Shows current charge (starts at 100, drains 1 per second)
- Bars use dark, minimal palette (world colors)
- Updates continuously from `GameState`

### Audio System

- `AudioManager` is an autoload singleton
- Currently configured for Crystal Chasm biome
- Audio file placeholder: `assets/audio/crystal_chasm_ambient.ogg` (not yet created)
- System gracefully handles missing audio files (prints message, continues)
- Fade transitions are implemented for future biome changes

### Flag Tracking System

- `GameState` is an autoload singleton tracking:
  - `health` and `charge` (player resources)
  - `pacifism_count` and `violence_count` (encounter tracking)
  - `story_flags` (dictionary of string keys to values)
  - `areas_visited` (tracking unique areas)
  - `current_biome` (current biome context)

- Flags are set automatically (no UI prompts):
  - When player enters an `Area2D` with `area_trigger.gd` script
  - Area trigger has export variables: `flag_key`, `flag_value`, `area_id`
  - Example: Entering the AreaTrigger in world.tscn sets `visited_sacred_zone = true`

### Charge Drain System

- Charge drains 1.0 per second
- Implemented in `player.gd` using a timer
- Drains continuously while game is running
- When charge reaches 0, player can still move (behavior change stubbed for future)

## Current Limitations / Placeholders

1. **Player Sprite**: Uses ColorRect placeholder instead of actual sprite
2. **Light Texture**: Uses default Light2D texture (no custom soft gradient yet)
3. **Audio**: Audio file doesn't exist yet (system handles this gracefully)
4. **Terrain**: Just a dark background, no actual cave geometry
5. **Area Trigger**: One example trigger exists, but flag_key/area_id not set in scene (can be set in editor)
6. **Save/Load**: Stubbed in GameState, not yet implemented

## Next Steps (Future)

- Add actual player sprite (8-12px)
- Create soft circular gradient texture for Light2D
- Add Crystal Chasm ambient audio file
- Implement actual terrain/geometry
- Expand flag tracking with more examples
- Implement save/load system
- Add multiple biomes with transitions
- Add NPCs and dialogue
- Implement combat system

## Notes

- All code follows GDScript naming conventions
- Functions are small and modular
- Systems are data-driven where possible
- Minimal implementation focuses on core mood, not features

