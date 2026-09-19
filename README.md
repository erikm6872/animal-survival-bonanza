# Animal Survival Bonanza

An open-source, microtransaction-free 3D animal survival game. Choose an
animal, explore an open world, fight to survive, and earn in-game currency
through play — no purchases, ever.

## Status

Early prototype, single biome. Three playable animals so far — Wolf and Stag
(ground) and Sparrow (flight, with landing/hopping) — chosen from a character
select screen, sharing a data-driven combat/movement framework (health,
stamina, dodge, melee attacks). The world is a procedurally generated valley
ringed by mountains, with rolling hills, a river with a waterfall, two ponds,
ambient fish, and scattered trees/bushes. Progression/currency and hostile
wildlife are not yet implemented. See [docs/GDD.md](docs/GDD.md) for the full
design plan and [docs/wiki](docs/wiki/Home.md) for how it's built.

## Tech stack

- **Engine:** [Godot 4.7](https://godotengine.org/) (GDScript)
- **License:** MIT (see [LICENSE](LICENSE))
- **Art:** Free/CC0 low-poly asset packs, plus a couple of procedurally-built
  models where no suitable asset existed (see
  [assets/models/ATTRIBUTION.md](assets/models/ATTRIBUTION.md))

## Running the project

1. Install [Godot 4.7+](https://godotengine.org/download).
2. Open this folder as a project in the Godot editor, or run headless:
   ```
   godot --path .
   ```
   This launches into the character select screen
   (`scenes/ui/character_select.tscn`), the project's main scene.
3. Pick an animal, then:
   - **Ground (Wolf/Stag):** WASD to move, mouse to look, Space to jump,
     Shift to sprint, Left Mouse to attack, Ctrl to dodge.
   - **Flight (Sparrow):** WASD + mouse for full 3D movement (look up/down
     to climb/dive), Shift for fast flying, Left Mouse to attack, Ctrl to
     dodge, Space to land/take off when close to the ground.
   - **Both:** `C` cycles camera distance, `Esc` opens the pause menu
     (Resume / Settings / Change Animal / Quit — Settings has mouse
     sensitivity, fullscreen, a summer/winter terrain toggle, and a fur
     color picker), `F1`/`F3` toggle the controls/debug overlays, `K`
     damages yourself for testing.

## Project layout

```
scenes/     Godot scenes (player, world, ui, debug)
scripts/    GDScript source (player, world, combat, ui, core)
resources/  Data-driven resources (per-species .tres files)
assets/     Models, textures, animations
addons/     Third-party Godot plugins
docs/       Design doc (GDD.md) and technical wiki (wiki/)
```

## Contributing

This project is early and the design is still evolving — see the GDD for
current direction before opening large PRs, and the
[technical wiki](docs/wiki/Home.md) for how the existing systems fit
together. Issues and small PRs are welcome.
