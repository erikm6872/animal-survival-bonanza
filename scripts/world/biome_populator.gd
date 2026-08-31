extends Node3D

## Scatters trees and bushes across the terrain, height-sampled so they sit
## correctly on the hills. Fixed seed so the layout is stable across runs.

const TREE_SCENES: Array[String] = [
	"res://assets/models/nature-kit/tree_default.glb",
	"res://assets/models/nature-kit/tree_oak.glb",
	"res://assets/models/nature-kit/tree_pineTallA.glb",
	"res://assets/models/nature-kit/tree_pineRoundA.glb",
	"res://assets/models/nature-kit/tree_small.glb",
	"res://assets/models/nature-kit/tree_thin.glb",
]
const BUSH_SCENES: Array[String] = [
	"res://assets/models/nature-kit/plant_bush.glb",
	"res://assets/models/nature-kit/plant_bushDetailed.glb",
	"res://assets/models/nature-kit/plant_bushLarge.glb",
	"res://assets/models/nature-kit/plant_bushSmall.glb",
	"res://assets/models/nature-kit/plant_bushTriangle.glb",
]

@export var tree_count: int = 220
@export var bush_count: int = 100
@export var play_area_half_size: float = 90.0
@export var safe_zone_radius: float = 10.0 ## keep clear around spawn/dummy
@export var rng_seed: int = 20260827

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_scatter(TREE_SCENES, tree_count, rng, 2.0, 3.0)
	_scatter(BUSH_SCENES, bush_count, rng, 0.8, 1.4)

func _scatter(scene_paths: Array[String], count: int, rng: RandomNumberGenerator, min_scale: float, max_scale: float) -> void:
	var scenes: Array[PackedScene] = []
	for path in scene_paths:
		scenes.append(load(path))

	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 10:
		attempts += 1
		var x := rng.randf_range(-play_area_half_size, play_area_half_size)
		var z := rng.randf_range(-play_area_half_size, play_area_half_size)
		if Vector2(x, z).length() < safe_zone_radius:
			continue
		if TerrainHeight.is_water(x, z):
			continue

		var y := TerrainHeight.get_height(x, z)
		var scene: PackedScene = scenes[rng.randi_range(0, scenes.size() - 1)]
		var inst: Node3D = scene.instantiate()
		add_child(inst)

		var scale_factor := rng.randf_range(min_scale, max_scale)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		basis = basis.scaled(Vector3.ONE * scale_factor)
		inst.transform = Transform3D(basis, Vector3(x, y, z))
		placed += 1
