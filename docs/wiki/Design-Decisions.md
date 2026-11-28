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
- **The Bald Eagle reuses a real CC0 model instead of going fully
  procedural like Sparrow, despite that model being incomplete.** A second
  search (prompted by wanting a second bird) turned up Quaternius's
  "Eagle.fbx" — CC0, rigged — in a different, older pack than the one
  originally searched for Sparrow, which is why it didn't turn up the first
  time. It only ships `Idle`/`Flying` animations, nothing for
  attack/death/hit-react/hop. Two real options existed: ignore it and build
  fully procedurally (guaranteed-complete animation set, more build time,
  no authentic-feather look), or a hybrid — use the real mesh for its
  idle/flying look, recolor its 4 generic-eagle surfaces into bald eagle
  markings, and code-generate the missing clips as whole-body
  rotation/position tracks on its root node (the same technique Sparrow's
  own procedural clips already use, just retargeted). Went with the
  hybrid: it's less new code than a from-scratch model, and a real mesh
  reads as more authentic than primitives. The accepted cost: no per-bone
  control means no folded-wing ground pose, so the Eagle keeps its flight
  silhouette while landed — a minor, deliberate gap, not an oversight. See
  [Species System](Species-System.md#when-the-models-animation-set-is-incomplete-the-bald-eagles-hybrid-approach).
- **The Bald Eagle's `model_scale` needed a real in-game screenshot to
  pick, not math.** A raw local-space AABB measurement on the imported mesh
  came back implausibly tiny (millimeter-scale numbers) — this is the same
  FBX/skinned-mesh AABB-composition gotcha already documented for the fish
  models (see
  [World Generation](World-Generation.md#fbx-unit-gotcha)), where an
  unposed/unskinned AABB measurement doesn't reflect the actual rendered
  size. Rather than guess a correction factor, `model_scale = 1.0` (i.e.
  no correction) was tried first and simply looked right once actually
  spawned in the world — a reminder that this particular gotcha is better
  resolved by looking at the thing than by computing around it.
- **Chameleon is fully procedural, no real-model search needed first.**
  Unlike Sparrow and the Eagle, no search for a CC0 chameleon model was
  done before building one from primitives — the tongue-extend attack
  needs a custom animation no stock pack would ship regardless of species,
  so there was no scenario where a found model would have saved the
  procedural-animation work anyway. Built the same way as
  `simple_bird_model.gd`: primitive meshes, code-driven `Animation`
  resources, including a tongue built as a wrapper `Node3D` (rotated to
  point forward) containing an un-rotated `CylinderMesh` offset by half
  its height — needed because a `CylinderMesh`'s long axis is always
  local Y, which survives as the *scale* axis regardless of how the
  containing node is rotated, so animating the mesh's own `scale.z`
  directly would have stretched its radius, not its length.
- **The tongue attack's `Hitbox` is a fixed point at range, not something
  that tracks the animated tongue tip.** Every species' attack hitbox
  already works this way (a fixed `hitbox_offset`, active only during a
  timing window) — bite attacks just don't make the fixed-vs-animated
  distinction visible, since their reach is short enough that "close to
  the target" and "at the hitbox's exact offset" are nearly the same
  thing. The tongue's reach (~1.4 units) makes the gap obvious: standing
  right next to a target **misses**, because the hitbox sits at the
  tongue's full extension, not wherever the target happens to be. Caught
  by the same kind of deterministic distance test that found the Fox's
  original `attack_range`/hitbox-reach mismatch — confirmed the hit
  lands cleanly at the intended ~1.3-unit range, and misses at
  point-blank range, which is a real (if initially surprising) gameplay
  characteristic of a ranged tongue attack, not a bug.
- **Flies reuse Hitbox/Damageable wholesale instead of a new "edible"
  component.** A fly has a 1-HP `Damageable` under its own `Area3D` (not
  a `CharacterBody3D` — flies never need to physically collide with the
  player while wandering), so the exact same tongue attack that damages
  enemies also "eats" a fly in one hit. `Damageable.died(source)` already
  carries the attacker, so the fly's own script restores the attacker's
  stamina (`Stamina.restore()`, a new method — regen before this was
  purely passive/per-second) and frees itself. Zero new combat-system
  code, just a new thing for the existing system to apply to.
- **Chameleon movement is ground-only for this pass; climbing is
  deliberately deferred, not dropped.** Real chameleons climb, and it's
  the obvious next step for this species specifically, but it's a new
  movement domain the same size of effort flight was for Sparrow — out of
  scope for landing the base species. Reuses `player.tscn`/
  `player_controller.gd` as-is for now; see "Next steps" in
  `docs/GDD.md`.
- **The Tuna is photo-textured, not primitive-mesh geometry.** Stakeholder
  feedback ("the tuna doesn't look like a tuna," from an animal buff) asked
  for a real photo as the body texture. The reference photo supplied was
  watermarked Adobe Stock content — unusable in an MIT-licensed,
  redistributable repo — so a public-domain NOAA yellowfin photo was
  sourced instead (see `assets/textures/ATTRIBUTION.md`). The photo's
  alpha silhouette provides the snout, fins, finlets, and forked tail for
  free, so there's no hand-built fin geometry at all.
- **The Tuna's volume comes from inflated photo sheets plus an
  alpha-derived core, not a modeled body.** Flat mirrored cutout quads
  looked two-dimensional, so each flank is a subdivided sheet bulged
  outward by an elliptical thickness profile (flat in the fin regions,
  where the bulge fades to zero). The sheets never close across the
  centerline, which made the fish a hollow see-through lens from dead
  ahead/astern (the chase camera's angle) — filled by a dark interior
  solid whose per-slice center/depth are measured from the texture's own
  alpha channel at build time, so it follows the real silhouette and
  can't poke out through transparent texels the way a hand-guessed
  ellipsoid did. Two hard-won rules for this technique: both flanks must
  use **identical** (non-flipped) UVs — "mirroring" a flat side-profile
  photo just relocates head content to the tail end — and the flank
  material must keep default backface culling, since double-siding
  near-coincident sheets makes the far one bleed through the near one.

- **Character select got a `category` field and filter tabs, split along
  five groups rather than the three originally named (land mammals /
  undersea / dinosaurs).** Sorting the existing roster into exactly those
  three left Chameleon, Komodo Dragon (reptiles) and Sparrow, Bald Eagle,
  Pelican (birds) with no honest home — folding them into "Land Mammals"
  would make that label inaccurate for 5 of the game's then-9 species.
  Decision: keep all three requested groups and add Birds/Reptiles rather
  than mislabel. `category` (`AnimalSpecies.Category` enum) is deliberately
  a separate axis from `player_scene`/`start_scene` — it only drives which
  character-select tab a species appears under, nothing mechanical — see
  [Species System](Species-System.md#categories-vs-controllers-maps-two-independent-axes).
- **Velociraptor: the photo-cutout technique, extended to a two-legged
  pose.** The Tuna/Tiger Shark technique (inflated flank sheets + an
  alpha-derived interior core/rim) assumes a torpedo-shaped body with a
  single thickness profile centered on the image's vertical middle — true
  for a fish, not for a biped where the same photo column holds two
  unrelated masses (torso above, legs below) stacked in one contiguous
  alpha run. Applying the fish's single-profile formula as-is would
  inflate a leg's full hip-to-foot run into a torso-sized sausage.
  Decision: split every alpha scan into two independently-profiled bands
  by a fixed row cutoff (torso/neck/head/tail above it, legs below),
  each with its own measured center and depth per length-slice, combined
  via `max()` in the flank's thickness function — see
  `scripts/player/velociraptor_model.gd`. Accepted trade-off: both bands
  taper toward zero approaching their shared boundary, leaving a soft
  under-inflated "waist" right at hip height rather than a perfectly
  continuous body — a minor, visible-but-not-chased seam, in the same
  spirit as the fish scripts' own documented small gaps.
- **Velociraptor's source image was chosen for pose, not just license.**
  Several CC-licensed restorations were candidates; a dynamic
  mid-stride pose (Fred Wierum's, CC BY-SA 4.0) was passed over because
  its raised foot has a true background gap between the leg and the body
  in several image columns — the band-splitting technique above still
  depends on each column being one contiguous opaque run within its band.
  TotalDino's standing restoration (CC BY 4.0, `Velociraptor_TD.png`) was
  used instead specifically because both feet plant directly under the
  body with no gap, and it already shipped with a clean alpha channel
  (no hand-tracing needed, unlike the Tiger Shark's photo).
- **The Velociraptor's stakeholder-specified four-beat move — tackle to
  the ground, clamp, rip sideways — turned out to be a special move, not
  the everyday attack, once the regular attack was specified separately
  (a quick lunge with a grab).** Originally built as `anim_attack` itself;
  retargeted to a new `anim_pounce`/`_make_pounce_animation()` once the
  distinction came in, with a new, much shorter `_make_bite_animation()`
  taking over `anim_attack`. The elaborate version keeps its five value
  tracks (position x/y, rotation x/y/z) keyed through named phase markers
  (`t_crouch`, `t_impact`, `t_clamp`, `t_rip_end`) — "tackle down, then
  wrench the head sideways while jaws are clamped" doesn't reduce to a
  single forward poke the way the quick attack does. `pounce_hit_*_fraction`
  and `pounce_hitbox_offset` in `velociraptor_species.tres` are timed to
  the clamp+rip span specifically (not the tackle travel or recovery),
  since the hitbox is a static sphere relative to the character root (see
  `player_controller.gd` — it doesn't track the animated model's position).
- **The Pounce is a one-hit kill, gated behind 3 landed normal kills, built
  as the same pattern as the Chameleon's secret fly-devour mechanic** (see
  `can_devour_enemies`/`FLIES_NEEDED_TO_DEVOUR`) rather than a new bespoke
  system: `player_controller.gd` tracks `kills_since_pounce` unconditionally
  for every species (harmless/unused unless `can_pounce` is set, exactly
  like `flies_eaten`), charges it on a landed hit that actually kills (not
  just any hit), and only consumes the charge on an actual landed pounce —
  a pounce that misses keeps the charge banked, same as a missed tongue
  grab doesn't spend the Chameleon's fly count. "Guaranteed kill" is
  implemented as a damage number, not a new kill API: the Hitbox's
  `damage` and its transform/shape are swapped to pounce-specific values
  (`_use_pounce_hitbox()`) for the pounce's hit window and restored
  (`_use_normal_hitbox()`) when it ends or is interrupted, rather than
  adding an explicit instakill path to `Hitbox`/`Damageable`.
- **The regular attack reads as "reach out, then close in to grab" through
  whole-body motion only — there's no separate arm to actually animate.**
  The stakeholder asked for the arms to visibly close on the grab, but the
  source illustration (`Velociraptor_TD.png`) doesn't draw a forelimb at
  all (unlike some other candidate restorations considered for the model
  itself), and the model has no separate mesh piece for one regardless —
  same whole-body-rotation constraint as the running gait. The lunge-then-
  snap-back-in motion (`_make_bite_animation()`) is meant to evoke a grab
  through timing/body language rather than literal arm closure; adding a
  real articulated arm would mean sourcing new arm geometry/texture, which
  wasn't in scope for this pass.
- **A visible line between the open jaws, fixed as its own small Rim-like
  patch rather than a generalization of `_build_rim`.** The source photo's
  open mouth means several columns near the snout have two separate opaque
  runs (upper jaw, lower jaw) instead of one, which `_build_rim`'s
  topmost/bottommost-per-column trace correctly never bridges — but
  nothing sealed the gap's own *inner* boundary, the same hollow-lens
  problem `_build_rim` exists to solve for the body's outer silhouette, just
  recurring at the mouth cavity. Generalizing `_build_rim` to handle every
  multi-run column everywhere was rejected: the legs/toes area has columns
  with up to 6 runs (tooth-serration-style noise, individual toe/claw
  gaps), and sealing those would look like webbing that doesn't belong
  there. Instead, `_build_mouth_seal()` only scans a column range
  empirically bounded to the snout (`MOUTH_GAP_MAX_U`), seals just that
  gap's inner boundary, and leaves everything else untouched.
- **No existing dinosaur model, real or CC0, was found** (Sketchfab/
  poly.pizza/OpenGameArt/Quaternius all searched) — same situation as the
  Sparrow's missing bird model and the Tuna/shark's missing fish models,
  resolved the same way: build it from what the project already knows how
  to build (procedural photo cutout) rather than compromise on a
  wrong-looking or license-incompatible asset.

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
- **Ocean seafloor decor: shader-animated seaweed, MultiMesh coral,
  reused land rocks, no collision.** Rocks reuse the CC0 nature-kit
  models already shipped for the land map; seaweed and coral are
  procedural. The seaweed sway lives entirely in a vertex shader
  (`shaders/seaweed.gdshader`, phase keyed off world position so blades
  drift out of step) so hundreds of blades animate with zero per-frame
  script work — important for the Chromebook web build. Seaweed and coral
  are MultiMesh batches (one draw call per kind). Decor gets **no
  collision**: the swim controller's seafloor clearance already keeps the
  player just above the floor, and collision would snag the swim clamp
  rather than add anything. The ocean also hides a few fixed-position
  easter eggs — locations deliberately not documented here, since this
  wiki is public and spoiling them defeats the point. One technique note:
  objects "buried" in a slope must be aligned to the local floor normal
  and sunk along it, or the whole downhill face ends up exposed.
- **MultiMesh instance data can't be verified headlessly.** The dummy
  rendering server used by `--headless` doesn't retain MultiMesh buffers,
  so `get_instance_transform()` reads back zeros — placement checks that
  touch MultiMesh must run under the real renderer (`DISPLAY=:0`), the
  same way screenshot verification already does.
- **The spawn/respawn cave is built from plain primitive-cube collision,
  not the nature-kit's premade `cliff_blockCave_*` piece, and its entrance
  is a bare gap rather than that piece's carved hole.** The asset's hole
  axis isn't documented, and this environment has no reliable way to
  render and visually confirm which direction it opens (see the browser-
  preview `document.hidden` render-loop limitation already logged
  elsewhere in this file). Code can self-check a value against physics,
  but can't self-check "does this look right" — so the lower-fidelity,
  fully-deterministic option (an actual gap in the wall ring, collision
  and visual guaranteed identical by construction) was chosen over a
  fancier piece whose orientation would have been a guess. The surrounding
  hill is a ring-shaped bump in `TerrainHeight` (zero at both the inner and
  outer radius, so the terrain mesh stays continuous — no cliff/crack),
  not a separate mesh, keeping it consistent with every other terrain
  feature's "one shared height function" rule above.

## Hostile wildlife

- **A separate `EnemySpecies` resource, not a reuse of `AnimalSpecies`.**
  The two look almost identical (model, stats, animation names, combat
  timing), which made reuse tempting, but `AnimalSpecies.player_scene` has
  no default specifically because it exists for the character-select spawn
  flow — an enemy never goes through that flow. Forcing enemies into
  `AnimalSpecies` would mean every enemy resource sets a field that means
  nothing for it. A parallel, narrower type was simpler than teaching one
  resource to serve two purposes. See
  [Hostile Wildlife](Hostile-Wildlife.md).
- **Fox, reusing the same Quaternius pack Wolf and Stag came from**, rather
  than sourcing a new asset. Same reasoning as the Stag/bear decision above
  — the pack already has several more ground animals (Husky, Cow, Bull)
  with the same rig/animation-name conventions, so the first enemy cost an
  afternoon instead of another asset search.
- **Ground enemies are kept off the mountain terrain
  (`enemy_spawner.gd`'s `play_area_half_size` well inside
  `MOUNTAIN_START_RADIUS`), not a terrain-collision fix.** Verification
  caught a real bug: a ground creature spawned or teleported into the
  mountain ring can fall through the world, because the mountains' jagged
  ridged noise makes the *analytic* height diverge from what the terrain
  mesh's coarser collision grid actually resolves to. The fix scopes where
  ground creatures go, rather than making the terrain collision itself
  finer-grained near slopes — the cheaper fix for "one enemy type
  shouldn't fall through the world," not a fix for mountain traversal in
  general (which the player can still wander into and hasn't been
  addressed).
- **`attack_range` must be tuned against the `Hitbox`'s actual physical
  reach, not picked independently.** They're unrelated numbers in the code
  (one's an AI distance check, the other's a `hitbox_offset` + collision
  radius), and nothing enforces they agree — a mismatch there shipped once
  during initial testing (the AI correctly played its attack animation on
  schedule while never actually being close enough to land a hit). Caught
  by a test that checked whether player health actually dropped, not just
  whether the state machine reached the ATTACK state — a reminder that
  "the state machine did the right thing" and "the mechanic actually
  works" are different claims, and worth verifying separately.
- **The Tiger Shark is a playable species, not hostile wildlife.** It
  shipped once as an ocean enemy (its own `ocean_enemy_controller.gd`, a
  3D swim-chase AI state machine) before a correction: it was meant to
  join the Tuna as a second playable ocean animal all along. The enemy
  controller, its `EnemySpecies` resource, and the ocean enemy spawner
  were deleted outright rather than kept as unused infrastructure — see
  `resources/species/tiger_shark_species.tres` (an `AnimalSpecies`, not
  an `EnemySpecies`) and `scripts/player/tiger_shark_model.gd`, which
  reuses `swim_controller.gd` exactly like the Tuna.
- **The Tiger Shark is photo-textured with the exact same inflated-sheet
  + alpha-derived-core technique as the playable Tuna** (requested
  explicitly, rather than left as a judgment call) — see
  `scripts/player/tiger_shark_model.gd`, which differs from
  `tuna_model.gd` only in its proportions and source photo, not its
  approach.
- **The shark's source photo needed a hand-traced cutout, not an
  automatic one.** Unlike the Tuna's photo (already published with an
  alpha channel by a Commons contributor), the only suitable public-domain
  tiger shark photo found (same NOAA/SEFSC Pascagoula collection, see
  `assets/textures/ATTRIBUTION.md`) was a flat, un-extracted shot of a
  shark lying on a boat deck. Two automatic approaches were tried and
  both failed the same way: a neighbor-to-neighbor flood fill leaked
  through the silhouette because parts of the shark's grey flank are
  genuinely close in color to the blue-grey deck, and an edge-detection
  "wall" flood fill failed because the photo's JPEG/sensor noise produced
  edge-strength speckle comparable to the real outline once blurred enough
  to suppress false edges. The outline was traced by hand instead — as a
  polygon, refined by overlaying it on the source photo and checking
  specific regions against raw pixel brightness samples rather than eyeballing
  alone — then supersampled 2x before downscaling, for anti-aliased edges
  without needing a smarter segmentation algorithm.
- **Both fish models (Tuna and Tiger Shark) needed a third mesh piece --
  a "Rim" -- beyond the flank sheets and the interior Core.** The flank
  sheets are full rectangles clipped to the photo's silhouette by
  alpha-scissor in the shader, not by real mesh edges, so wherever the
  opaque silhouette (fin tips, snout, tail) runs close to the sheet's
  own dorsal/ventral border, there's nothing but open air between the
  two flanks there. The Core (added earlier to fix the hollow-lens look
  from dead ahead/astern) doesn't reach those spots either -- it
  deliberately stays narrower than the silhouette and stops short of the
  tail fork. Reported as "the texture doesn't connect on the edges, so
  from certain angles the inside is visible," which is exactly that gap
  seen nearly edge-on along the back, belly, or a fin. Fixed by tracing
  the silhouette's true top and bottom boundary from the same per-column
  alpha scan the Core uses (the real extremes this time, not a shrunken
  approximation) and stitching a thin strip connecting the two flanks
  along it, closed off at the nose and tail tip -- sealing the entire
  perimeter the Core was never meant to reach. Verified with rendered
  screenshots from the angles that actually exposed the bug (top-down,
  bottom-up, shallow grazing angles along the fin edges), not just the
  square-on angles used to verify the Core.
- **The first Rim fix (above) still left a gap, reported again against
  the shark.** Root cause: the Rim's top/bottom boundary was sampled at
  only `LENGTH_SEGMENTS + 1` (33) points along the body, reusing the same
  coarse spacing as the body mesh's own low-poly grid. The flank sheets'
  silhouette is alpha-scissored per-pixel at full texture resolution, so
  a feature narrower than one grid cell -- a fin's leading or trailing
  edge rising steeply -- could sit entirely between two Rim samples; the
  straight line connecting those samples cut inside the real silhouette
  there, and the actual edge poked out past it, reopening the gap. Fixed
  by sampling the Rim once per image column (1200 points for the shark)
  instead of once per body segment -- decoupling the Rim's resolution
  from the body mesh's polygon budget, since it's a thin strip and cheap
  to build at that density regardless of how coarse the body grid is.
  Confirmed by re-rendering the same grazing angles with the Rim colored
  solid magenta to make any remaining seam unmistakable, plus an ambient
  fill light added to the debug rig after an apparent gap turned out to
  be unlit backface shading from a single hard directional light, not a
  real hole -- a reminder to check pixel color (black vs. the actual
  background color) before concluding a dark patch is missing geometry.

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

## Deployment (Chromebook install)

- **Web export, not Android APK, as the actual delivery target** — despite
  Android being the initially chosen/built path. The Chromebook's Play
  Store support made Android sideloading look viable (no Crostini needed),
  and a signed debug APK was built and verified successfully. But the
  device turned out to be under Google Family Link (parental controls),
  which hard-blocks installing apps from outside the Play Store for
  supervised accounts — not a setting a parent can toggle, a built-in
  safety restriction of account supervision. Rather than remove Family
  Link supervision (a bigger decision than this feature warrants) or give
  up, pivoted to a Godot Web (HTML5/WASM) export: it runs as a page in
  Chrome, so it needs no app-install permission at all and sidesteps the
  restriction entirely. The Android export toolchain/pipeline was kept
  rather than torn out — it cost nothing extra to keep rebuilding both
  targets, in case Family Link ever stops applying or the restriction
  turns out to be liftable after all.
- **Self-signed HTTPS, not plain HTTP, for the local download server.**
  Godot's web export refuses to initialize outside a "secure context"
  (HTTPS, or the special-cased `localhost`) — a browser requirement, not a
  Godot one, and a `http://<lan-ip>` URL doesn't qualify no matter how
  private the network is. A self-signed cert satisfies the API requirement
  even though Chrome still shows a "not private" warning the user has to
  click through once per device — the warning is about certificate trust,
  which is a separate concern from the encrypted-transport requirement the
  secure-context check actually cares about.
- **GitHub Pages replaced the local self-signed HTTPS server as the actual
  install mechanism**, once it was clear the project was already public
  (open-source, MIT-licensed) anyway — the "local network only" constraint
  from the original ask no longer bought anything real. A GitHub Actions
  workflow (`.github/workflows/deploy-web.yml`) exports the Web build and
  deploys it to Pages on every push to `main`, using the
  `barichello/godot-ci` Docker image (pinned to `4.7.2`, matching the local
  Godot version) rather than hand-installing export templates in CI.
  Upside beyond not babysitting a systemd service on a dev machine: Pages
  gets real (non-self-signed) HTTPS for free, so the Chromebook no longer
  needs the one-time "not private" click-through. `export_presets.cfg` had
  to come out of `.gitignore` (it was in Godot's default template) so CI
  uses the same export settings as local builds — checked first for
  anything local-machine-specific (keystore paths, absolute paths); it had
  none.

## Web build cache-busting

- **Commit-SHA-versioned build filenames + a tiny fetch-based bootstrap
  page, not cache-control headers.** GitHub Pages gives no way to set
  custom HTTP response headers, so there's no server-side lever to force
  browsers to re-fetch a changed build (the actual problem reported: a
  Chromebook kept loading an old cached build after a deploy, with no easy
  way to force a refresh). The deploy workflow now renames every exported
  file (`index.html`/`.js`/`.wasm`/`.pck`/etc.) to `game-<short sha>.*`, so
  each deploy's real game files live at URLs that have never been
  requested before and can't collide with anything a browser has cached
  from a previous deploy. `web/index.html` (hand-written, checked into the
  repo, copied over the export's own `index.html` by the workflow) is the
  one thing still served at the stable root URL — it barely ever changes,
  so a browser caching *that* is harmless, and all it does is
  `fetch('manifest.json', { cache: 'no-store' })` to learn the current
  build's actual filename before redirecting there. `cache: 'no-store'`
  forces a real network round-trip (and, per HTTP spec, forces any
  compliant CDN cache to revalidate with the origin) every time, which is
  the only remaining lever once response headers aren't an option.

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
