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
- [x] Basic third-person character controller (capsule placeholder,
      WASD + mouse-look, sprint, jump) — `scripts/player/player_controller.gd`
- [x] Minimal test world (ground plane, sky, directional light) —
      `scenes/world/test_world.tscn`
- [ ] Combat system (attack, dodge, stamina, hit reactions)
- [ ] Hostile wildlife / AI
- [ ] Currency + progression systems
- [ ] Real animal model/animations (currently primitive placeholder)
- [ ] Open-world level design beyond the flat test plane

## Open questions for future sessions

- Exact stat set for the first animal (health/stamina/speed/damage
  baseline numbers).
- Biome theme for the first real level (forest, savanna, etc.).
- Specific free asset packs to adopt for the animal model and environment.
