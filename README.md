# Animal Survival Bonanza

An open-source, microtransaction-free 3D animal survival game. Choose an
animal, explore an open world, fight to survive, and earn in-game currency
through play — no purchases, ever.

## Status

Early prototype. A single playable animal with basic third-person movement
and a test world exists; combat, progression, and additional animals are not
yet implemented. See [docs/GDD.md](docs/GDD.md) for the full design plan.

## Tech stack

- **Engine:** [Godot 4.7](https://godotengine.org/) (GDScript)
- **License:** MIT (see [LICENSE](LICENSE))
- **Art:** Free/CC0 low-poly asset packs for the initial prototype

## Running the project

1. Install [Godot 4.7+](https://godotengine.org/download).
2. Open this folder as a project in the Godot editor, or run headless:
   ```
   godot --path . scenes/world/test_world.tscn
   ```
3. Controls: WASD to move, mouse to look, Space to jump, Shift to sprint,
   Left Mouse to attack (placeholder), Esc to release the mouse cursor.

## Project layout

```
scenes/     Godot scenes (player, world, ui)
scripts/    GDScript source (player, world, combat)
assets/     Models, textures, animations
addons/     Third-party Godot plugins
docs/       Design documents
```

## Contributing

This project is early and the design is still evolving — see the GDD for
current direction before opening large PRs. Issues and small PRs are welcome.
