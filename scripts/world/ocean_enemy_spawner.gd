extends Node3D

## Scatters Tiger Sharks through the open ocean -- the ocean biome's
## hostile wildlife, mirroring enemy_spawner.gd's rejection-sampling
## approach for the land map's Fox. Kept clear of the spawn point so the
## Tuna doesn't surface directly into a shark.

const ENEMY_SCENE: String = "res://scenes/enemies/ocean_enemy.tscn"
const SHARK_SPECIES: String = "res://resources/enemies/tiger_shark_species.tres"

@export var shark_count: int = 5
@export var spawn_area_radius: float = 80.0
@export var safe_zone_radius: float = 25.0
@export var rng_seed: int = 20261116

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var enemy_scene: PackedScene = load(ENEMY_SCENE)
	var species: EnemySpecies = load(SHARK_SPECIES)

	var placed := 0
	var attempts := 0
	while placed < shark_count and attempts < shark_count * 20:
		attempts += 1
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(0.0, spawn_area_radius)
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		if Vector2(x, z).length() < safe_zone_radius:
			continue

		var seafloor := OceanHeight.get_seafloor_height(x, z)
		var y := rng.randf_range(seafloor + 4.0, OceanHeight.WATER_LEVEL - 3.0)
		var instance: CharacterBody3D = enemy_scene.instantiate()
		instance.species = species
		instance.position = Vector3(x, y, z)
		add_child(instance)
		placed += 1
