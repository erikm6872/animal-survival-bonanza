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

- **v1 scope:** one fully-featured animal, polished — movement, combat,
  and progression all built around it before adding more species.
- Future species should feel mechanically distinct (not just reskins),
  but that's explicitly out of scope until v1's single animal is fun.
- Longer-term, "mechanically distinct" likely means different *movement
  domains* entirely (flight, swimming), not just different ground-based
  stats — see "Future ideas" below.

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
- [x] Minimal test world (ground plane, sky, directional light) —
      `scenes/world/test_world.tscn`, with a dozen Nature Kit trees
      scattered around spawn for visual context (not a real level yet)
- [x] Wolf model (Quaternius, CC0) swapped in as the v1 playable animal —
      `assets/models/Wolf.gltf`, wired into `scenes/player/player.tscn`
- [x] Kenney Nature Kit (CC0) imported for future environment art —
      `assets/models/nature-kit/` (329 props: trees, rocks, fences, paths,
      etc.), only the trees are placed so far
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
- [ ] Stamina
- [ ] Dodge
- [ ] Hostile wildlife / AI
- [ ] Currency + progression systems
- [ ] Open-world level design beyond scattered trees on a flat plane

## Next steps

Roughly in the order they unblock each other:

1. **Stamina.** Sprint/attack/dodge should consume stamina and regen over
   time, per the GDD's combat pillar. No resource for this exists yet —
   needs the same treatment as health (a value + a UI element).
2. **Dodge.** `dodge` input action exists in `project.godot` but has no
   behavior — no dedicated dodge animation in the pack, so likely a quick
   movement burst + brief i-frames rather than an animation swap.
3. **Hostile wildlife / AI.** Needs at least one enemy type with basic
   state-machine behavior (idle/patrol → chase → attack) so combat has
   something to actually fight back. The training dummy proved hit
   detection works but doesn't hit back. Could reuse another animal from
   the same Quaternius pack (Fox, Husky, etc. — same rig/animation set,
   including `Idle_HitReact*`/`Death`) as the first enemy, giving it a
   Damageable + its own Hitbox.
4. **Build a real level from the Nature Kit.** `test_world.tscn` is still
   a flat plane with a handful of decorative trees. Use the other 300+
   `assets/models/nature-kit/*.glb` props (rocks, cliffs, paths, water) to
   build the first real biome with terrain variation.
5. **Currency + progression.** No systems exist yet. Needs a currency
   resource, a source (kills/exploration per the GDD), and at least one
   spend sink (cosmetic or stat upgrade) to close the loop.

## Future ideas (post-v1, from co-creator brainstorming)

Not scoped or scheduled — captured here so they aren't lost before v1
(single grounded animal, single biome) is even done:

- **Birds as a playable animal type.** Flight is a fundamentally different
  movement model from the current ground-based CharacterBody3D controller
  (3D freedom of movement, no "floor," different camera needs, likely
  different stamina rules for sustained flight/gliding vs. flapping).
  Not a reskin of the Wolf controller — needs its own movement script.
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
