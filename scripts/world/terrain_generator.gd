extends StaticBody3D

## Builds a rolling-hills ground mesh + matching collision at runtime from
## TerrainHeight, replacing the old flat plane.

const TERRAIN_SIZE: float = 200.0
const RESOLUTION: int = 100 ## segments per side
const CELL_SIZE: float = TERRAIN_SIZE / RESOLUTION

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	_build_mesh()
	_build_collision()

func _build_mesh() -> void:
	var verts_per_side := RESOLUTION + 1
	var half := TERRAIN_SIZE / 2.0

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(verts_per_side * verts_per_side)
	uvs.resize(verts_per_side * verts_per_side)

	for zi in verts_per_side:
		for xi in verts_per_side:
			var x := -half + xi * CELL_SIZE
			var z := -half + zi * CELL_SIZE
			var idx := zi * verts_per_side + xi
			vertices[idx] = Vector3(x, TerrainHeight.get_height(x, z), z)
			uvs[idx] = Vector2(float(xi) / RESOLUTION, float(zi) / RESOLUTION)

	var indices := PackedInt32Array()
	indices.resize(RESOLUTION * RESOLUTION * 6)
	var ii := 0
	for zi in RESOLUTION:
		for xi in RESOLUTION:
			var i0 := zi * verts_per_side + xi
			var i1 := i0 + 1
			var i2 := i0 + verts_per_side
			var i3 := i2 + 1
			indices[ii] = i0; ii += 1
			indices[ii] = i1; ii += 1
			indices[ii] = i2; ii += 1
			indices[ii] = i1; ii += 1
			indices[ii] = i3; ii += 1
			indices[ii] = i2; ii += 1

	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		var face_normal := (c - a).cross(b - a).normalized()
		normals[indices[i]] += face_normal
		normals[indices[i + 1]] += face_normal
		normals[indices[i + 2]] += face_normal
	for i in normals.size():
		normals[i] = normals[i].normalized()

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.55, 0.28)
	array_mesh.surface_set_material(0, mat)

	mesh_instance.mesh = array_mesh

func _build_collision() -> void:
	var verts_per_side := RESOLUTION + 1
	var half := TERRAIN_SIZE / 2.0
	var map_data := PackedFloat32Array()
	map_data.resize(verts_per_side * verts_per_side)

	for zi in verts_per_side:
		for xi in verts_per_side:
			var x := -half + xi * CELL_SIZE
			var z := -half + zi * CELL_SIZE
			map_data[zi * verts_per_side + xi] = TerrainHeight.get_height(x, z)

	var shape := HeightMapShape3D.new()
	shape.map_width = verts_per_side
	shape.map_depth = verts_per_side
	shape.map_data = map_data
	collision_shape.shape = shape
	collision_shape.scale = Vector3(CELL_SIZE, 1.0, CELL_SIZE)
