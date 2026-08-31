extends Node3D

## Builds the visible water meshes (ponds + river) at runtime, matching the
## basins TerrainHeight carves into the terrain so the water surface always
## lines up with the ground instead of floating or clipping. Visual only —
## no swimming collision yet.

const RIVER_LENGTH_HALF: float = 100.0
const RIVER_SEGMENTS: int = 50 ## across the river's full length; segment count below the falls is split proportionally

func _ready() -> void:
	# Two flat ribbons — the low valley stretch and the higher "source"
	# stretch coming out of the mountains — bridged by a steep sloped ribbon
	# hugging the terrain's own carved drop at TerrainHeight.WATERFALL_X:
	# the falls.
	_build_river_segment(-RIVER_LENGTH_HALF, TerrainHeight.WATERFALL_X - WATERFALL_RISE_WIDTH, TerrainHeight.RIVER_WATER_LEVEL)
	_build_river_segment(TerrainHeight.WATERFALL_X, RIVER_LENGTH_HALF, TerrainHeight.RIVER_SOURCE_WATER_LEVEL)
	_build_waterfall()
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

func _build_river_segment(x_start: float, x_end: float, water_level: float) -> void:
	var half_width := TerrainHeight.RIVER_HALF_WIDTH
	var length := x_end - x_start
	var segments := maxi(2, roundi(RIVER_SEGMENTS * length / (2.0 * RIVER_LENGTH_HALF)))
	var points := segments + 1

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(points * 2)
	uvs.resize(points * 2)

	for i in points:
		var x := x_start + length * i / segments
		var z := TerrainHeight.river_center_z(x)
		vertices[i * 2] = Vector3(x, water_level, z - half_width)
		vertices[i * 2 + 1] = Vector3(x, water_level, z + half_width)
		uvs[i * 2] = Vector2(float(i) / segments, 0.0)
		uvs[i * 2 + 1] = Vector2(float(i) / segments, 1.0)

	var indices := PackedInt32Array()
	for i in segments:
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

## A steep ribbon (same construction as _build_river_segment, just over a
## short, steep span) that follows the actual rise from the valley water
## level up to the source water level — the falls. Two earlier attempts
## both went invisible: a flat quad placed exactly at WATERFALL_X ended up
## behind the terrain's own carved cliff there; a crossed pair of quads
## fixed that but, having no connection to the surrounding water, read as a
## stray floating shard from most angles instead of falling water; and a
## smoothstep-eased ribbon (this same approach, but eased) dipped below the
## terrain's own ramp partway through and got buried again.
##
## WATERFALL_X (80) lands exactly on a terrain grid vertex (CELL_SIZE is
## 200/100 = 2), so the terrain's rendered surface between x=WATERFALL_X-2
## and x=WATERFALL_X isn't a hard step — it's the one straight line
## connecting the low-bed vertex to the high-bed vertex. Matching that
## exactly with a **linear** (not eased) rise over the same x-span, offset
## by the same RIVER_BED_DEPTH used everywhere else water sits above its
## bed, keeps the ribbon parallel to and above the actual ground the whole
## way — same relationship the flat river/pond water already has to its bed.
const WATERFALL_RISE_WIDTH: float = 2.0 ## must match terrain_generator.gd's CELL_SIZE
const WATERFALL_SEGMENTS: int = 8

func _build_waterfall() -> void:
	var half_width := TerrainHeight.RIVER_HALF_WIDTH
	var bottom_y := TerrainHeight.RIVER_WATER_LEVEL
	var top_y := TerrainHeight.RIVER_SOURCE_WATER_LEVEL
	var x_start := TerrainHeight.WATERFALL_X - WATERFALL_RISE_WIDTH
	var x_end := TerrainHeight.WATERFALL_X
	var points := WATERFALL_SEGMENTS + 1

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(points * 2)
	uvs.resize(points * 2)

	for i in points:
		var t := float(i) / WATERFALL_SEGMENTS
		var x := lerpf(x_start, x_end, t)
		var z := TerrainHeight.river_center_z(x)
		var y := lerpf(bottom_y, top_y, t)
		vertices[i * 2] = Vector3(x, y, z - half_width)
		vertices[i * 2 + 1] = Vector3(x, y, z + half_width)
		uvs[i * 2] = Vector2(t, 0.0)
		uvs[i * 2 + 1] = Vector2(t, 1.0)

	var indices := PackedInt32Array()
	for i in WATERFALL_SEGMENTS:
		var i0 := i * 2
		var i1 := i0 + 1
		var i2 := i0 + 2
		var i3 := i0 + 3
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
