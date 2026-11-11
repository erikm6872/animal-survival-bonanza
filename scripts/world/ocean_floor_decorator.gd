extends Node3D

## Scatters rocks, swaying seaweed, and coral across the ocean seafloor,
## height-sampled from OceanHeight so everything sits on the floor --
## the underwater counterpart of biome_populator.gd. Fixed seed so the
## layout is stable across runs. Also hides a few fixed-position easter
## eggs (see _place_easter_eggs).
##
## Nothing here gets collision: the swim controller's seafloor clearance
## already keeps the player just above the floor, and collision on decor
## would snag the swim clamp rather than add anything.

const SEED := 20261110
const SCATTER_HALF := 95.0 ## floor is 200x200; keep decor off the very edge

## Rocks reuse the CC0 nature-kit models already shipped for the land map.
const ROCK_SCENES_LARGE: Array[String] = [
	"res://assets/models/nature-kit/rock_largeA.glb",
	"res://assets/models/nature-kit/rock_largeC.glb",
	"res://assets/models/nature-kit/rock_largeE.glb",
	"res://assets/models/nature-kit/rock_tallB.glb",
	"res://assets/models/nature-kit/rock_tallD.glb",
	"res://assets/models/nature-kit/rock_tallH.glb",
]
const ROCK_SCENES_SMALL: Array[String] = [
	"res://assets/models/nature-kit/rock_smallA.glb",
	"res://assets/models/nature-kit/rock_smallC.glb",
	"res://assets/models/nature-kit/rock_smallE.glb",
	"res://assets/models/nature-kit/rock_smallFlatA.glb",
	"res://assets/models/nature-kit/rock_smallTopA.glb",
]
const LARGE_ROCK_COUNT := 45
const SMALL_ROCK_COUNT := 60

const SEAWEED_PATCH_COUNT := 42
const SEAWEED_BLADES_PER_PATCH := 6
const BLADE_HEIGHT := 2.0

const BRANCH_CORAL_COUNT := 16
const BRAIN_CORAL_COUNT := 12
const FAN_CORAL_COUNT := 14

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = SEED
	_scatter_rocks()
	_scatter_seaweed()
	_scatter_coral()
	_place_easter_eggs()

func _random_floor_pos() -> Vector3:
	var x := _rng.randf_range(-SCATTER_HALF, SCATTER_HALF)
	var z := _rng.randf_range(-SCATTER_HALF, SCATTER_HALF)
	return Vector3(x, OceanHeight.get_seafloor_height(x, z), z)

func _scatter_rocks() -> void:
	var large_scenes: Array[PackedScene] = []
	for path in ROCK_SCENES_LARGE:
		large_scenes.append(load(path))
	var small_scenes: Array[PackedScene] = []
	for path in ROCK_SCENES_SMALL:
		small_scenes.append(load(path))

	for i in LARGE_ROCK_COUNT:
		var rock: Node3D = large_scenes[_rng.randi() % large_scenes.size()].instantiate()
		var pos := _random_floor_pos()
		var s := _rng.randf_range(1.5, 3.5)
		rock.position = pos + Vector3(0, -0.2 * s, 0) # settle into the sand
		rock.rotation.y = _rng.randf_range(0.0, TAU)
		rock.scale = Vector3(s, s * _rng.randf_range(0.7, 1.2), s)
		add_child(rock)
	for i in SMALL_ROCK_COUNT:
		var rock: Node3D = small_scenes[_rng.randi() % small_scenes.size()].instantiate()
		var pos := _random_floor_pos()
		var s := _rng.randf_range(0.8, 1.8)
		rock.position = pos + Vector3(0, -0.1 * s, 0)
		rock.rotation.y = _rng.randf_range(0.0, TAU)
		rock.scale = Vector3(s, s, s)
		add_child(rock)

## One MultiMesh of tapered blades; the sway lives entirely in
## shaders/seaweed.gdshader's vertex pass, so hundreds of blades animate
## with zero per-frame script work.
func _scatter_seaweed() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _build_blade_mesh()
	multimesh.instance_count = SEAWEED_PATCH_COUNT * SEAWEED_BLADES_PER_PATCH

	var idx := 0
	for p in SEAWEED_PATCH_COUNT:
		var center := _random_floor_pos()
		for b in SEAWEED_BLADES_PER_PATCH:
			var offset := Vector3(_rng.randf_range(-0.9, 0.9), 0, _rng.randf_range(-0.9, 0.9))
			var x := center.x + offset.x
			var z := center.z + offset.z
			var pos := Vector3(x, OceanHeight.get_seafloor_height(x, z) - 0.05, z)
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
			basis = basis.scaled(Vector3(
				_rng.randf_range(0.7, 1.3),
				_rng.randf_range(0.6, 1.6),
				_rng.randf_range(0.7, 1.3)))
			multimesh.set_instance_transform(idx, Transform3D(basis, pos))
			idx += 1

	var instance := MultiMeshInstance3D.new()
	instance.name = "Seaweed"
	instance.multimesh = multimesh
	add_child(instance)

## A flat tapered strip, root at y=0, BLADE_HEIGHT tall, swayed by the
## seaweed shader. Double-sided via the shader's cull_disabled.
func _build_blade_mesh() -> ArrayMesh:
	const ROWS := 6
	const ROOT_HALF_WIDTH := 0.11
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for r in range(ROWS + 1):
		var t := r / float(ROWS)
		var y := t * BLADE_HEIGHT
		var hw := ROOT_HALF_WIDTH * (1.0 - t * 0.85)
		# A gentle built-in S-curve so blades don't look like rulers
		# even in the instant before the sway kicks in.
		var x_off := sin(t * PI) * 0.06
		vertices.append(Vector3(-hw + x_off, y, 0))
		vertices.append(Vector3(hw + x_off, y, 0))
		normals.append(Vector3(0, 0, 1))
		normals.append(Vector3(0, 0, 1))
	for r in range(ROWS):
		var i0 := r * 2
		indices.append_array([i0, i0 + 1, i0 + 2, i0 + 2, i0 + 1, i0 + 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/seaweed.gdshader")
	mesh.surface_set_material(0, mat)
	return mesh

func _scatter_coral() -> void:
	_scatter_multimesh("BranchCoralOrange", _build_branch_coral_mesh(Color(0.9, 0.45, 0.15)),
		BRANCH_CORAL_COUNT / 2, 0.8, 1.8)
	_scatter_multimesh("BranchCoralMagenta", _build_branch_coral_mesh(Color(0.8, 0.25, 0.5)),
		BRANCH_CORAL_COUNT / 2, 0.8, 1.8)
	_scatter_multimesh("BrainCoral", _build_brain_coral_mesh(), BRAIN_CORAL_COUNT, 0.8, 2.2)
	_scatter_multimesh("FanCoral", _build_fan_coral_mesh(), FAN_CORAL_COUNT, 0.9, 1.9)

func _scatter_multimesh(node_name: String, mesh: Mesh, count: int, scale_min: float, scale_max: float) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	for i in count:
		var pos := _random_floor_pos() + Vector3(0, -0.05, 0)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var s := _rng.randf_range(scale_min, scale_max)
		basis = basis.scaled(Vector3(s, s * _rng.randf_range(0.85, 1.15), s))
		multimesh.set_instance_transform(i, Transform3D(basis, pos))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	add_child(instance)

## A trunk with a crown of tilted branches, merged into one mesh via
## SurfaceTool.append_from so a whole coral is a single surface.
func _build_branch_coral_mesh(color: Color) -> ArrayMesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.085
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1

	var st := SurfaceTool.new()
	st.append_from(cyl, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)))
	const BRANCHES := 5
	for i in BRANCHES:
		var yaw := TAU * i / BRANCHES
		var tilt := deg_to_rad(38.0 + 7.0 * (i % 2))
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		basis = basis.scaled(Vector3(0.6, 0.65, 0.6))
		var origin := Vector3(0, 0.55 + 0.08 * i, 0) + basis * Vector3(0, 0.3, 0)
		st.append_from(cyl, 0, Transform3D(basis, origin))

	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.surface_set_material(0, mat)
	return mesh

func _build_brain_coral_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 0.62 # squashed dome
	sphere.radial_segments = 12
	sphere.rings = 6
	var st := SurfaceTool.new()
	st.append_from(sphere, 0, Transform3D.IDENTITY)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.62, 0.5)
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)
	return mesh

## An upright half-disc fan.
func _build_fan_coral_mesh() -> ArrayMesh:
	const SEGMENTS := 8
	const RADIUS := 0.7
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	normals.append(Vector3(0, 0, 1))
	for i in range(SEGMENTS + 1):
		var a := PI * i / SEGMENTS
		vertices.append(Vector3(cos(a) * RADIUS, sin(a) * RADIUS, 0))
		normals.append(Vector3(0, 0, 1))
	for i in range(SEGMENTS):
		indices.append_array([0, i + 2, i + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.3, 0.72)
	mat.roughness = 0.85
	# A single flat fan with no twin surface behind it -- double-sided is
	# safe here, same reasoning as the seaweed blades.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh

## Fixed-position secrets, deliberately NOT drawn from _rng so adding or
## retuning scatter counts above never moves them.
func _place_easter_eggs() -> void:
	_place_treasure_chest(Vector3(58, 0, 43)) # sandy shallows ring
	_place_rubber_duck(Vector3(-61, 0, -48)) # deep water
	_place_sunken_anchor(Vector3(24, 0, -70))

## A chest sunk nose-down into the sand with only the lid and one gold
## band showing, out in the shallows where the floor reads as sand.
func _place_treasure_chest(pos: Vector3) -> void:
	var chest := Node3D.new()
	chest.name = "TreasureChest"

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.26, 0.12)
	wood.roughness = 0.9
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.78, 0.25)
	# Low metallic: there's no bright sky to reflect underwater, so high
	# metallic just rendered the band near-black.
	gold.metallic = 0.2
	gold.roughness = 0.4

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.9, 0.55, 0.6)
	base_mesh.material = wood
	base.mesh = base_mesh
	chest.add_child(base)

	var band := MeshInstance3D.new()
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.14, 0.58, 0.64)
	band_mesh.material = gold
	band.mesh = band_mesh
	chest.add_child(band)

	var lid := MeshInstance3D.new()
	var lid_mesh := CylinderMesh.new()
	lid_mesh.top_radius = 0.3
	lid_mesh.bottom_radius = 0.3
	lid_mesh.height = 0.9
	lid_mesh.radial_segments = 10
	lid_mesh.material = wood
	lid.mesh = lid_mesh
	lid.rotation.z = PI / 2.0 # cylinder axis along the chest's length
	lid.position.y = 0.275
	chest.add_child(lid)

	# The chest sits on the shallows ramp (~25 degrees); a straight vertical
	# sink leaves the whole downhill face exposed, so align the chest to the
	# local floor normal and sink along it for an even burial -- only the
	# lid dome and a sliver of the gold band left showing.
	var floor_y := OceanHeight.get_seafloor_height(pos.x, pos.z)
	var n := _floor_normal(pos.x, pos.z)
	chest.basis = Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, deg_to_rad(35))
	chest.position = Vector3(pos.x, floor_y, pos.z) - n * 0.25
	add_child(chest)

func _floor_normal(x: float, z: float) -> Vector3:
	var e := 0.5
	var hx := OceanHeight.get_seafloor_height(x + e, z) - OceanHeight.get_seafloor_height(x - e, z)
	var hz := OceanHeight.get_seafloor_height(x, z + e) - OceanHeight.get_seafloor_height(x, z - e)
	return Vector3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)).normalized()

## Every ocean needs one.
func _place_rubber_duck(pos: Vector3) -> void:
	var duck := Node3D.new()
	duck.name = "RubberDuck"

	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(0.98, 0.83, 0.1)
	yellow.roughness = 0.4
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.95, 0.5, 0.1)
	orange.roughness = 0.5

	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.25
	body_mesh.height = 0.4
	body_mesh.material = yellow
	body.mesh = body_mesh
	duck.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.14
	head_mesh.height = 0.28
	head_mesh.material = yellow
	head.mesh = head_mesh
	head.position = Vector3(0, 0.3, 0.16)
	duck.add_child(head)

	var beak := MeshInstance3D.new()
	var beak_mesh := BoxMesh.new()
	beak_mesh.size = Vector3(0.1, 0.05, 0.12)
	beak_mesh.material = orange
	beak.mesh = beak_mesh
	beak.position = Vector3(0, 0.28, 0.3)
	duck.add_child(beak)

	var floor_y := OceanHeight.get_seafloor_height(pos.x, pos.z)
	duck.position = Vector3(pos.x, floor_y + 0.15, pos.z)
	duck.rotation.y = deg_to_rad(-60)
	add_child(duck)

func _place_sunken_anchor(pos: Vector3) -> void:
	var anchor := Node3D.new()
	anchor.name = "SunkenAnchor"

	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.32, 0.34, 0.38)
	iron.metallic = 0.15 # same underwater-metallic caveat as the chest gold
	iron.roughness = 0.65

	var shank := MeshInstance3D.new()
	var shank_mesh := CylinderMesh.new()
	shank_mesh.top_radius = 0.06
	shank_mesh.bottom_radius = 0.06
	shank_mesh.height = 1.4
	shank_mesh.material = iron
	shank.mesh = shank_mesh
	shank.position.y = 0.7
	anchor.add_child(shank)

	var stock := MeshInstance3D.new()
	var stock_mesh := CylinderMesh.new()
	stock_mesh.top_radius = 0.05
	stock_mesh.bottom_radius = 0.05
	stock_mesh.height = 0.7
	stock_mesh.material = iron
	stock.mesh = stock_mesh
	stock.rotation.z = PI / 2.0
	stock.position.y = 1.2
	anchor.add_child(stock)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.07
	ring_mesh.outer_radius = 0.14
	ring_mesh.material = iron
	ring.mesh = ring_mesh
	ring.rotation.x = PI / 2.0
	ring.position.y = 1.48
	anchor.add_child(ring)

	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := CylinderMesh.new()
		arm_mesh.top_radius = 0.055
		arm_mesh.bottom_radius = 0.055
		arm_mesh.height = 0.65
		arm_mesh.material = iron
		arm.mesh = arm_mesh
		arm.rotation.z = side * deg_to_rad(125)
		arm.position = Vector3(side * 0.25, 0.1, 0)
		anchor.add_child(arm)

	var floor_y := OceanHeight.get_seafloor_height(pos.x, pos.z)
	anchor.position = Vector3(pos.x, floor_y + 0.1, pos.z)
	# Toppled onto its side, flukes dug into the sand.
	anchor.rotation = Vector3(0, deg_to_rad(30), deg_to_rad(-62))
	add_child(anchor)
