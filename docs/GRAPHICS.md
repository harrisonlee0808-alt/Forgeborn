Forgeborn — Graphics & Visual Language Spec (No-Personality Edition)
Core visual philosophy

No expressive terrain.
Terrain does not “emote,” curl, or decorate itself.

No organic personality in caves or walls (no vines, faces, stylized cracks).

Visual interest comes from:

scale

negative space

lighting

rare color exceptions

The world should feel indifferent, not alive.

1) Palette strategy (global consistency)
Global palette rule

Use one master neutral palette across most of the game:

dark blacks

deep blue-grays / green-grays

muted desaturated mid-tones

UI, terrain, props, enemies all derive from this same palette.

This creates:

cohesion

low visual noise

a “machine world” feeling

Biome exception rule

Only alien or anomalous biomes are allowed to break the palette.

Examples:

Crystal Chasm: 3–4 pink/magenta tones only

Radiant Forest: limited cyan/green glow accent

Magnetar Valley: pale interference whites + muted teal

Temple of Echoes: gold/yellow accents only

Hard rule:
No biome may introduce more than one accent color family.

2) Terrain and environment visuals
Terrain appearance

Terrain textures are:

flat or lightly dithered

no highlights

no directional lighting baked into sprites

Use tileless textures or procedural fills for destructible terrain.

Terrain should read as:

mass

obstruction

emptiness

Not as “rock with character.”

Static structures (ruins, temples)

Built from:

simple rectangles

repeating motifs

symmetry

No erosion detail unless it serves scale.

Think:

“This was built by machines that didn’t care how it looked.”

3) Lighting is the main visual feature

This is the most important part of your look.

Global darkness

The world is very dark, especially caves.

Default visibility is low.

You should not be able to see the full room clearly.

Player-centered light

The player emits a soft radial light:

brighter near the player

fast falloff

Light radius should be just large enough to:

see immediate terrain

navigate safely

never fully reveal large spaces

This reinforces:

vulnerability

scale

isolation

Implementation (Godot 4)

Use Light2D on the player:

texture: soft circular gradient

blend mode: additive or mix (test both)

World uses:

very dark ambient color

minimal secondary lights (rare, purposeful)

Biome lighting overrides

Some biomes may:

slightly increase ambient light

tint the player light color subtly (e.g., pink in crystal biome)

But the player light remains the primary readable light source.

4) UI visuals (must obey the world palette)
UI rules

UI uses the same neutral palette as the world.

No bright HUD colors.

Health/charge bars:

thin

minimal

low contrast until critical

UI should feel:

embedded

informational

non-intrusive

Think “instrument panel,” not “game HUD.”

5) Characters and enemies
Player

High contrast against terrain.

Simple silhouette.

Small, readable, neutral.

No expressive face needed.

Enemies

Designed as:

shapes first

detail last

No exaggerated animations.

Movement and sound convey threat, not visuals.

NPCs

Slightly more readable than enemies.

Still restrained; no personality animation unless narratively justified.

6) Asset creation strategy (best for non-artists)
What you should NOT do

Don’t try to hand-draw detailed sprites.

Don’t mix asset packs with wildly different styles.

Don’t use colorful or expressive tilesets.

What you SHOULD do

Generate or find very plain base assets

flat cave textures

simple blocks

abstract ruin shapes

Force everything into your palette

indexed color mode

one palette per biome

Rely on lighting and scale

darkness hides simplicity

light creates drama

This means your art can be:

technically simple

visually strong

7) Why this works for iteration

This art direction:

scales well as content grows

avoids “art debt”

lets you tweak:

palette values

light radius

contrast
without redrawing assets

It’s ideal for:

“Get it close, then tweak the end product.”