# UI and Menus

## `GameState` (autoload) — the cross-scene glue

```gdscript
extends Node

var selected_species: AnimalSpecies = null

signal season_changed(is_winter: bool)
var is_winter: bool = false

func set_winter(value: bool) -> void
```

The only autoload holding real state. Being on an autoload (not the world
scene) is specifically what lets both fields survive a
`change_scene_to_file()` — `selected_species` needs to survive character
select → world, and `is_winter` needs to survive the "Change Animal" round
trip back through character select and into a freshly-instanced world
scene. `set_winter()` no-ops if the value isn't actually changing, so
`season_changed` only fires on a real flip.

## Character select (`scenes/ui/character_select.tscn`)

The project's `run/main_scene`. `character_select.gd` hardcodes a
`SPECIES_PATHS` list (currently Wolf, Stag, Sparrow), loads each
`AnimalSpecies` resource, and generates one button per species showing its
stats. Picking one sets `GameState.selected_species` and changes scene to
`test_world.tscn` — see [Species System](Species-System.md) for what
happens from there.

Adding a species to the roster (beyond authoring its `.tres`, per
[Species System](Species-System.md#adding-a-new-species-same-movement-type))
means adding its path to `SPECIES_PATHS` here.

## Pause menu (`scenes/ui/pause_menu.tscn`, autoload)

`Esc` toggles it (`_unhandled_input` checks `ui_cancel`); being paused sets
`get_tree().paused = true` and shows the mouse cursor. Two panels:

**Menu panel:** Resume / Settings / Change Animal / Quit.

- **Change Animal** unpauses and sends the player back to
  `character_select.tscn` — it deliberately doesn't have its own
  species-switching logic, just re-enters the same flow character select
  always uses. This is also why `PauseMenu` needs to be an autoload rather
  than living in the world scene: it has to survive the scene change it's
  the one triggering.

**Settings panel:**

- **Mouse sensitivity** — reads/writes the current player's
  `mouse_sensitivity` directly (works against either controller, since both
  expose that field the same way).
- **Fullscreen** — a toggle-mode `Button`, not a `CheckBox`. (A `CheckBox`
  was tried first; its check icon didn't render in this theme, confirmed
  via screenshot — swapped for a `Button` with `toggle_mode = true`, which
  was already proven to render.)
- **Season (Winter/Summer)** — toggles `GameState.is_winter` via
  `GameState.set_winter()`, which fires `season_changed` and triggers
  `terrain_generator.gd` to rebuild with the other palette. See
  [World Generation](World-Generation.md).
- **Fur color** — a `ColorPickerButton` calling the current player's
  `set_fur_color()`/`get_fur_color()`. Labeled generically ("Fur Color,"
  not "Wolf Color") since any species could be active when this panel
  opens.

Both `Settings` reads (on open) and writes (on change) go through
`get_tree().get_first_node_in_group("player")` — every player controller
scene adds itself to the `"player"` group, so the pause menu never needs a
direct reference or to know which controller type is active.

## HUD (`scripts/ui/player_hud.gd`)

Minimal: `update_health(current, max)` and `update_stamina(current, max)`,
each just setting a `ProgressBar` + `Label`. Both controllers call these
from their `Damageable`/`Stamina` signal handlers — the HUD itself doesn't
listen to anything directly.

## Debug overlay (`scripts/ui/debug_overlay.gd`, autoload)

Two independently-toggleable panels: `F3` for performance stats (FPS,
frame/physics time, RAM, CPU, draw calls, object/node counts — reading
`/proc/self/status` and `/proc/self/stat` directly on Linux for RAM/CPU,
since `Performance.get_monitor()` alone doesn't give process-level RSS or
CPU%), `F1` for a static list of key bindings. Neither depends on
`GameState` or which species is active.
