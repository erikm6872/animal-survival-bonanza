extends Node3D

## Scatters trees, rocks, and bushes across the terrain, height-sampled so
## they sit correctly on the hills. Fixed seed so the layout is stable
## across runs.
##
## Counts/scales have been bumped several times over for a denser, thicker,
## taller forest feel, most recently per feedback that trees still weren't
## large enough in any dimension. Scatter area is a disk out to
## TerrainHeight.MOUNTAIN_START_RADIUS (not a square) so the forest stops
## right at the foot of the mountain ring instead of continuing onto the
## mountainside. TerrainHeight.is_clearing() still carves bare
## fields/clearings back out of that disk so it doesn't read as solid
## wall-to-wall forest despite the density.

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
	"res://assets/models/nature-kit/plant_bushLargeTriangle.glb",
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

@export var small_tree_count: int = 640
@export var medium_tree_count: int = 960
@export var tall_tree_count: int = 440
@export var bush_count: int = 520
@export var small_rock_count: int = 220
@export var large_rock_count: int = 80
@export var safe_zone_radius: float = 10.0 ## keep clear around spawn/dummy
@export var rng_seed: int = 20260827

## Bit 10 -- a collision layer that exists purely so
## scripts/core/outline_visibility.gd can raycast-test whether vegetation
## is blocking the view of a player/enemy. Deliberately NOT part of any
## movement collision mask, so this never makes trees/bushes/rocks solid
## to walk through -- it only makes them detectable as "something is in
## the way" for the outline effect.
const VISION_BLOCKER_COLLISION_LAYER: int = 1 << 9
const VISION_BLOCKER_RADIUS: float = 0.6 ## generic per-item radius before scale_factor; doesn't need to match each asset's exact silhouette
const VISION_BLOCKER_HEIGHT: float = 3.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_scatter(TREE_SCENES_SMALL, small_tree_count, rng, 1.3, 2.2)
	_scatter(TREE_SCENES_MEDIUM, medium_tree_count, rng, 2.8, 4.5)
	_scatter(TREE_SCENES_TALL, tall_tree_count, rng, 4.0, 6.5)
	_scatter(BUSH_SCENES, bush_count, rng, 0.8, 1.6)
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
		# Uniform-by-area sampling within a disk (radius = R * sqrt(u), the
		# standard way to avoid center-clustering) out to
		# TerrainHeight.MOUNTAIN_START_RADIUS, so vegetation stops right at
		# the foot of the mountain ring instead of continuing onto it.
		var angle := rng.randf_range(0.0, TAU)
		var radius := sqrt(rng.randf()) * TerrainHeight.MOUNTAIN_START_RADIUS
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		if radius < safe_zone_radius:
			continue
		if TerrainHeight.is_water(x, z):
			continue
		if TerrainHeight.is_clearing(x, z):
			continue

		var y := TerrainHeight.get_height(x, z)
		var scene: PackedScene = scenes[rng.randi_range(0, scenes.size() - 1)]
		var inst: Node3D = scene.instantiate()
		add_child(inst)

		var scale_factor := rng.randf_range(min_scale, max_scale)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		basis = basis.scaled(Vector3.ONE * scale_factor)
		inst.transform = Transform3D(basis, Vector3(x, y, z))
		_add_vision_blocker(inst)
		placed += 1

## A simple cylinder on its own dedicated collision layer -- see
## VISION_BLOCKER_COLLISION_LAYER -- so outline_visibility.gd can detect
## this item as an obstruction without it ever affecting movement. Sized in
## inst's own local space (no manual scale multiply) since inst's transform
## already carries scale_factor and StaticBody3D/CollisionShape3D inherit
## that from their parent like any other node.
func _add_vision_blocker(inst: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = VISION_BLOCKER_COLLISION_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = VISION_BLOCKER_RADIUS
	cylinder.height = VISION_BLOCKER_HEIGHT
	shape.shape = cylinder
	shape.position.y = cylinder.height * 0.5
	body.add_child(shape)
	inst.add_child(body)
