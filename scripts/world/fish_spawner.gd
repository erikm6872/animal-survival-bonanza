extends Node3D

## Spawns ambient fish in the ponds and at a few spots along the river.

const FISH_SCENES: Array[String] = [
	"res://assets/models/fish/Fish1.fbx",
	"res://assets/models/fish/Fish2.fbx",
	"res://assets/models/fish/Fish3.fbx",
]

## The FBX importer bakes in a ~100x unit conversion (cm -> m), so the raw
## mesh (~8 local units long pre-scale) needs a small factor here, not a
## multiplier, to end up a reasonable ~0.25m.
const FISH_SCALE: float = 0.03
const SWIM_DEPTH: float = 0.4 ## below the water surface

@export var fish_per_pond: int = 5
@export var river_spawn_points: int = 5
@export var fish_per_river_point: int = 3
@export var rng_seed: int = 20260829

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var scenes: Array[PackedScene] = []
	for path in FISH_SCENES:
		scenes.append(load(path))

	for pond in TerrainHeight.PONDS:
		var center3d := Vector3(pond["center"].x, pond["water_level"] - SWIM_DEPTH, pond["center"].y)
		var wander_radius: float = pond["radius"] * 0.7
		for i in fish_per_pond:
			_spawn_fish(scenes, rng, center3d, wander_radius)

	var river_divisions := maxi(river_spawn_points - 1, 1)
	for i in river_spawn_points:
		var x: float = lerp(-80.0, 80.0, float(i) / float(river_divisions))
		var z := TerrainHeight.river_center_z(x)
		var center3d := Vector3(x, TerrainHeight.RIVER_WATER_LEVEL - SWIM_DEPTH, z)
		var wander_radius := TerrainHeight.RIVER_HALF_WIDTH * 0.8
		for j in fish_per_river_point:
			_spawn_fish(scenes, rng, center3d, wander_radius)

func _spawn_fish(scenes: Array[PackedScene], rng: RandomNumberGenerator, center: Vector3, wander_radius: float) -> void:
	var wrapper := Node3D.new()
	wrapper.set_script(load("res://scripts/world/fish.gd"))
	wrapper.center = center
	wrapper.radius = wander_radius

	var scene: PackedScene = scenes[rng.randi_range(0, scenes.size() - 1)]
	var model: Node3D = scene.instantiate()
	wrapper.add_child(model)
	# Faces +Z by default (same as the Wolf pack); flip X/Z to match fish.gd's
	# -Z-forward movement convention.
	model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(-FISH_SCALE, FISH_SCALE, -FISH_SCALE)), Vector3.ZERO)

	# Add fully assembled (script + params + model child) so fish.gd's
	# _ready() sees the model already in place when it looks for the
	# AnimationPlayer.
	add_child(wrapper)
	wrapper.global_position = center
