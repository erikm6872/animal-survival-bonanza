extends Node3D

## Builds the visible water meshes (ponds + river) at runtime, matching the
## basins TerrainHeight carves into the terrain so the water surface always
## lines up with the ground instead of floating or clipping. Visual only —
## no swimming collision yet.

const RIVER_LENGTH_HALF: float = 100.0
const RIVER_SEGMENTS: int = 50

func _ready() -> void:
	_build_river()
	for pond in TerrainHeight.PONDS:
		_build_pond(pond["center"], pond["radius"], pond["water_level"])

func _build_pond(center: Vector2, radius: float, water_level: float) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.05
	cyl.radial_segments = 32

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = cyl
	mesh_inst.material_override = _water_material()
	add_child(mesh_inst)
	mesh_inst.position = Vector3(center.x, water_level, center.y)

func _build_river() -> void:
	var half_width := TerrainHeight.RIVER_HALF_WIDTH
	var points := RIVER_SEGMENTS + 1

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(points * 2)
	uvs.resize(points * 2)

	for i in points:
		var x := -RIVER_LENGTH_HALF + (2.0 * RIVER_LENGTH_HALF) * i / RIVER_SEGMENTS
		var z := TerrainHeight.river_center_z(x)
		vertices[i * 2] = Vector3(x, TerrainHeight.RIVER_WATER_LEVEL, z - half_width)
		vertices[i * 2 + 1] = Vector3(x, TerrainHeight.RIVER_WATER_LEVEL, z + half_width)
		uvs[i * 2] = Vector2(float(i) / RIVER_SEGMENTS, 0.0)
		uvs[i * 2 + 1] = Vector2(float(i) / RIVER_SEGMENTS, 1.0)

	var indices := PackedInt32Array()
	for i in RIVER_SEGMENTS:
		var i0 := i * 2
		var i1 := i0 + 1
		var i2 := i0 + 2
		var i3 := i0 + 3
		# Front-facing from above: cross(C-A, B-A) must point +Y.
		indices.append(i0); indices.append(i2); indices.append(i1)
		indices.append(i1); indices.append(i2); indices.append(i3)

	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = array_mesh
	mesh_inst.material_override = _water_material()
	add_child(mesh_inst)

func _water_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.45, 0.6, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED ## visible from below too, since there's no swimming collision to keep the player out yet
	mat.metallic = 0.2
	mat.roughness = 0.1
	return mat
