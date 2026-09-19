# Species System

`scripts/player/animal_species.gd` defines `AnimalSpecies`, a `Resource`
that fully describes one playable animal: its model, stats, animation clip
names, fur tint config, and combat timing. The three playable species —
Wolf, Stag, Sparrow — are each a single `.tres` file under
`resources/species/`. Adding a fourth species that reuses an existing
movement controller is a new `.tres` file, not a code change.

## Fields

```gdscript
@export var display_name: String
@export var model_scene: PackedScene       # instanced under $Model at spawn
@export var model_scale: float
@export var player_scene: PackedScene      # which controller scene plays this species

@export var fur_mesh_path: NodePath        # empty = no fur tinting
@export var fur_surfaces: Array[int]
@export var fur_lighten: Array[float]      # parallel to fur_surfaces

@export_group("Stats")
@export var max_health: float
@export var attack_damage: float
@export var walk_speed: float
@export var sprint_speed: float

@export_group("Animations")
@export var anim_idle: String
@export var anim_walk: String
@export var anim_gallop: String
@export var anim_attack: String
@export var anim_death: String
@export var anim_dodge: String
@export var anim_hit_react: Array[String]  # picked at random on hit
@export var anim_ground_idle: String       # flight-only, see below
@export var anim_hop: String               # flight-only, see below

@export_group("Combat")
@export var hitbox_offset: Vector3
@export var attack_hit_start_fraction: float  # 0-1 of the Attack clip's length
@export var attack_hit_end_fraction: float
```

Both controllers read every field through `species.<name>` rather than
hardcoding clip names or stats, which is why Wolf and Stag can share a
controller despite the underlying Quaternius pack using slightly different
clip names per animal (`Idle_Headlow` vs `Idle_2_HeadLow`, etc.) — see
`assets/models/ATTRIBUTION.md` for the exact per-animal clip lists.

`anim_ground_idle`/`anim_hop` are read only by `flight_controller.gd`, for
the landed/hopping state — see [Movement Controllers](Movement-Controllers.md).
Leaving them empty (the default) is correct for every ground species; the
flight controller falls back to `anim_idle`/`anim_walk` if they're unset,
so a flying species without dedicated ground clips still works, just with
its flying-idle pose while grounded.

## `player_scene`: which controller plays this species

A species doesn't just describe stats — it also names which *scene* spawns
it. `scripts/world/player_spawner.gd` reads `GameState.selected_species`
and instances `species.player_scene` directly, so the world scene never
needs to know how many controller types exist. Today there are two:
`scenes/player/player.tscn` (ground, used by Wolf and Stag) and
`scenes/player/flying_player.tscn` (flight, used by Sparrow). A new
movement domain (swimming, say) would mean one new controller scene, one
new species resource pointing at it, and no changes to the spawner.

## The circular-`preload()` trap

Don't add a `preload()` default to `species` (on a controller) or
`player_scene` (on `AnimalSpecies`). The dependency chain looks like:

```
animal_species.gd → (preloads) → player.tscn → player_controller.gd
    → (preloads) → wolf_species.tres → (references) → animal_species.gd
```

`preload()` defaults on `@export` fields are resolved at **compile time**,
so this chain becomes a hard circular dependency the moment any link in it
uses `preload()` instead of `load()`. The fix used throughout this codebase:

- `AnimalSpecies.player_scene` has no default value at all — every species
  `.tres` sets it explicitly via `ExtResource`.
- Both controllers' `@export var species: AnimalSpecies` also has no
  default. Instead, `_ready()` does:
  ```gdscript
  if GameState.selected_species:
      species = GameState.selected_species
  elif not species:
      species = load("res://resources/species/wolf_species.tres")  # or sparrow_species.tres
  ```
  using runtime `load()`, which only touches the file when this code
  actually executes — no compile-time cycle.

This is also why each species `.tres` is a complete, standalone resource:
there's no shared base resource they inherit stats from, since that would
reopen the same cycle risk from the resource side.

## Adding a new species (same movement type)

1. Copy an existing `.tres` (e.g. `wolf_species.tres`) as a starting point.
2. Point `model_scene` at the new model, set `model_scale` for its actual
   size (see the FBX-unit gotcha in
   [World Generation](World-Generation.md#fbx-unit-gotcha) if it's imported
   from an FBX pack), and fill in the animation clip names the model
   actually has.
3. Set `player_scene` to `res://scenes/player/player.tscn` (or
   `flying_player.tscn` for a flying species).
4. Tune `hitbox_offset` and the `attack_hit_*_fraction` pair by eye against
   the model's actual attack animation — these aren't derived from
   anything, they're just where the bite/lunge lands in that specific clip.
5. Add the new `.tres` path to `SPECIES_PATHS` in
   `scripts/ui/character_select.gd`.

No controller script changes needed, as long as the model's animation set
covers the fields the chosen controller reads.
