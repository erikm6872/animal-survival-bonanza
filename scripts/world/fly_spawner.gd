extends Node3D

## Scatters fly swarms across the map — same rejection-sampling approach as
## enemy_spawner.gd/biome_populator.gd, but spawning small clusters (flies
## plausibly swarm together) with each fly then wandering within its own
## cluster via fly.gd, rather than one fly per rejected point.

const FLY_SCRIPT: String = "res://scripts/world/fly.gd"

@export var swarm_count: int = 15
@export var flies_per_swarm: int = 4
## Hovering height above the ground, not clamped to terrain collision like
## ground creatures — flies never touch the ground/physics at all, so the
## mountain-collision gotcha documented on enemy_spawner.gd doesn't apply
## here, but they still need to stay low enough for a ground-bound
## Chameleon to actually reach them.
@export var hover_height_min: float = 0.3
@export var hover_height_max: float = 1.0
@export var swarm_radius: float = 2.5
@export var play_area_half_size: float = 55.0
@export var safe_zone_radius: float = 10.0
@export var rng_seed: int = 20261101

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var placed := 0
	var attempts := 0
	while placed < swarm_count and attempts < swarm_count * 20:
		attempts += 1
		var x := rng.randf_range(-play_area_half_size, play_area_half_size)
		var z := rng.randf_range(-play_area_half_size, play_area_half_size)
		if Vector2(x, z).length() < safe_zone_radius:
			continue
		if TerrainHeight.is_water(x, z):
			continue

		var ground_y := TerrainHeight.get_height(x, z)
		var hover_y := ground_y + rng.randf_range(hover_height_min, hover_height_max)
		_spawn_swarm(rng, Vector3(x, hover_y, z))
		placed += 1

func _spawn_swarm(rng: RandomNumberGenerator, center: Vector3) -> void:
	for i in flies_per_swarm:
		var fly := Node3D.new()
		fly.set_script(load(FLY_SCRIPT))
		fly.center = center
		fly.radius = swarm_radius
		# Slight per-fly variation so a swarm doesn't move in lockstep.
		fly.fly_speed = rng.randf_range(0.6, 1.1)
		fly.turn_speed = rng.randf_range(2.5, 4.0)
		add_child(fly)
		fly.global_position = center
