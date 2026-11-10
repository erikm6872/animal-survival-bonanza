extends Node3D

## Spawns ambient baitfish schools through the open ocean -- the Tuna's prey.
## Reuses the same FBX fish models as the land map's ponds/river (fish_spawner.gd),
## just with ocean_fish.gd's full-3D wander instead of a flat pond/river patch.

const FISH_SCENES: Array[String] = [
	"res://assets/models/fish/Fish1.fbx",
	"res://assets/models/fish/Fish2.fbx",
	"res://assets/models/fish/Fish3.fbx",
]

const FISH_SCALE: float = 0.03 ## see fish_spawner.gd -- FBX cm->m correction

@export var school_count: int = 10
@export var fish_per_school: int = 6
@export var school_radius: float = 5.0
@export var spawn_area_radius: float = 70.0
@export var rng_seed: int = 20261109

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var scenes: Array[PackedScene] = []
	for path in FISH_SCENES:
		scenes.append(load(path))

	for i in school_count:
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(0.0, spawn_area_radius)
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		var seafloor := OceanHeight.get_seafloor_height(x, z)
		var y := rng.randf_range(seafloor + 3.0, OceanHeight.WATER_LEVEL - 2.0)
		var center := Vector3(x, y, z)
		for j in fish_per_school:
			_spawn_fish(scenes, rng, center, school_radius)

func _spawn_fish(scenes: Array[PackedScene], rng: RandomNumberGenerator, center: Vector3, wander_radius: float) -> void:
	var wrapper := Node3D.new()
	wrapper.set_script(load("res://scripts/world/ocean_fish.gd"))
	wrapper.center = center
	wrapper.radius = wander_radius

	var scene: PackedScene = scenes[rng.randi_range(0, scenes.size() - 1)]
	var model: Node3D = scene.instantiate()
	wrapper.add_child(model)
	# Faces +Z by default; flip X/Z to match ocean_fish.gd's -Z-forward
	# movement convention.
	model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(-FISH_SCALE, FISH_SCALE, -FISH_SCALE)), Vector3.ZERO)

	add_child(wrapper)
	wrapper.global_position = center
