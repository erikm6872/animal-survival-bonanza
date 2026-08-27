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
      `scenes/world/test_world.tscn`
- [x] Wolf model (Quaternius, CC0) swapped in as the v1 playable animal —
      `assets/models/Wolf.gltf`, wired into `scenes/player/player.tscn`
- [x] Kenney Nature Kit (CC0) imported for future environment art —
      `assets/models/nature-kit/` (329 props: trees, rocks, fences, paths,
      etc.), not yet placed in any level
- [x] Idle/Walk animations wired to movement state
      (`player_controller.gd` plays "Walk" while moving, "Idle" at rest)
- [ ] Combat system (attack, dodge, stamina, hit reactions)
- [ ] Hostile wildlife / AI
- [ ] Currency + progression systems
- [ ] Open-world level design beyond the flat test plane (nature-kit props
      unused so far)

## Next steps

Roughly in the order they unblock each other:

1. **Sprint/Gallop animation.** `sprint` input and `sprint_speed` already
   exist in `player_controller.gd`, but sprinting still plays the Walk
   animation. Wire the pack's `Gallop` clip in the same way Idle/Walk were
   wired.
2. **Build a real level from the Nature Kit.** `test_world.tscn` is still a
   flat plane. Use `assets/models/nature-kit/*.glb` to build the first
   biome (terrain variation, trees, rocks, paths) — this is a prerequisite
   for "open-world exploration" actually meaning something.
3. **Combat system.** The Wolf pack already has `Attack`, `Idle_HitReact1`,
   `Idle_HitReact2`, and `Death` animations ready to use. Needs: an attack
   input action → animation → hit detection (hitbox/area or raycast)
   → damage application, plus a health/stamina resource on the player.
   `dodge` input action already exists in `project.godot` but has no
   behavior yet.
4. **Hostile wildlife / AI.** Needs at least one enemy type with basic
   state-machine behavior (idle/patrol → chase → attack) to give combat
   something to hit. Could reuse another animal from the same Quaternius
   pack (Fox, Husky, etc. — same rig/animation set) as a first enemy.
5. **Currency + progression.** No systems exist yet. Needs a currency
   resource, a source (kills/exploration per the GDD), and at least one
   spend sink (cosmetic or stat upgrade) to close the loop.

## Open questions for future sessions

- Exact stat set for the first animal (health/stamina/speed/damage
  baseline numbers).
- Biome theme for the first real level (forest, savanna, etc.) — the
  Nature Kit supports forest/rock/farm/beach-ish themes out of the box.
- Whether additional animals (for enemies or future playable species) come
  from the same Quaternius pack already partially downloaded, or a new
  source.
