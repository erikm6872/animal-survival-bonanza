# Architecture Overview

## Directory layout

```
scenes/
  player/     Ground player scene, flight player scene, the procedural bird model
  world/      The test world, training dummy
  ui/         Character select, pause menu, HUD, debug overlay
  debug/      Doesn't exist on main — created on demand for throwaway
              verification scenes, then deleted before committing (see
              "Debug harnesses" below)
scripts/
  core/       game_state.gd (the one cross-scene autoload with actual state)
  player/     animal_species.gd, the two movement controllers, the bird model
  combat/     Damageable, Hitbox, Stamina, training_dummy.gd
  world/      Terrain/water/biome/fish generation, the player spawner
  ui/         Scripts for the scenes under scenes/ui/
resources/
  species/    One .tres per playable animal (wolf, stag, sparrow)
assets/
  models/     Imported CC0 asset packs (Quaternius, Kenney) + ATTRIBUTION.md
docs/
  GDD.md      Design doc — what the game is and what's planned
  wiki/       This wiki — how the code is built
```

## Autoloads

Three singletons, declared in `project.godot`:

- **`GameState`** (`scripts/core/game_state.gd`) — the only autoload that
  actually carries state across scenes: `selected_species` (set by
  character select, read by the player spawner) and `is_winter` (set by the
  pause menu, read by the terrain generator via a signal). See
  [Species System](Species-System.md) and [World Generation](World-Generation.md).
- **`DebugOverlay`** (`scenes/ui/debug_overlay.tscn`) — the `F1`/`F3`
  panels. Self-contained; doesn't interact with `GameState`.
- **`PauseMenu`** (`scenes/ui/pause_menu.tscn`) — being an autoload (not
  part of the world scene) is what lets it survive the "Change Animal"
  scene change back to character select. See [UI and Menus](UI-And-Menus.md).

## Scene flow

```
character_select.tscn (project's main scene)
  │  pick a species card
  ▼
GameState.selected_species = <chosen AnimalSpecies>
  │  change_scene_to_file
  ▼
test_world.tscn
  │  PlayerSpawner._ready() (scripts/world/player_spawner.gd)
  │    reads GameState.selected_species
  │    instances species.player_scene (player.tscn or flying_player.tscn)
  ▼
The chosen controller's _ready() wires itself from the species resource:
  stats, animation clip names, hitbox offset, fur tint config, etc.
```

Nothing about the world scene hardcodes which species is playing — it asks
`GameState` once, at spawn time, and the resource it gets back is
self-describing. The pause menu's "Change Animal" option re-enters this
same flow by just sending the player back to character select
(`get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")`),
rather than having its own separate species-switching code path.

## Debug harnesses

Several features in this project's history were verified with a throwaway
scene + script under `scenes/debug/` / `scripts/debug/` — e.g. instancing
`test_world.tscn` headlessly, forcing a species, driving input actions
programmatically, and saving a `Camera3D`'s render to a PNG for visual
inspection. These directories don't exist in the repo at rest; they're
created for one verification pass and deleted again before the feature is
committed. If you find either directory present on `main`, that's leftover
work, not an intentional part of the game.

## Why some things are duplicated instead of shared

`player_controller.gd` and `flight_controller.gd` independently implement
component wiring, damage/death/respawn, and fur-color get/set — see
[Movement Controllers](Movement-Controllers.md) for the reasoning. The
short version: the two movement models (gravity + floor vs. no gravity +
full 3D) are different enough that a shared base class would mean branching
almost every line of `_physics_process`, and the working ground controller
was deliberately left alone rather than risked mid-refactor.
