# Hostile Wildlife

The first enemy type: a hostile Fox, built to give combat something to
actually fight back (the training dummy proved hit detection works, but
never hit back). Three new files, none of them touching the player
controllers or `AnimalSpecies`.

## `EnemySpecies` (`scripts/enemies/enemy_species.gd`)

A data-driven resource shaped like [`AnimalSpecies`](Species-System.md) —
model, stats, animation clip names, combat timing — but deliberately a
**separate resource type**, not a reuse of `AnimalSpecies`:

```gdscript
extends Resource
class_name EnemySpecies

@export var display_name: String
@export var model_scene: PackedScene
@export var model_scale: float

@export_group("Stats")
@export var max_health: float
@export var attack_damage: float
@export var walk_speed: float
@export var chase_speed: float

@export_group("AI")
@export var detection_radius: float  # player within this while idle triggers a chase
@export var attack_range: float
@export var leash_radius: float      # player beyond this while chasing breaks it off

@export_group("Animations")
@export var anim_idle: String
@export var anim_chase: String
@export var anim_attack: String
@export var anim_death: String
@export var anim_hit_react: Array[String]

@export_group("Combat")
@export var hitbox_offset: Vector3
@export var attack_hit_start_fraction: float
@export var attack_hit_end_fraction: float
```

`AnimalSpecies.player_scene` has no default specifically because it exists
for the character-select spawn flow — an enemy never goes through that
flow, so forcing enemies into `AnimalSpecies` would mean every enemy
resource sets an irrelevant field just to satisfy the type. A parallel,
narrower resource type was simpler than complicating `AnimalSpecies` to
serve two purposes. No `anim_walk`/`anim_gallop` split either — an enemy
only ever moves at one speed (`chase_speed`) when it's moving at all.

## `enemy_controller.gd` — the state machine

A `CharacterBody3D`, same gravity/floor movement model as the ground player
controller, with an explicit `enum State { IDLE, CHASE, ATTACK, DEAD }`
rather than the boolean-flag style the player controllers use — there's
exactly one active state at a time here, so an enum reads more directly
than a pile of `is_*` bools would.

```
IDLE ──(player within detection_radius, or takes damage)──▶ CHASE
CHASE ──(within attack_range)──▶ ATTACK
CHASE ──(player beyond leash_radius)──▶ IDLE
ATTACK ──(player beyond attack_range * 1.3)──▶ CHASE
(any) ──(health reaches 0)──▶ DEAD ──(after DEATH_RESPAWN_DELAY)──▶ IDLE, full health, back at spawn
```

Notes on specific transitions:

- **Getting hit while IDLE triggers CHASE.** An idle animal that gets
  attacked and just stands there ignoring it reads as broken, not passive.
- **ATTACK breaks off at `attack_range * 1.3`, not exactly `attack_range`.**
  Breaking off at the exact same distance that triggers the attack means
  standing right at that boundary flickers between the two states every
  frame. The slack margin avoids that.
- **DEAD respawns after a delay at `home_position`** (recorded once, in
  `_ready()`, from wherever the spawner placed it) — same pattern as
  `training_dummy.gd`, so a single enemy can be fought repeatedly during
  testing/play instead of being a one-shot kill with nothing left to fight.

Combat mechanics (attack hit-window timing, hit-react, damage handling) are
copy-pasted in structure from the ground player controller — same
`Damageable`/`Hitbox` components, same fraction-based attack-window timing
— just driven by AI state instead of player input. See
[Combat System](Combat-System.md) for what those components actually do.

### The attack-range tuning gotcha

`attack_range` is an AI decision threshold ("close enough to start
attacking"), but it has no inherent connection to how far the `Hitbox`
Area3D actually reaches (`hitbox_offset` distance + its `SphereShape3D`
radius). Setting `attack_range` larger than that physical reach lets the
enemy stop attacking-but-whiffing at a distance the hitbox can never
actually cover — the AI looks like it's attacking (animation plays, hitbox
opens on schedule) but nothing ever lands. This shipped once during initial
testing (`attack_range = 2.0` against a hitbox reaching about 1.05 units)
before being caught by a script-driven test that checked whether player
health actually dropped, not just whether the state machine reached
`ATTACK`. Fixed by tuning `attack_range` (1.5) below the hitbox's actual
reach, with a small margin — see the current values in
`resources/enemies/fox_species.tres`.

## `enemy_spawner.gd` (`scripts/world/enemy_spawner.gd`)

Same rejection-sampling scatter as
[`biome_populator.gd`](World-Generation.md#biome_populatorgd--trees-and-bushes):
pick a random point, reject it if it's too close to spawn or inside the
water, otherwise place an enemy there. One real difference from scattering
static props, though:

### The mountain-collision gotcha

`biome_populator.gd` scatters trees out to `play_area_half_size = 90`,
reaching into the lower mountain slopes — harmless for static decoration.
`enemy_spawner.gd` keeps `play_area_half_size` at **55**, well inside
`TerrainHeight.MOUNTAIN_START_RADIUS` (65). The mountain ring's terrain
uses ridged noise for jagged peaks — enough high-frequency variation that
the *analytic* height at an arbitrary `(x, z)` (what `enemy_spawner.gd` and
`TerrainHeight.get_height()` compute directly) can diverge sharply from the
terrain mesh's actual collision surface, which is only sampled at the
mesh's 2-unit grid vertices (see
[World Generation](World-Generation.md#terrain_generatorgd--the-mesh-and-its-collision)).
An enemy — or the player, wandering the same terrain — spawned or teleported
into one of these gaps falls through into freefall instead of landing on
solid ground. This was caught during verification (a test script teleported
the player near a mountain-zone enemy to trigger a chase, and the player
fell through the world instead); the fix was pulling the enemy spawn area
back to the gentler valley terrain, not adjusting the terrain generation
itself. Ground-based creatures — enemies now, and the player in normal
play — are safest kept off steep mountain terrain until the terrain
collision itself gets finer-grained near slopes, if that's ever needed.

## Adding a new enemy type

1. Source or build a model with at least idle/chase/attack/death/hit-react
   animations — the same Quaternius "Ultimate Animated Animal Pack" Fox
   came from has several more ground animals (Husky, Cow, Bull, etc.) with
   the same rig/animation-name conventions.
2. Copy `resources/enemies/fox_species.tres` as a starting point, point
   `model_scene` at the new model, and tune `hitbox_offset`/`attack_range`
   together (see the gotcha above) rather than independently.
3. Either add a second `@export`ed species field to `enemy_spawner.gd` (or
   generalize it to take an array of species to pick from) — it currently
   hardcodes a single Fox species constant, since "at least one enemy
   type" was the initial bar, not a roster.
