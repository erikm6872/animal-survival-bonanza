extends Node3D

## Scatters trees, rocks, and bushes across the terrain, height-sampled so
## they sit correctly on the hills. Fixed seed so the layout is stable
## across runs.
##
## Counts/areas were last tuned when the map's play_area_half_size was
## still 90 (TERRAIN_SIZE 200); the map size increase that doubled
## play_area_half_size to 180 quadrupled the scattered area (side length
## doubles, area is squared) without raising the counts to match, which is
## why the forest felt sparse afterward. Counts below are rebalanced to
## roughly the original per-square-meter density over the new area, times
## a further density bump per this request for a denser, more varied
## forest feel.

## Small undergrowth-scale trees — young growth filling gaps between the
## bigger canopy trees.
const TREE_SCENES_SMALL: Array[String] = [
	"res://assets/models/nature-kit/tree_small.glb",
	"res://assets/models/nature-kit/tree_small_dark.glb",
	"res://assets/models/nature-kit/tree_small_fall.glb",
	"res://assets/models/nature-kit/tree_pineSmallA.glb",
	"res://assets/models/nature-kit/tree_pineSmallB.glb",
	"res://assets/models/nature-kit/tree_pineSmallC.glb",
	"res://assets/models/nature-kit/tree_pineSmallD.glb",
	"res://assets/models/nature-kit/tree_thin.glb",
	"res://assets/models/nature-kit/tree_thin_dark.glb",
]
## Mid-size canopy trees — the bulk of the forest.
const TREE_SCENES_MEDIUM: Array[String] = [
	"res://assets/models/nature-kit/tree_default.glb",
	"res://assets/models/nature-kit/tree_default_dark.glb",
	"res://assets/models/nature-kit/tree_default_fall.glb",
	"res://assets/models/nature-kit/tree_oak.glb",
	"res://assets/models/nature-kit/tree_oak_dark.glb",
	"res://assets/models/nature-kit/tree_oak_fall.glb",
	"res://assets/models/nature-kit/tree_detailed.glb",
	"res://assets/models/nature-kit/tree_detailed_fall.glb",
	"res://assets/models/nature-kit/tree_fat.glb",
	"res://assets/models/nature-kit/tree_fat_fall.glb",
	"res://assets/models/nature-kit/tree_cone.glb",
	"res://assets/models/nature-kit/tree_cone_dark.glb",
	"res://assets/models/nature-kit/tree_pineRoundA.glb",
	"res://assets/models/nature-kit/tree_pineRoundB.glb",
	"res://assets/models/nature-kit/tree_pineRoundC.glb",
	"res://assets/models/nature-kit/tree_pineDefaultA.glb",
	"res://assets/models/nature-kit/tree_pineDefaultB.glb",
]
## Tall canopy standouts — scattered more sparsely to read as landmarks
## rather than filler.
const TREE_SCENES_TALL: Array[String] = [
	"res://assets/models/nature-kit/tree_tall.glb",
	"res://assets/models/nature-kit/tree_tall_dark.glb",
	"res://assets/models/nature-kit/tree_tall_fall.glb",
	"res://assets/models/nature-kit/tree_pineTallA.glb",
	"res://assets/models/nature-kit/tree_pineTallB.glb",
	"res://assets/models/nature-kit/tree_pineTallC.glb",
	"res://assets/models/nature-kit/tree_pineTallD.glb",
	"res://assets/models/nature-kit/tree_plateau.glb",
]
const BUSH_SCENES: Array[String] = [
	"res://assets/models/nature-kit/plant_bush.glb",
	"res://assets/models/nature-kit/plant_bushDetailed.glb",
	"res://assets/models/nature-kit/plant_bushLarge.glb",
	"res://assets/models/nature-kit/plant_bushSmall.glb",
	"res://assets/models/nature-kit/plant_bushTriangle.glb",
]
const ROCK_SCENES_SMALL: Array[String] = [
	"res://assets/models/nature-kit/rock_smallA.glb",
	"res://assets/models/nature-kit/rock_smallB.glb",
	"res://assets/models/nature-kit/rock_smallC.glb",
	"res://assets/models/nature-kit/rock_smallD.glb",
	"res://assets/models/nature-kit/rock_smallE.glb",
	"res://assets/models/nature-kit/rock_smallF.glb",
	"res://assets/models/nature-kit/stone_smallA.glb",
	"res://assets/models/nature-kit/stone_smallB.glb",
	"res://assets/models/nature-kit/stone_smallC.glb",
]
const ROCK_SCENES_LARGE: Array[String] = [
	"res://assets/models/nature-kit/rock_largeA.glb",
	"res://assets/models/nature-kit/rock_largeB.glb",
	"res://assets/models/nature-kit/rock_largeC.glb",
	"res://assets/models/nature-kit/rock_largeD.glb",
	"res://assets/models/nature-kit/rock_tallA.glb",
	"res://assets/models/nature-kit/rock_tallB.glb",
	"res://assets/models/nature-kit/rock_tallC.glb",
	"res://assets/models/nature-kit/stone_largeA.glb",
	"res://assets/models/nature-kit/stone_largeB.glb",
	"res://assets/models/nature-kit/stone_tallA.glb",
]

@export var small_tree_count: int = 320
@export var medium_tree_count: int = 480
@export var tall_tree_count: int = 140
@export var bush_count: int = 360
@export var small_rock_count: int = 220
@export var large_rock_count: int = 80
@export var play_area_half_size: float = 180.0
@export var safe_zone_radius: float = 10.0 ## keep clear around spawn/dummy
@export var rng_seed: int = 20260827

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_scatter(TREE_SCENES_SMALL, small_tree_count, rng, 1.0, 1.8)
	_scatter(TREE_SCENES_MEDIUM, medium_tree_count, rng, 2.0, 3.0)
	_scatter(TREE_SCENES_TALL, tall_tree_count, rng, 2.8, 4.2)
	_scatter(BUSH_SCENES, bush_count, rng, 0.8, 1.4)
	_scatter(ROCK_SCENES_SMALL, small_rock_count, rng, 0.6, 1.3)
	_scatter(ROCK_SCENES_LARGE, large_rock_count, rng, 1.2, 2.4)

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
