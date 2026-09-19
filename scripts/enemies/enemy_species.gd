extends Resource
class_name EnemySpecies

## Data-driven description of a hostile animal, mirroring the shape of
## AnimalSpecies (scripts/player/animal_species.gd) but scoped to what an
## AI-controlled enemy actually needs — no player_scene, no fur tinting,
## and AI tuning (detection/attack range) instead of player input mapping.
## Kept as a separate resource type rather than reusing AnimalSpecies
## directly, since AnimalSpecies.player_scene has no default and exists
## specifically for the character-select spawn flow an enemy never goes
## through.

@export var display_name: String = ""
@export var model_scene: PackedScene
@export var model_scale: float = 0.3

@export_group("Stats")
@export var max_health: float = 60.0
@export var attack_damage: float = 10.0
@export var walk_speed: float = 3.0
@export var chase_speed: float = 6.0

@export_group("AI")
@export var detection_radius: float = 15.0 ## player within this range while idle triggers a chase
@export var attack_range: float = 2.0
@export var leash_radius: float = 25.0 ## player beyond this range while chasing breaks it off

@export_group("Animations")
@export var anim_idle: String = "Idle"
@export var anim_chase: String = "Gallop"
@export var anim_attack: String = "Attack"
@export var anim_death: String = "Death"
@export var anim_hit_react: Array[String] = ["Idle_HitReact1", "Idle_HitReact2"]

@export_group("Combat")
@export var hitbox_offset: Vector3 = Vector3(0, 0.5, -0.9)
@export var attack_hit_start_fraction: float = 0.4
@export var attack_hit_end_fraction: float = 0.65
