extends Node3D

## Builds the cave the player spawns/respawns in (see player_controller.gd
## and flight_controller.gd _respawn()/_reset_position(), which both target
## world origin). Built from the nature-kit's 1x1x1 cliff block pieces tiled
## into a hollow room, matching TerrainHeight's CAVE_HOLLOW_RADIUS/
## CAVE_MOUND_RADIUS mound so the room sits on the flat ground the mound
## hollows out, with the hillside rising around it.
##
## Walls are a single ring of blocks (interior cell left empty = the room);
## a separate floor/ceiling slab seals top and bottom since the ring alone
## only closes the sides. The south-wall center cell is left completely
## empty (no block at all) rather than using the kit's cliff_blockCave
## piece -- that piece's carved-hole axis isn't documented and there's no
## way to visually confirm its orientation in this environment, so an
## empty cell is used instead: a plain gap that's guaranteed to look like
## exactly what it collides like.

const BLOCK_SOLID := "res://assets/models/nature-kit/cliff_block_stone.glb"
const BOULDER_SCENES: Array[String] = [
	"res://assets/models/nature-kit/rock_largeA.glb",
	"res://assets/models/nature-kit/rock_largeB.glb",
	"res://assets/models/nature-kit/rock_largeC.glb",
	"res://assets/models/nature-kit/stone_largeA.glb",
	"res://assets/models/nature-kit/stone_largeB.glb",
]

const BLOCK_SCALE: float = 3.0 ## each 1x1x1 block becomes a 3m cube
const WALL_HEIGHT: float = BLOCK_SCALE
const SLAB_THICKNESS: float = 0.4
const ROOM_HALF_EXTENT: int = 1 ## grid runs -1..1 on both axes (3x3 blocks)

const MOVEMENT_LAYER: int = 1 ## bit 0 -- matches Terrain's collision_layer
const VISION_BLOCKER_LAYER: int = 1 << 9 ## bit 10 -- matches biome_populator.gd
const SOLID_COLLISION_LAYER: int = MOVEMENT_LAYER | VISION_BLOCKER_LAYER

const STONE_COLOR := Color(0.32, 0.29, 0.27)
const TORCH_COLOR := Color(1.0, 0.72, 0.42)

const RNG_SEED: int = 20260827

static var _stone_material: StandardMaterial3D

func _ready() -> void:
	var base_y := TerrainHeight.get_height(0.0, 0.0)
	global_position = Vector3(0.0, base_y, 0.0)

	_build_walls()
	_build_slab(-SLAB_THICKNESS * 0.5) # floor, top surface at local y = 0
	_build_slab(WALL_HEIGHT + SLAB_THICKNESS * 0.5) # ceiling, bottom surface at local y = WALL_HEIGHT
	_add_torchlight()
	_scatter_boulders()

func _get_stone_material() -> StandardMaterial3D:
	if _stone_material == null:
		_stone_material = StandardMaterial3D.new()
		_stone_material.albedo_color = STONE_COLOR
		_stone_material.roughness = 0.95
	return _stone_material

## Places one block per perimeter cell of a (2*ROOM_HALF_EXTENT+1) grid,
## leaving the interior hollow. The south wall's center cell (i=0,
## j=+ROOM_HALF_EXTENT, facing +Z, away from the relocated TrainingDummy) is
## skipped entirely -- that gap is the entrance.
func _build_walls() -> void:
	for i in range(-ROOM_HALF_EXTENT, ROOM_HALF_EXTENT + 1):
		for j in range(-ROOM_HALF_EXTENT, ROOM_HALF_EXTENT + 1):
			var is_perimeter := i == -ROOM_HALF_EXTENT or i == ROOM_HALF_EXTENT \
				or j == -ROOM_HALF_EXTENT or j == ROOM_HALF_EXTENT
			if not is_perimeter:
				continue
			var is_entrance := i == 0 and j == ROOM_HALF_EXTENT
			if is_entrance:
				continue
			_place_solid_block(Vector3(i * BLOCK_SCALE, 0.0, j * BLOCK_SCALE))

func _place_solid_block(local_pos: Vector3) -> void:
	var scene: PackedScene = load(BLOCK_SOLID)
	var inst: Node3D = scene.instantiate()
	add_child(inst)
	inst.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(BLOCK_SCALE, WALL_HEIGHT, BLOCK_SCALE)), local_pos)

	var body := StaticBody3D.new()
	body.collision_layer = SOLID_COLLISION_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BLOCK_SCALE, WALL_HEIGHT, BLOCK_SCALE)
	shape.shape = box
	shape.position.y = WALL_HEIGHT * 0.5
	body.add_child(shape)
	inst.add_child(body)

## A flat slab spanning the whole room footprint (plus a small margin) so the
## floor/ceiling stay solid and flat regardless of minor terrain noise, and
## the ceiling has no gap anywhere -- including right over the entrance --
## to keep direct sunlight out.
func _build_slab(local_y: float) -> void:
	var half_span := (ROOM_HALF_EXTENT + 0.5) * BLOCK_SCALE + 0.3
	var mesh := BoxMesh.new()
	mesh.size = Vector3(half_span * 2.0, SLAB_THICKNESS, half_span * 2.0)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, local_y, 0.0)
	mesh_instance.set_surface_override_material(0, _get_stone_material())
	add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.collision_layer = SOLID_COLLISION_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	body.add_child(shape)
	mesh_instance.add_child(body)

## Warm, dim interior light -- enough to see the room by, without washing out
## the "cave" feel; the flat global ambient (WorldEnvironment) still fills in
## the deep shadows a little further.
func _add_torchlight() -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, WALL_HEIGHT * 0.4, 0.0)
	light.light_color = TORCH_COLOR
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.shadow_enabled = true
	add_child(light)

## A few boulders on the mound's outer slope, skipping the entrance-facing
## arc so they don't block or hide the cave mouth.
func _scatter_boulders() -> void:
	var scenes: Array[PackedScene] = []
	for path in BOULDER_SCENES:
		scenes.append(load(path))

	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED

	var placed := 0
	var attempts := 0
	while placed < 7 and attempts < 70:
		attempts += 1
		var angle := rng.randf_range(0.0, TAU)
		# Entrance opens toward +Z (angle 0 in this x/z convention); keep
		# clear of it.
		var angle_from_entrance := wrapf(angle, -PI, PI)
		if absf(angle_from_entrance) < deg_to_rad(40.0):
			continue
		var radius := rng.randf_range(TerrainHeight.CAVE_HOLLOW_RADIUS + 0.5, TerrainHeight.CAVE_MOUND_RADIUS - 0.5)
		var x := sin(angle) * radius
		var z := cos(angle) * radius
		var y := TerrainHeight.get_height(x, z) - global_position.y

		var scene: PackedScene = scenes[rng.randi_range(0, scenes.size() - 1)]
		var inst: Node3D = scene.instantiate()
		add_child(inst)
		var scale_factor := rng.randf_range(1.4, 2.4)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_factor)
		inst.transform = Transform3D(basis, Vector3(x, y, z))
		placed += 1
