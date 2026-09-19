extends Node3D

## Scatters hostile wildlife across the map — same rejection-sampling
## approach as biome_populator.gd (random point, reject if too close to
## spawn or inside the water), just spawning enemies instead of scenery.

const ENEMY_SCENE: String = "res://scenes/enemies/enemy.tscn"
const FOX_SPECIES: String = "res://resources/enemies/fox_species.tres"

@export var enemy_count: int = 8
## Kept well inside TerrainHeight.MOUNTAIN_START_RADIUS (65) — the mountain
## ring's terrain is steep enough that the collision heightmap (sampled
## only at its 2-unit grid) can diverge sharply from the smooth analytic
## height used to place things, enough for a ground-based enemy (or the
## player, wandering the same terrain) to spawn over a gap and fall through.
@export var play_area_half_size: float = 55.0
@export var safe_zone_radius: float = 20.0 ## keep clear around spawn/dummy
@export var rng_seed: int = 20260918

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var enemy_scene: PackedScene = load(ENEMY_SCENE)
	var species: EnemySpecies = load(FOX_SPECIES)

	var placed := 0
	var attempts := 0
	while placed < enemy_count and attempts < enemy_count * 20:
		attempts += 1
		var x := rng.randf_range(-play_area_half_size, play_area_half_size)
		var z := rng.randf_range(-play_area_half_size, play_area_half_size)
		if Vector2(x, z).length() < safe_zone_radius:
			continue
		if TerrainHeight.is_water(x, z):
			continue

		var y := TerrainHeight.get_height(x, z)
		var instance: CharacterBody3D = enemy_scene.instantiate()
		instance.species = species
		# Set before add_child(): _ready() (which runs synchronously as part
		# of add_child) records this as its home/respawn position.
		instance.position = Vector3(x, y, z)
		add_child(instance)
		placed += 1
