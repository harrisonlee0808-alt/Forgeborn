Forgeborn — Visual Scale & Terrain Addendum (AI Reference)
Visual goal (non-negotiable)

The player character is very small relative to the screen.

Every pixel of the player sprite is readable at all times.

The world feels vast; the character feels fragile and “lost” inside it.

Overall aesthetic: cute, low-resolution indie pixel art, not realistic.

This is a scale and framing decision, not just an art decision, and must be enforced at the engine level.

1) Camera and pixel scale rules (Godot 4)
Player scale

Player sprite target size: ~8×12 px to 12×16 px

Sprite must never be scaled non-uniformly.

Animations rely on silhouette clarity, not detail density.

Camera framing

Player height should be approximately:

5–10% of the screen height at all times

Camera does not zoom in for combat or interactions.

This ensures:

large environmental context

strong loneliness / scale contrast

Pixel-perfect enforcement

Engine settings:

Disable texture filtering (nearest-neighbor only)

Use integer scaling

Snap rendered positions to pixel grid

Camera movement must be smoothed but pixel-aligned on final render

Rule: no sub-pixel jitter. If something moves, it moves in whole pixels visually.

2) Terrain system (smooth + destructible, pixel-consistent)
Destructible terrain representation

Terrain uses a hidden destructible mask, not visible tiles.

Mask resolution:

2×2 pixel cells (recommended)

Optional later test: 1×1 px for select areas if performance allows

Mask is chunked (e.g., 128×128 cells per chunk).

Digging / destruction

Digging clears mask cells in a brush shape (circle/square).

Brush radius can be any size → “break any size hole” illusion is preserved.

Only chunks affected by digging are rebuilt.

Geometry reconstruction

Use marching squares (or equivalent) per chunk to:

Generate collision polygons

Generate visual outlines

Rendering rule

Terrain visuals must:

Snap polygon vertices to pixel grid

Avoid anti-aliasing

Match pixel density of sprites

Important: even if collision is smooth, visuals must still look pixel-art, not vector art.

3) Static vs destructible geometry

Static slopes and ruins:

Built as StaticBody2D with CollisionPolygon2D

Pixel-aligned vertices

Destructible surfaces:

Must be part of the mask system

Cannot be “half destructible”

This avoids inconsistent player expectations.

4) Performance constraints (accepted tradeoffs)

To keep this practical:

Rebuild no more than a few terrain chunks per frame.

Queue rebuilds if digging is continuous (drill, explosions).

Simplify collision polygons:

Limit max vertices per polygon

Merge small adjacent polygons where possible

The design accepts:

Slightly “blocky” edges at extreme zoom (fits the indie look)

Quantization at the mask resolution scale

5) Art direction rules (for AI + asset generation)

Use limited color palettes per biome.

Avoid gradients; rely on flat color + contrast.

Detail is suggested, not drawn (cracks, glyphs, silhouettes).

The player sprite must:

Be readable in silhouette alone

Animate clearly at tiny scale

Stand out from terrain via contrast, not size

6) Why this supports iteration

This setup is intentionally:

close to final look early

flexible enough to tweak:

camera zoom

mask resolution

chunk size

edge smoothing aggressiveness

You can:

start with 2 px mask cells

adjust camera zoom slightly

tune player size ±2 px
without rewriting systems.