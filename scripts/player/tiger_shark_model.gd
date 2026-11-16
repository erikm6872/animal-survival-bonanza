extends Node3D

## Photo-textured Tiger Shark body, built with the exact same technique as
## the playable Tuna (scripts/player/tuna_model.gd): two subdivided flank
## sheets sharing one real-photo texture (assets/textures/tiger_shark_side.png,
## see assets/textures/ATTRIBUTION.md), inflated outward by an elliptical
## thickness profile for a rounded body instead of a flat cutout, plus a
## dark interior core (derived from the texture's own alpha silhouette) so
## the fish doesn't read as a hollow lens from dead ahead or astern. See
## tuna_model.gd's comments for the full rationale behind each piece --
## nothing here deviates from that technique, only the proportions and the
## source photo differ.
##
## Unlike the Tuna's photo, this one had no pre-made alpha cutout to start
## from -- the source NOAA photo shows the shark lying on a boat deck, and
## the deck's blue-grey tone sits close enough to the shark's own flank
## color that automatic background removal wasn't usable (see
## ATTRIBUTION.md). The texture is a hand-traced cutout instead; still a
## real, properly licensed photo, just extracted by hand rather than found
## pre-extracted.
##
## Authored facing +Z, flipped via a "Visual" child node -- same reasoning
## as tuna_model.gd: swim_controller.gd's _spawn_model() overwrites this
## node's own transform right after instancing it.
##
## A playable species, not hostile wildlife -- see tiger_shark_species.tres
## (resources/species/) and swimming_player.tscn, the same controller the
## Tuna uses.

const TEXTURE_PATH := "res://assets/textures/tiger_shark_side.png"

## Source photo is head-on-the-left, tail-on-the-right, cropped to its
## alpha bbox at 1200x318 -- LENGTH/HEIGHT match that aspect ratio so the
## shark isn't stretched.
const LENGTH := 2.3
const HEIGHT := 0.611
const SIDE_GAP := 0.05

## A tiger shark reads as noticeably chunkier/rounder than the Tuna's
## torpedo build -- proportionally bigger relative to LENGTH than the
## Tuna's MAX_HALF_THICKNESS (0.11 against a 1.4 LENGTH).
const MAX_HALF_THICKNESS := 0.2
const BODY_HALF_HEIGHT_FRACTION := 0.55
const LENGTH_SEGMENTS := 32
const HEIGHT_SEGMENTS := 12

const CORE_RING_SEGMENTS := 16
const CORE_MAX_U := 0.82
const CORE_HEIGHT_SHRINK := 0.8
const CORE_WIDTH_RATIO := 0.7
const CORE_MIN_HALF_HEIGHT := 0.04
const CORE_INSET := 0.005

var anim_player: AnimationPlayer

func _ready() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.rotate_y(PI)
	add_child(visual)

	_build_body(visual)
	_build_animations(visual)

func _build_body(root: Node3D) -> void:
	var texture: Texture2D = load(TEXTURE_PATH)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5

	_make_side_sheet(root, 1.0, mat)
	_make_side_sheet(root, -1.0, mat)
	_build_core(root, texture)
	_build_rim(root, texture)

func _half_thickness(y: float, z: float) -> float:
	var yn := absf(y) / (HEIGHT / 2.0 * BODY_HALF_HEIGHT_FRACTION)
	if yn >= 1.0:
		return 0.0
	var cross_section := sqrt(1.0 - yn * yn)
	var zn := absf(z) / (LENGTH / 2.0)
	var length_profile := sqrt(maxf(0.0, 1.0 - pow(zn, 2.5)))
	return MAX_HALF_THICKNESS * cross_section * length_profile

func _sheet_normal(side: float, y: float, z: float) -> Vector3:
	var e := 0.005
	var db_dy := (_half_thickness(y + e, z) - _half_thickness(y - e, z)) / (2.0 * e)
	var db_dz := (_half_thickness(y, z + e) - _half_thickness(y, z - e)) / (2.0 * e)
	return Vector3(side, -db_dy, -db_dz).normalized()

func _make_side_sheet(root: Node3D, side: float, mat: StandardMaterial3D) -> void:
	var half_l := LENGTH / 2.0
	var half_h := HEIGHT / 2.0
	var cols := LENGTH_SEGMENTS + 1
	var rows := HEIGHT_SEGMENTS + 1

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for r in range(rows):
		var v := r / float(HEIGHT_SEGMENTS)
		var y := half_h - v * HEIGHT
		for c in range(cols):
			var u := c / float(LENGTH_SEGMENTS)
			var z := half_l - u * LENGTH
			var x := side * (SIDE_GAP + _half_thickness(y, z))
			vertices.append(Vector3(x, y, z))
			normals.append(_sheet_normal(side, y, z))
			uvs.append(Vector2(u, v))

	var indices := PackedInt32Array()
	for r in range(HEIGHT_SEGMENTS):
		for c in range(LENGTH_SEGMENTS):
			var tl := r * cols + c
			var tr := tl + 1
			var bl := tl + cols
			var br := bl + 1
			if side > 0.0:
				indices.append_array([bl, tl, br, br, tl, tr])
			else:
				indices.append_array([bl, br, tl, br, tr, tl])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	array_mesh.surface_set_material(0, mat)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "FlankRight" if side > 0.0 else "FlankLeft"
	mesh_instance.mesh = array_mesh
	root.add_child(mesh_instance)

func _build_core(root: Node3D, texture: Texture2D) -> void:
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()
	var img_w := img.get_width()
	var img_h := img.get_height()
	var half_l := LENGTH / 2.0
	var half_h := HEIGHT / 2.0

	var ring_z: Array[float] = []
	var ring_yc: Array[float] = []
	var ring_hh: Array[float] = []
	for c in range(LENGTH_SEGMENTS + 1):
		var u := c / float(LENGTH_SEGMENTS)
		if u > CORE_MAX_U:
			break
		var col := int(round(u * (img_w - 1)))
		var best_start := -1
		var best_len := 0
		var run_start := -1
		for row in range(img_h + 1):
			var opaque := row < img_h and img.get_pixel(col, row).a > 0.5
			if opaque and run_start < 0:
				run_start = row
			elif not opaque and run_start >= 0:
				if row - run_start > best_len:
					best_len = row - run_start
					best_start = run_start
				run_start = -1
		var hh := (best_len / 2.0) / float(img_h - 1) * HEIGHT * CORE_HEIGHT_SHRINK
		if hh < CORE_MIN_HALF_HEIGHT:
			if ring_z.is_empty():
				continue
			break
		var center_row := best_start + best_len / 2.0
		ring_z.append(half_l - u * LENGTH)
		ring_yc.append(half_h - center_row / float(img_h - 1) * HEIGHT)
		ring_hh.append(hh)
	if ring_z.size() < 2:
		return

	var ring_pts: Array[PackedVector3Array] = []
	for i in range(ring_z.size()):
		var pts := PackedVector3Array()
		var hw := minf(SIDE_GAP + MAX_HALF_THICKNESS, ring_hh[i] * CORE_WIDTH_RATIO)
		for s in range(CORE_RING_SEGMENTS):
			var a := TAU * s / CORE_RING_SEGMENTS
			var y := ring_yc[i] + ring_hh[i] * sin(a)
			var limit := SIDE_GAP + _half_thickness(y, ring_z[i]) - CORE_INSET
			var x := clampf(hw * cos(a), -limit, limit)
			pts.append(Vector3(x, y, ring_z[i]))
		ring_pts.append(pts)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for i in range(ring_pts.size() - 1):
		for s in range(CORE_RING_SEGMENTS):
			var s2 := (s + 1) % CORE_RING_SEGMENTS
			var a := ring_pts[i][s]
			var b := ring_pts[i][s2]
			var c := ring_pts[i + 1][s]
			var d := ring_pts[i + 1][s2]
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(d)
	st.set_smooth_group(1)
	var head_center := Vector3(0, ring_yc[0], ring_z[0] + 0.03)
	var tail_center := Vector3(0, ring_yc[ring_yc.size() - 1], ring_z[ring_z.size() - 1] - 0.03)
	for s in range(CORE_RING_SEGMENTS):
		var s2 := (s + 1) % CORE_RING_SEGMENTS
		st.add_vertex(head_center)
		st.add_vertex(ring_pts[0][s])
		st.add_vertex(ring_pts[0][s2])
		st.add_vertex(tail_center)
		st.add_vertex(ring_pts[ring_pts.size() - 1][s2])
		st.add_vertex(ring_pts[ring_pts.size() - 1][s])
	st.generate_normals()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.34)
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Core"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

## The two flank sheets are textured rectangles clipped by alpha-scissor in
## the shader, not by real mesh edges -- so wherever the opaque silhouette
## (fin tips, snout, tail) runs close to the sheet's dorsal/ventral border,
## there's nothing but open air between the two flanks there, and a
## shallow enough viewing angle looks straight through the model at that
## edge. The Core fills the fat midsection but deliberately stays narrower
## than the silhouette (CORE_HEIGHT_SHRINK) and stops short of the tail
## fork (CORE_MAX_U), so it doesn't reach any of those edges either. This
## traces the silhouette's actual top and bottom boundary (same alpha scan
## _build_core uses, but the true extremes, not a shrunken approximation)
## and stitches a thin strip connecting the two flanks exactly along it --
## plus a closing quad at the nose and tail tip -- sealing the perimeter
## the Core was never meant to reach.
func _build_rim(root: Node3D, texture: Texture2D) -> void:
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()
	var img_w := img.get_width()
	var img_h := img.get_height()
	var half_l := LENGTH / 2.0
	var half_h := HEIGHT / 2.0

	var top_pts: Array[Vector2] = [] # (y, z) pairs along the dorsal boundary
	var bottom_pts: Array[Vector2] = [] # along the ventral boundary
	# Sampled once per image column (not LENGTH_SEGMENTS) -- the body mesh's
	# low-poly grid is coarse enough that a silhouette feature narrower than
	# one grid cell (a fin's leading/trailing edge rising steeply) can sit
	# entirely between two samples, letting the actual alpha-scissored edge
	# bulge past a Rim traced at that resolution and reopen the gap.
	for col in range(img_w):
		var u := col / float(img_w - 1)
		var top_row := -1
		var bottom_row := -1
		for row in range(img_h):
			if img.get_pixel(col, row).a > 0.5:
				if top_row < 0:
					top_row = row
				bottom_row = row
		if top_row < 0:
			continue
		var z := half_l - u * LENGTH
		top_pts.append(Vector2(half_h - top_row / float(img_h - 1) * HEIGHT, z))
		bottom_pts.append(Vector2(half_h - bottom_row / float(img_h - 1) * HEIGHT, z))
	if top_pts.size() < 2:
		return

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.34)
	mat.roughness = 0.8
	# Thin and only ever seen near edge-on -- same double-sided reasoning
	# as the Core, not the flank sheets' winding-order approach.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_rim_strip(st, top_pts)
	_add_rim_strip(st, bottom_pts)
	# Nose and tail: a single-segment "strip" connecting the dorsal point
	# to the ventral point at that end closes the last open gap.
	_add_rim_strip(st, [top_pts[0], bottom_pts[0]])
	_add_rim_strip(st, [top_pts[top_pts.size() - 1], bottom_pts[bottom_pts.size() - 1]])
	st.generate_normals()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Rim"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

## side=+1 is the right flank's edge vertex at this boundary point,
## side=-1 the left flank's -- the identical inflation formula the flank
## sheets themselves use, so the rim meets them with no step.
func _rim_vertex(side: float, yz: Vector2) -> Vector3:
	var y := yz.x
	var z := yz.y
	return Vector3(side * (SIDE_GAP + _half_thickness(y, z)), y, z)

func _add_rim_strip(st: SurfaceTool, points: Array) -> void:
	for i in range(points.size() - 1):
		var r0 := _rim_vertex(1.0, points[i])
		var l0 := _rim_vertex(-1.0, points[i])
		var r1 := _rim_vertex(1.0, points[i + 1])
		var l1 := _rim_vertex(-1.0, points[i + 1])
		st.add_vertex(r0)
		st.add_vertex(l0)
		st.add_vertex(r1)
		st.add_vertex(r1)
		st.add_vertex(l0)
		st.add_vertex(l1)

func _build_animations(root: Node3D) -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	root.add_child(anim_player)
	var library := AnimationLibrary.new()
	library.add_animation("Swim_Idle", _make_swim_animation(1.5, 7.0))
	library.add_animation("Fast_Swim", _make_swim_animation(0.6, 14.0))
	library.add_animation("Bite", _make_bite_animation())
	library.add_animation("Death", _make_death_animation())
	library.add_animation("HitReact", _make_hit_react_animation())
	anim_player.add_animation_library("", library)

func _make_swim_animation(cycle_length: float, max_angle_deg: float) -> Animation:
	var anim := Animation.new()
	anim.length = cycle_length
	anim.loop_mode = Animation.LOOP_LINEAR

	var max_angle := deg_to_rad(max_angle_deg)
	var body_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(body_track, NodePath(".:rotation:y"))
	anim.track_insert_key(body_track, 0.0, 0.0)
	anim.track_insert_key(body_track, cycle_length * 0.25, -max_angle)
	anim.track_insert_key(body_track, cycle_length * 0.5, 0.0)
	anim.track_insert_key(body_track, cycle_length * 0.75, max_angle)
	anim.track_insert_key(body_track, cycle_length, 0.0)

	return anim

func _make_bite_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.5
	anim.loop_mode = Animation.LOOP_NONE
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:position:z"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.18, 0.45)
	anim.track_insert_key(track, 0.32, 0.45)
	anim.track_insert_key(track, 0.5, 0.0)
	return anim

func _make_death_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.9
	anim.loop_mode = Animation.LOOP_NONE
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:rotation:z"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.55, deg_to_rad(80))
	anim.track_insert_key(track, 0.9, deg_to_rad(90))
	return anim

func _make_hit_react_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.3
	anim.loop_mode = Animation.LOOP_NONE
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:rotation:x"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.1, deg_to_rad(-15))
	anim.track_insert_key(track, 0.3, 0.0)
	return anim
