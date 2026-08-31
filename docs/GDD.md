# Animal Survival Bonanza — Game Design Document (v0.1)

## Vision

An open-source, microtransaction-free 3D animal survival game. Players
choose an animal and explore an open world, combining exploration and
action-combat to survive, grow stronger, and earn currency purely through
play. Multiplayer is a long-term goal, not a v1 requirement.

## Core pillars

- **Open source, no monetization.** MIT-licensed, no paid currency or loot
  boxes ever. Currency is earned in-game only.
- **Open-world exploration + combat.** Not a pure life-sim, not a pure
  arena game — a explorable biome where combat, hunting, and traversal all
  matter.
- **Single-player first, multiplayer-ready later.** Core systems should
  avoid assumptions that would make later networking painful (e.g. keep
  gameplay state separate from input/rendering), but no netcode work
  happens until the single-player loop is fun.

## Gameplay loop (v1 target)

1. Player spawns as their chosen animal in an open-world biome.
2. Explore the world, discover points of interest, encounter wildlife.
3. Engage in real-time, skill-based combat (dodge/attack/stamina) against
   hostile animals or rival predators.
5. Earn in-game currency from kills, exploration, and objectives.
6. Spend currency on cosmetic unlocks (fur patterns, accessories) and
   ability/stat upgrades (speed, health, damage, stamina).

## Animal roster

- Three playable animals now, chosen from a character select screen at
  launch: **Wolf** (100 HP, 15 damage, 5/9 walk/sprint), **Stag** (150
  HP, 25 damage, 4/7 walk/sprint) — a tankier-but-slower archetype, same
  stat shape originally scoped for a bear. No CC0 rigged bear was found
  (see `docs/GDD.md` history / commit `4dd5420` for the search); the Stag
  reuses the same Quaternius pack as the Wolf instead — and **Sparrow**
  (60 HP, 10 damage, 8/16 cruise/fast), the first flying species (see
  "Flight" below).
- Species are data-driven (`scripts/player/animal_species.gd`,
  `resources/species/*.tres`) — model, stats, animation clip names, fur
  tint config, and hitbox timing all live in the resource, not in
  `player_controller.gd`. Adding a species is a new `.tres` file, not a
  code change (as long as the model has a comparable animation set).
  A species now also names its own player scene (`player_scene`, ground
  vs. flight controller) via `scripts/world/player_spawner.gd`, which
  instances whichever one the chosen species points to at spawn time
  instead of the level embedding a fixed player scene.

## Flight

- `scripts/player/flight_controller.gd` is a separate controller from
  `player_controller.gd`, not a branch inside it — full 3D movement (no
  gravity, no floor, pitch+yaw via `Basis.looking_at`/`slerp` instead of
  yaw-only `lerp_angle`) is different enough that forcing it into the
  ground controller would mean branching almost every line of
  `_physics_process`. Shares the same component wiring (Damageable,
  Stamina, Hitbox, HUD, camera rig) and the `AnimalSpecies` schema, so
  species resources and the pause menu's mouse-sensitivity/fur-color
  calls work identically regardless of which controller is spawned.
  `_clamp_above_ground()` is the only real "floor" — a minimum clearance
  above `TerrainHeight` so the bird can't fly underground.
- No CC0 or commercial-use-safe rigged/animated bird asset could be
  found — Quaternius's animal packs (Ultimate Animated Animals, Farm
  Animal Pack) have no birds at all, and their Monsters pack's only
  flying options are fantasy creatures (its "Pigeon" is a purple
  tentacled blob-monster, not a bird). The best real bird found was
  CC-BY on Sketchfab but downloads are gated behind an account login.
  So the Sparrow model is built procedurally
  (`scripts/player/simple_bird_model.gd`) from primitive meshes
  (capsule body, sphere head, cone beak, prism tail, two swept-back box
  wings) with code-driven wing-flap animation (`AnimationPlayer`
  built at runtime, value tracks on the wing pivots' `rotation:z`) —
  the same approach already used for the terrain/water/fish, rather than
  an imported model. Reuses the same `AnimalSpecies.anim_*` field names
  as the imported species (`Flying_Idle`, `Fast_Flying`, `Headbutt`,
  `Death`, `HitReact`) so nothing else in the species system needed to
  change. Fur tinting is unsupported for this species (`fur_mesh_path`
  left empty) since it has no single tintable surface the way Wolf/Stag
  do.
- Landing — `Space` toggles between flying and landed, but only when
  within `LAND_MAX_HEIGHT` of the ground (no landing from high altitude).
  Landed switches to real gravity + `is_on_floor()`/`move_and_slide()`
  floor collision (like the ground species) instead of the no-gravity
  hover model, flattens movement input to the horizontal plane so
  looking up/down doesn't tilt the hop direction, and plays
  `anim_ground_idle`/`anim_hop` (`Ground_Idle`/`Hop` for the Sparrow —
  wings folded, no flap) instead of the flying idle/gallop clips.
  `_level_model_orientation()` snaps any dive pitch back to level the
  moment it lands, since `_face_direction`'s slerp would otherwise only
  correct it gradually (and not at all while standing still). Pressing
  `Space` again gives an upward `TAKEOFF_VELOCITY` burst and resumes
  normal flight physics.
- Future species should still feel mechanically distinct beyond stats
  where it makes sense — see "Future ideas" below for the bigger swings
  (flight, swimming) that are a different scope entirely from what the
  current data-driven system supports (it only varies stats/animations
  on the same ground-based CharacterBody3D movement model).

## Combat

- Action/skill-based: real-time dodge, attack, and stamina management.
  Timing and positioning matter more than stat checks or auto-resolve.
- Placeholder v1 input: Left Mouse = attack, planned dodge key bound to
  `dodge` action (see `project.godot` input map).

## Currency & progression

- Two spending tracks:
  - **Cosmetic unlocks** — no gameplay power, visual only.
  - **Ability/stat upgrades** — speed, health, bite damage, stamina, etc.
- No premium currency, no real-money purchases anywhere in the design.

## Art direction

- Low-poly stylized. Chosen for fast iteration, forgiving of imperfect
  animation, and compatible with free/CC0 asset packs for prototyping.
- v1 asset strategy: use free/CC0 low-poly asset packs (e.g. Kenney,
  Quaternius-style) to reach a playable prototype fast; revisit custom art
  once the core loop is validated.

## Platform

- v1 target: Desktop (Windows/Linux/Mac) via native Godot export.
- Web export is a possible future target but not a v1 constraint.

## Multiplayer (future)

- Not built in v1. When pursued, expect to introduce client/server
  authority for movement and combat — current single-player code should
  be refactored at that point, not preemptively over-engineered now.

## Tech

- **Engine:** Godot 4.7 (GDScript). Chosen over Unreal/Unity for a fully
  open, royalty-free stack with no licensing friction for an open-source
  project.
- **License:** MIT.

## Current implementation status (v0.1)

- [x] Project scaffold, folder structure, license, README
- [x] Basic third-person character controller (WASD + mouse-look, sprint,
      jump) — `scripts/player/player_controller.gd`
- [x] Three playable animals via a data-driven species system — see "Animal
      roster" above. Character select (`scenes/ui/character_select.tscn`)
      is now the game's main scene.
- [x] Flight (Sparrow) — see "Flight" above. Full 3D movement, its own
      controller, a procedurally-built bird model since no usable bird
      asset could be sourced.
- [x] Kenney Nature Kit (CC0) imported for environment art —
      `assets/models/nature-kit/` (329 props: trees, rocks, fences, paths,
      etc.), trees/bushes now used by the biome (below); rocks/cliffs/paths
      still unused
- [x] Procedural rolling-hills terrain — `scripts/world/terrain_height.gd`
      (layered FastNoiseLite, the single source of truth for ground height
      at any x/z), `scripts/world/terrain_generator.gd` (builds the mesh +
      matching `HeightMapShape3D` collision at runtime), replacing the old
      flat plane. `scripts/world/biome_populator.gd` scatters 220 trees and
      100 bushes across it (fixed RNG seed, height-sampled so nothing floats
      or sinks), skipping any spot inside the river/ponds.
- [x] Mountains surrounding the map — `TerrainHeight._mountain_height()`
      ramps ridged noise in by radial distance from the map center, only
      past `MOUNTAIN_START_RADIUS` (65), so the playable area (trees scatter
      out to radius 90) stays untouched and just the outer ring rises into
      jagged peaks up to `MOUNTAIN_MAX_HEIGHT` (45). `terrain_generator.gd`
      colors the mesh by height (vertex colors: grass → rock → snow) so it
      reads as real mountains instead of giant green hills.
- [x] River + two ponds + a waterfall — `TerrainHeight` carves basins that
      blend smoothly back up to the hill height at each bank (no cliffs),
      and `scripts/world/water_generator.gd` builds matching visible water
      (a procedural ribbon mesh for the river's meander, a disk per pond) at
      the same level the terrain carves toward. Past `WATERFALL_X` (80,
      inside the mountain ring) the river is a second, higher-elevation
      ribbon — a separate flat "source" stretch coming down out of the
      mountains — with a steep sloped ribbon bridging the two flat levels
      (same ribbon construction as the river itself, just over a short,
      finely-subdivided span): the waterfall. `_carve_water()` picks
      whichever water level applies based on x, so the actual terrain (and
      its collision) has a real gorge/cliff there, not just a floating
      visual seam. Three broken attempts before landing on this: a single
      flat quad placed exactly at `WATERFALL_X` ended up behind the
      terrain's own carved cliff face from the valley side (invisible); a
      crossed pair of quads fixed that but, having no connection to the
      surrounding water, read as a stray floating shard from most angles
      instead of falling water; and an eased (smoothstep) rise across a
      wide span dipped below the terrain's own ramp partway through and got
      buried again. `WATERFALL_X` lands exactly on a terrain grid vertex
      (`WATERFALL_RISE_WIDTH` matches `terrain_generator.gd`'s `CELL_SIZE`),
      so the terrain's rendered surface between the low and high beds is
      just the one straight line connecting those two vertices — matching
      that with a **linear** (not eased) rise, offset by the same
      `RIVER_BED_DEPTH` every other stretch of water sits above its bed,
      keeps the ribbon parallel to and above the ground the whole way, the
      same relationship the flat river/pond water already has to its bed.
      Visual/terrain only — no
      swimming mechanics or water collision yet, so the player can
      currently walk down into a basin and end up under the water plane
      (harmless-looking since the water material is double-sided, but not
      "real" water).
- [x] Ambient fish — `scripts/world/fish.gd` (wander within a circular area,
      loop the Swim animation), `scripts/world/fish_spawner.gd` (5 per pond,
      5x3 along the river). Three species from Quaternius's Animated Fish
      Pack (CC0, FBX) in `assets/models/fish/`. Decorative only — not
      huntable/interactable yet.
- [x] Idle/Walk/Gallop animations wired to movement state (walk vs. sprint)
- [x] Attack animation wired to the `attack` input (left mouse) — plays
      once, blocks movement animations until it finishes
- [x] Melee hit detection — `scripts/combat/hitbox.gd` (Area3D, active
      during the Attack clip's bite-lunge window) and
      `scripts/combat/damageable.gd` (health + `take_damage()`, reusable
      component). Player has a Damageable so it's hittable once enemies
      exist. A respawning training dummy with a floating HP label
      (`scenes/world/training_dummy.tscn`) verifies it works.
- [x] Camera distance cycling (`C` key) — far/mid/close, smoothly lerped
- [x] Debug overlay (`F3`) and key bindings reference (`F1`), stacked
      top-right — `scripts/ui/debug_overlay.gd`
- [x] Player health — HUD bar (`scripts/ui/player_hud.gd`), hit-react
      animations (`Idle_HitReact1/2`, picked at random) on damage, `Death`
      on zero HP, respawn a few seconds later. Debug-only `K` key to
      damage self for testing, since nothing deals damage back yet.
- [x] Stamina — `scripts/combat/stamina.gd`, regens after a short delay,
      an "exhausted" state (must recover above 25% before spending again)
      to avoid flicker at empty. Sprint drains it continuously and falls
      back to walk speed when exhausted; attack costs a flat amount and
      is refused without enough. Bar added under health in the HUD.
- [x] Dodge — Ctrl, a `DODGE_SPEED` burst in the direction of current
      movement input (or backward if none held) for `DODGE_DURATION`,
      granting `Damageable.is_invulnerable` for the same window. No
      dedicated dodge clip in the pack, so it reuses Gallop visually.
      Costs stamina like attack; mutually exclusive with attack/hit-react.
- [x] Pause menu (`Esc`) — Resume/Settings/Change Animal/Quit, autoloaded
      (`scripts/ui/pause_menu.gd`), pauses via `get_tree().paused`. Change
      Animal reuses the character-select flow (`change_scene_to_file` back
      to `character_select.tscn`, which already does the "pick a species,
      load test_world.tscn" flow on its own) so switching species no longer
      means closing and relaunching the app. Settings: mouse sensitivity,
      fullscreen toggle, a Winter toggle (swaps the terrain's vertex-color
      palette between grass/summer and snow/winter via
      `GameState.season_changed` — geometry is unchanged, only
      `terrain_generator.gd`'s re-coloring), and a fur color picker
      (plain-color tint on the active species' fur surfaces, per
      `AnimalSpecies.fur_surfaces`; real fur textures are future work).
      No persistence across restarts yet.
- [ ] Hostile wildlife / AI
- [ ] Currency + progression systems
- [ ] Player hunger/thirst mechanics
- [ ] Swimming / water collision (river and ponds are visual-only so far)

## Next steps

Roughly in the order they unblock each other:

1. **Hostile wildlife / AI.** Needs at least one enemy type with basic
   state-machine behavior (idle/patrol → chase → attack) so combat has
   something to actually fight back. The training dummy proved hit
   detection works but doesn't hit back. Could reuse another animal from
   the same Quaternius pack (Fox, Husky, etc. — same rig/animation set,
   including `Idle_HitReact*`/`Death`) as the first enemy, giving it a
   Damageable + its own Hitbox.
2. **Player hunger/thirst mechanics.** Not scoped in detail yet — likely
   depleting resources restored by eating/drinking in the world, following
   the same pattern as health/stamina (a resource + HUD element). Ties
   into the survival pillar and gives the river/ponds and future foraging
   actual gameplay purpose beyond scenery.
3. **Swimming / water collision.** The river/ponds are visual-only —
   nothing stops the player walking down into a basin and ending up under
   the water plane. Needs at least a shallow-water slowdown or a real
   swim state; full swimming-as-a-movement-domain is bigger scope (see
   "Future ideas") but *some* water interaction is needed even for the
   ground-based Wolf now that water exists in the world.
4. **Currency + progression.** No systems exist yet. Needs a currency
   resource, a source (kills/exploration per the GDD), and at least one
   spend sink (cosmetic or stat upgrade) to close the loop.

## Future ideas (post-v1, from co-creator brainstorming)

Not scoped or scheduled — captured here so they aren't lost before v1
(single grounded animal, single biome) is even done:

- **Sea creatures as a playable animal type.** Swimming needs buoyancy,
  water drag/currents, breath/oxygen management if surfacing matters, and
  its own biome (ocean/water volumes don't exist in the project yet at
  all). Also a fundamentally different controller from both the ground
  and flight cases.
- **Specific fish request: Ocean sunfish (Mola mola).** Named as a
  wanted species for the sea-creature track. Distinctive body shape
  (large, flat, nearly tailless) — an existing rigged low-poly asset may
  not exist in the packs already in the project (Quaternius/Kenney), so
  this may need sourcing a new asset or a custom model when the time
  comes.
- Each new environment (air, water) implies its own physics rules and
  probably its own biome/level, not just a new model dropped into the
  current ground world — worth treating as a separate vertical slice
  rather than folding into the current single-biome roadmap above.

## Open questions for future sessions

- Exact stat set for the first animal (health/stamina/speed/damage
  baseline numbers).
- Biome theme for the first real level (forest, savanna, etc.) — the
  Nature Kit supports forest/rock/farm/beach-ish themes out of the box.
- Whether additional animals (for enemies or future playable species) come
  from the same Quaternius pack already partially downloaded, or a new
  source.
