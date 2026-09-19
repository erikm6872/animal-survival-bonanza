# Animal Survival Bonanza — Technical Wiki

This is architectural documentation for how the game is actually built —
who owns what, why things are split the way they are, and the gotchas that
weren't obvious the first time around. For *what* the game is trying to be
and what's planned next, see [docs/GDD.md](../GDD.md); this wiki is about
*how the current code works*.

## Pages

- **[Architecture Overview](Architecture-Overview.md)** — scene flow,
  autoloads, and the project's directory layout. Start here.
- **[Species System](Species-System.md)** — `AnimalSpecies`, the
  data-driven resource that lets a new playable animal be a `.tres` file
  instead of a code change.
- **[Movement Controllers](Movement-Controllers.md)** — the ground
  (`player_controller.gd`) and flight (`flight_controller.gd`) controllers,
  why they're separate scripts, and the landing/hopping state machine.
- **[Combat System](Combat-System.md)** — `Damageable`, `Hitbox`, `Stamina`:
  the reusable components behind health, melee attacks, and dodge i-frames.
- **[World Generation](World-Generation.md)** — procedural terrain,
  mountains, the river/waterfall/ponds, and biome scattering, all built at
  runtime from one source-of-truth height function.
- **[UI and Menus](UI-And-Menus.md)** — character select, the pause menu,
  HUD, debug overlay, and the `GameState` autoload that ties scenes together.
- **[Design Decisions](Design-Decisions.md)** — a running log of *why*,
  covering choices the other pages don't have room to explain and the
  rejected approaches that shaped the current ones. Updated whenever we
  make a significant decision, not just when a page gets a rewrite.

## Conventions worth knowing up front

- **Models face +Z; the game is -Z-forward.** Every imported model gets a
  `Transform3D` with negative X/Z scale applied to flip it, and movement
  math uses `atan2(-dir.x, -dir.z)` accordingly. See
  [Movement Controllers](Movement-Controllers.md).
- **No `preload()` defaults on `species`/`player_scene` fields.** These
  fields sit right at the bottom of a dependency cycle
  (`AnimalSpecies` → a controller scene → a species `.tres` → `AnimalSpecies`
  again) — a `preload()` default would make that cycle compile-time instead
  of runtime. Every species resource sets `player_scene` explicitly, and
  every controller falls back to `load()` (not `preload()`) inside
  `_ready()`. See [Species System](Species-System.md).
- **One height function, queried everywhere.** `TerrainHeight.get_height()`
  is the only place ground height is computed — the terrain mesh, its
  collision, spawn points, tree placement, and the river/waterfall/pond
  beds all call it instead of maintaining their own copy. See
  [World Generation](World-Generation.md).
- **Vertex colors are linear; `albedo_color` is sRGB.** Anything writing
  directly into a mesh's `ARRAY_COLOR` needs `.srgb_to_linear()` first, or
  colors render far paler than the numbers suggest. Bit us once already in
  `terrain_generator.gd`.
