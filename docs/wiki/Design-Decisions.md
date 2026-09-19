# Design Decisions

A running log of decisions that shaped the project — what was chosen, what
was rejected, and why. The other wiki pages document *how* the current
code works; this page exists for the decisions that don't leave an obvious
trace in the code itself, or where a past attempt failing is exactly why
the current approach looks the way it does.

Newest entries at the bottom. This page is meant to be added to, not
rewritten — when we make a significant decision, it gets a new entry here
rather than editing history.

## Foundation

- **Godot 4.7 (GDScript), MIT license, CC0/free asset packs.** Chosen to
  reach a playable prototype fast without any licensing risk — every asset
  pack used (Quaternius, Kenney) is CC0, and the license is set from
  before any code existed.
- **Single-player-first, multiplayer as an eventual goal.** Multiplayer
  wasn't scoped into v1 architecture; the movement/combat/species systems
  aren't networked and weren't designed around future networking
  constraints. This may need revisiting if/when multiplayer becomes active
  work.
- **Low-poly stylized art direction.** Picked for fast iteration, forgiving
  of imperfect animation, and because it's what the available CC0 packs
  actually look like — not a purely aesthetic choice in isolation.

## Movement and combat feel

- **Action/skill-based combat** (real-time dodge, attack, stamina
  management) over stat-check/auto-resolve combat. Timing and positioning
  are meant to matter more than raw stats.
- **Dodge is a full Dark-Souls-style end-over-end roll**, not a simple
  sidestep or blink — chosen specifically to make the 360° roll match
  rotating the character model as it dodges. Required a hop arc
  (`DODGE_HOP_HEIGHT`, see [Movement Controllers](Movement-Controllers.md))
  once the roll was found to clip the model through the ground; the arc was
  the fix, not a redesign of the dodge itself.
- **Pause menu instead of just releasing the mouse cursor on Esc.** The
  original placeholder behavior (Esc = free the mouse) was replaced early
  with a real Resume/Settings/Quit menu, on the reasoning that a bare
  cursor-release isn't a real pause and doesn't scale to holding settings.

## The species system

- **Data-driven `AnimalSpecies` resources instead of per-animal code
  branches.** Once a second playable animal (Stag) was planned, hardcoding
  its stats/animation names into the controller would have meant an
  `if species == "wolf"` branch for every future animal. A `.tres` resource
  per species, read generically by the controller, was chosen instead — see
  [Species System](Species-System.md).
- **No CC0 rigged bear model exists.** Extensively searched (Quaternius,
  poly.pizza, OpenGameArt, itch.io, Sketchfab) for a bear to fill the
  "tankier, slower" archetype slot. The one candidate found (Sketchfab,
  CC-BY) had known rigging problems and unconfirmed animation coverage.
  **Decision: use the Stag model instead**, same pack as the Wolf, same
  stat archetype (tankier/slower) — reuse over a shaky asset.
- **Two separate movement controllers (ground vs. flight), not one
  controller with branches.** When Sparrow (flight) was added, the
  no-gravity/full-3D movement model was different enough from
  gravity-plus-floor ground movement that branching a shared
  `_physics_process` would have touched almost every line of it.
  Duplicating component wiring (~100 lines) was accepted as the cheaper,
  lower-risk cost — see [Movement Controllers](Movement-Controllers.md).
- **No usable bird asset exists either, so the Sparrow model is built
  procedurally.** Quaternius's animal packs have no birds at all; their
  Monsters pack's only flying options are fantasy creatures (its "Pigeon"
  turned out to be a purple tentacled blob-monster, not a bird); the one
  real bird found (Sketchfab, CC-BY) was gated behind an account login,
  which is a hard no — this project doesn't create accounts or handle
  credentials on the user's behalf. **Decision: build the bird from
  primitive meshes with code-driven animation**, the same technique already
  used for terrain/water/fish, rather than keep searching or compromise on
  a wrong-looking asset. Eyes and legs were added afterward specifically
  because the first pass read as a "blob with wings," not a bird.
- **Flight got a landing/hopping state, not just flight.** Once flight
  existed, being permanently airborne read as incomplete for a bird.
  Landing reuses the ground controller's gravity/floor model rather than
  inventing a third movement mode — see
  [Movement Controllers](Movement-Controllers.md#landing-and-ground-hopping).

## World generation

- **Everything procedural, nothing hand-authored.** Terrain, mountains,
  river, waterfall, ponds, and vegetation placement are all generated at
  runtime from code, keyed off one shared height function
  (`TerrainHeight.get_height()`) — not because hand-authoring wouldn't look
  better, but because it keeps every system (collision, spawn points, tree
  placement, water) guaranteed to agree with each other. See
  [World Generation](World-Generation.md).
- **Mountains ring the map rather than the terrain just stopping at the
  edge.** Ridged noise ramped in by radial distance, kept out of the
  playable area entirely (`MOUNTAIN_START_RADIUS`), so it reads as "a
  valley" rather than a bounding-box cutoff.
- **The waterfall is a ribbon mesh matched exactly to the terrain's own
  grid, not a hand-placed effect.** Two earlier approaches (a flat quad, a
  crossed pair of quads) both went invisible or looked like a floating
  glitch — see [World Generation](World-Generation.md#the-waterfall) for
  the full failure history. The eventual fix mattered enough to be worth a
  decision-log entry on its own: **when a procedural piece of geometry has
  to meet another procedural piece of geometry, matching its actual math
  (not just eyeballing a similar shape) is what makes it hold together
  from every angle**, not just the angle it was screenshotted from.

## Quality of life

- **"Change Animal" reuses the character-select flow instead of a new
  in-world species switcher.** Requested specifically to stop needing a
  full app relaunch to try a different animal. Rather than build a second
  way to assign `GameState.selected_species`, the pause menu option just
  re-enters the same flow character select already provides.
- **Winter/summer is a terrain color palette swap, not a full alternate
  asset set.** Scoped deliberately small — it changes what
  `terrain_generator.gd` colors vertices, not tree models, particle
  effects, or lighting. If "real" seasons become a bigger feature later,
  this toggle is the seed of it, not the finished version.

## Documentation

- **A technical wiki, kept in two places on purpose.** `docs/wiki/` lives
  in the main repo (so it goes through the same PR review as the code it
  describes, and can't silently drift out of sync the way an
  entirely-separate wiki can) *and* is mirrored to the GitHub Wiki tab (for
  discoverability — GitHub's Wiki tab is a separate `.wiki.git` repository
  that files under `docs/` don't automatically appear in). Updating both
  copies is a manual step for now; if that friction turns out to matter,
  automating the mirror is the next move, not dropping one copy.
- **This page exists because implementation docs don't capture *why*.**
  The other wiki pages describe current behavior; several of them
  (Species System's bear/bird sections, World Generation's waterfall
  section) already needed to explain a rejected approach to make the
  current one make sense. This page is the general home for that kind of
  entry going forward, instead of every implementation page growing its
  own "why" tangents.
