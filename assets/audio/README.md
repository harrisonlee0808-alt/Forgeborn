# Audio Assets

This directory contains ambient audio files for biomes.

## Current Placeholders

- `crystal_chasm_ambient.ogg` - Main ambient layer (required for Crystal Chasm)
- `crystal_chasm_rumble.ogg` - Low frequency rumble layer (optional, will gracefully skip if missing)
- `crystal_chasm_shimmer.ogg` - High frequency shimmer/sparkle layer (optional, will gracefully skip if missing)

## Audio Setup

When adding audio files, ensure they:
- Loop seamlessly
- Are appropriate volume (main ambient: -12dB, rumble: -20dB, shimmer: -25dB recommended)
- Match the mood of the biome

### Crystal Chasm
- Main ambient: Resonant, aware of player, pink/magenta palette feeling
- Rumble: Low frequency background texture (very quiet)
- Shimmer: High frequency sparkle/crystal sounds (very quiet)

The AudioManager will automatically set looping on OGG and MP3 files when they're loaded.
