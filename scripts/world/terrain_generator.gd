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
	GameState.season_changed.connect(_on_season_changed)

## Height (and so collision) is unaffected by season, so _build_collision()
## doesn't need to re-run — just the mesh, to pick up the new vertex colors.
## Rebuilds the geometry too rather than patching colors in place; simpler,
## and cheap enough at this resolution to not matter.
func _on_season_changed(_is_winter: bool) -> void:
	_build_mesh()

func _build_mesh() -> void:
	var verts_per_side := RESOLUTION + 1
	var half := TERRAIN_SIZE / 2.0

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	vertices.resize(verts_per_side * verts_per_side)
	uvs.resize(verts_per_side * verts_per_side)
	colors.resize(verts_per_side * verts_per_side)

	for zi in verts_per_side:
		for xi in verts_per_side:
			var x := -half + xi * CELL_SIZE
			var z := -half + zi * CELL_SIZE
			var idx := zi * verts_per_side + xi
			var y := TerrainHeight.get_height(x, z)
			vertices[idx] = Vector3(x, y, z)
			uvs[idx] = Vector2(float(xi) / RESOLUTION, float(zi) / RESOLUTION)
			# Vertex colors are read back as linear, but the color constants
			# below are written the same way albedo_color normally is
			# (sRGB) — without this conversion everything reads far paler
			# than the numbers suggest, since sRGB->linear darkens midtones.
			colors[idx] = _height_color(y).srgb_to_linear()

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
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	array_mesh.surface_set_material(0, mat)

	mesh_instance.mesh = array_mesh

## Grass (or snow-covered ground, in winter) at valley height, blending to
## bare rock partway up the mountains and a snow cap near the peaks —
## otherwise the mountains would just be giant green hills.
func _height_color(h: float) -> Color:
	var low := Color(0.85, 0.88, 0.92) if GameState.is_winter else Color(0.35, 0.55, 0.28)
	var rock := Color(0.55, 0.55, 0.58) if GameState.is_winter else Color(0.45, 0.42, 0.4)
	var snow := Color(0.92, 0.93, 0.95)
	if h < 8.0:
		return low
	elif h < 24.0:
		return low.lerp(rock, smoothstep(8.0, 24.0, h))
	else:
		return rock.lerp(snow, smoothstep(24.0, 36.0, h))

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
