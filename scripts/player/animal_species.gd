extends Resource
class_name AnimalSpecies

## Data-driven description of a playable animal: its model, stats, animation
## clip names, and combat tuning. player_controller.gd instances model_scene
## at runtime and reads everything else from here, so adding a new species
## is just a new resource file, not a code change.

@export var display_name: String = ""
@export var model_scene: PackedScene
@export var model_scale: float = 0.3
## Which scene/controller spawns this species — most species share the
## ground-based one; flight (or future movement types) just point here
## instead. Same stats/animation fields below still apply to both. Every
## species resource sets this explicitly (no default here — that would
## make this script preload player.tscn, which preloads a species resource
## of this same class, a real circular dependency).
@export var player_scene: PackedScene

## Path (relative to the instanced model's root) to the MeshInstance3D whose
## surfaces get tinted by the fur color picker. Empty = no fur tinting.
@export var fur_mesh_path: NodePath = ^""
@export var fur_surfaces: Array[int] = [0]
## Parallel to fur_surfaces: how far to lerp each surface's color toward
## white, for packs that split fur into a base + a lighter highlight tone.
@export var fur_lighten: Array[float] = [0.0]

@export_group("Stats")
@export var max_health: float = 100.0
@export var attack_damage: float = 15.0
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0

@export_group("Animations")
@export var anim_idle: String = "Idle"
@export var anim_walk: String = "Walk"
@export var anim_gallop: String = "Gallop"
@export var anim_attack: String = "Attack"
@export var anim_death: String = "Death"
@export var anim_dodge: String = "Gallop_Jump"
@export var anim_hit_react: Array[String] = ["Idle_HitReact1", "Idle_HitReact2"]
## Flight-only: played while landed and standing still / hopping along the
## ground. Empty = species doesn't support landing (falls back to
## anim_idle/anim_walk), which is fine for every ground species.
@export var anim_ground_idle: String = ""
@export var anim_hop: String = ""

@export_group("Combat")
@export var hitbox_offset: Vector3 = Vector3(0, 0.5, -0.9)
## Fraction (0-1) of the Attack clip's length the hitbox is live for — tuned
## per species to line up with that clip's bite/impact lunge.
@export var attack_hit_start_fraction: float = 0.4
@export var attack_hit_end_fraction: float = 0.65
