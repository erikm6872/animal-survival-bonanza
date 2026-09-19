# World Generation

Everything about the world is generated at runtime from procedural code —
there's no hand-authored terrain mesh or level layout. Four scripts under
`scripts/world/`, all keyed off one shared height function.

## `TerrainHeight` (`terrain_height.gd`) — the single source of truth

A `RefCounted` with only `static` members — not a node, just a namespace of
pure functions. `TerrainHeight.get_height(x, z)` is the *only* place ground
height is computed, and everything that needs to know "how tall is the
ground here" calls it, rather than sampling the generated mesh or keeping
its own copy: `terrain_generator.gd` (mesh + collision), `biome_populator.gd`
(tree/bush placement), `player_spawner.gd` and `training_dummy.gd` (spawn
height), and `water_generator.gd` (matching the water surface to the carved
bed). If two of these ever disagreed about ground height, trees would float
or sink and the player would clip into or hover above the terrain — the
single-function design is what guarantees they can't disagree.

`get_height()` composes, in order:

1. **Base rolling hills** — two layered `FastNoiseLite` samples (a large-
   scale one for the hills, a smaller-amplitude/higher-frequency one for
   detail).
2. **Mountains** (`_mountain_height()`) — ridged noise (`1 - abs(noise)`,
   the standard trick for a range of jagged peaks rather than smooth
   bumps), ramped in by `smoothstep` over radial distance from the map
   center. Zero inside `MOUNTAIN_START_RADIUS` (65) — the playable area,
   where trees scatter out to radius 90 — rising to full height by
   `MOUNTAIN_END_RADIUS` (100), the edge of the terrain mesh.
3. **Water carving** (`_carve_water()`) — only ever *lowers* the height
   from step 1+2, smoothly blending back up to the untouched terrain at the
   edge of each bank/shore so there's a real slope instead of a cliff. This
   is also where the river's stepped water level (see
   [Waterfall](#the-waterfall) below) and the two ponds' basins are carved.

`TerrainHeight` also exposes `river_center_z(x)` (the river's meander, a
sine wave) and `is_water(x, z)` (true inside the river channel or a pond,
ignoring their sloped banks — used to keep trees out of the water).

## `terrain_generator.gd` — the mesh and its collision

Builds a `RESOLUTION`×`RESOLUTION` (100×100) grid `ArrayMesh` at runtime,
sampling `TerrainHeight.get_height()` at every vertex, plus a matching
`HeightMapShape3D` for collision (same sampling, so the physics body and
the visible mesh can never disagree). Runs once in `_ready()`.

**Height-based coloring:** vertex colors blend grass → bare rock → snow
cap by height (`_height_color()`), so the mountains read as actual terrain
instead of giant green hills. `GameState.season_changed` (see
[UI and Menus](UI-And-Menus.md)) triggers a full `_build_mesh()` rebuild to
swap in a winter (pale/snow) or summer (green) palette — cheap enough at
this resolution not to matter, and simpler than patching the color array
in place.

> **Gotcha:** mesh vertex colors are read back as **linear**, but color
> literals written the way you'd type into `albedo_color` (like this
> project's grass/rock/snow palette) are **sRGB**. Assigning them straight
> into the `ARRAY_COLOR` array without `.srgb_to_linear()` first renders
> everything far paler than the numbers suggest — this actually shipped
> once (see git history: "Fix terrain vertex colors being washed out toward
> white") before being caught.

## `water_generator.gd` — river, waterfall, ponds

All visual only — there's no swimming collision yet, so the player can
currently walk down into a basin and end up under the water plane
(harmless-looking, since the water material has `cull_mode = CULL_DISABLED`
so it renders from underneath too, but not "real" water).

- **Ponds** — a flat `CylinderMesh` per entry in `TerrainHeight.PONDS`, at
  that pond's `water_level`.
- **River** — a ribbon mesh (a strip of quads following
  `TerrainHeight.river_center_z(x)`) at `RIVER_WATER_LEVEL`, built in two
  separate flat segments split at `WATERFALL_X` — the low "valley" stretch
  and the higher "source" stretch coming down out of the mountains.

### The waterfall

Bridges the two flat river segments at `TerrainHeight.WATERFALL_X`. This
took three attempts to get right, and the failure modes are worth knowing
if you touch this code:

1. **A single flat quad at exactly `WATERFALL_X`** — invisible. The
   terrain's own carved bed also steps up sharply at that x, and the quad
   ended up geometrically behind that opaque cliff face from the valley
   side.
2. **A crossed pair of quads** (to be visible from more angles) — fixed the
   occlusion, but a flat, disconnected shape has no relationship to the
   water on either side of it. From most angles — especially the top-down
   views flight makes routine — it read as a stray floating shard, not
   falling water.
3. **An eased (smoothstep) ribbon rising over a wide x-span** — connected
   to both sides, but the ease curve rises slower than the terrain's own
   (linear) ramp partway through the transition, so the ribbon dipped
   below the actual ground and got buried again.

The fix that stuck: `TerrainHeight.WATERFALL_X` (80) lands exactly on a
terrain grid vertex (grid spacing is `terrain_generator.gd`'s
`CELL_SIZE`, 200/100 = 2), so the terrain's *rendered* surface between the
low-bed vertex and the high-bed vertex isn't a hard step at all — it's the
one straight line connecting those two vertices. `_build_waterfall()`
matches that exactly: a **linear** (not eased) rise over the same x-span
(`WATERFALL_RISE_WIDTH`, matching `CELL_SIZE`), offset above it by the same
`RIVER_BED_DEPTH` every other stretch of water sits above its bed. Parallel
lines, offset by a constant — the ribbon can't dip below the ground it's
tracking, and it's built as one continuous strip connected to both the
upstream and downstream flat ribbons, so it reads as the same river instead
of a separate object.

## `biome_populator.gd` — trees and bushes

Scatters `tree_count` trees and `bush_count` bushes (from Kenney's Nature
Kit) via rejection sampling: pick a random `(x, z)` within
`play_area_half_size`, skip it if it's inside `safe_zone_radius` of the
origin (keeps the spawn point/training dummy clear) or if
`TerrainHeight.is_water(x, z)`, otherwise place it at
`TerrainHeight.get_height(x, z)` with a random rotation/scale. Fixed
`rng_seed` so the layout is stable across runs. `play_area_half_size` (90)
extends slightly past `MOUNTAIN_START_RADIUS` (65), so the outer ring of
scattered vegetation sits on lower mountain slopes rather than stopping
exactly at the valley floor.

## `fish.gd` / `fish_spawner.gd` — ambient fish

Purely decorative, not interactable. `fish_spawner.gd` places a few fish
per pond and a few points along the river; each `fish.gd` instance wanders
within a circular area (`center`/`radius`), picking a new random point to
swim toward whenever it gets within 0.3 units of its current target, and
loops whatever animation its model has (`Swim`).

### FBX unit gotcha

The fish models are FBX, and Godot's FBX importer bakes in a ~100x unit
conversion (cm → m). An AABB measurement that doesn't compose transforms
through the full Armature/Skeleton3D chain will report a size roughly 100x
too small, suggesting a much larger scale factor is needed than actually
is — this cost real debugging time once (`FISH_SCALE = 0.03` looks wrong
at a glance for what should be a small ambient fish, but is correct once
the baked-in FBX scale is accounted for). If a new FBX-sourced model looks
wildly wrong-sized, check `global_transform` at runtime rather than trusting
a naive local-space AABB measurement.
