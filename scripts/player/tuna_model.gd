extends Node3D

## Photo-textured tuna, not primitive-mesh geometry -- a stakeholder
## (animal enthusiast) flagged that the all-primitives version didn't read
## as a real tuna, specifically asking for the snout/fin/tail outline and a
## photo texture mirrored onto both flanks. Two subdivided sheets (one per
## side) share the same real-tuna photo (assets/textures/tuna_side.png, see
## assets/textures/ATTRIBUTION.md for the public-domain source). Each sheet
## is inflated outward by an elliptical thickness profile -- full-bodied
## through the middle, tapering smoothly toward the head, tail, and
## dorsal/belly edges -- so the body reads as a rounded cylinder instead of
## a flat cardboard cutout, while the fins (outside the body core, where the
## bulge fades to zero) stay flat. The photo's silhouette already covers the
## snout, dorsal/pectoral/anal fins, finlets, and forked tail, so there's no
## separate fin geometry to build.
##
## Authored facing +Z to match the rest of the project's model convention --
## swim_controller.gd negates X/Z scale on the model to align it to this
## project's -Z-forward movement. Built under a "Visual" child (rather than
## directly on self) with an extra 180-degree flip, since
## swim_controller.gd's _spawn_model() overwrites this node's own transform
## right after instancing it, which would silently erase a rotation set here.

const TEXTURE_PATH := "res://assets/textures/tuna_side.png"

## The source photo is head-on-the-left, tail-on-the-right; LENGTH/HEIGHT
## match its cropped aspect ratio (1024x378) so the fish isn't stretched.
const LENGTH := 1.4
const HEIGHT := 0.517
const SIDE_GAP := 0.04 ## how far each flank sits from the centerline

## How far the body bulges outward from each flank's base plane at its
## fattest point (mid-body). Total body width ~= 2 * (SIDE_GAP + this).
const MAX_HALF_THICKNESS := 0.11
## The photo is taller than the body itself (dorsal/anal fins stick out top
## and bottom), so only the central band of the image height gets inflated;
## beyond it the sheet stays flat for the fins.
const BODY_HALF_HEIGHT_FRACTION := 0.55
const LENGTH_SEGMENTS := 32
const HEIGHT_SEGMENTS := 12

## Interior core fill (see _build_core).
const CORE_RING_SEGMENTS := 16
const CORE_MAX_U := 0.82 ## stop before the tail fork's transparent middle
const CORE_HEIGHT_SHRINK := 0.8 ## keep safely inside the opaque silhouette
const CORE_WIDTH_RATIO := 0.7 ## a tuna is narrower than it is deep
const CORE_MIN_HALF_HEIGHT := 0.03
const CORE_INSET := 0.004 ## keep the core just inside the flank sheets

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
	# Default (CULL_BACK), not CULL_DISABLED -- each quad's winding already
	# faces outward on its own physical side (verified below), and with only
	# ~0.08 units between the two flanks, rendering backfaces too caused the
	# far quad's unlit backface to bleed through/z-fight with the near one,
	# which read as "one side right, the other facing backwards."

	# Right flank: faces +X. Left flank: faces -X (different winding order,
	# so each only renders when viewed from its own physical side). Both use
	# the IDENTICAL (non-flipped) UV mapping: an earlier version flipped U
	# for the left flank meaning to "mirror" it, but a flat 2D side-profile
	# photo has no genuine left-right content to mirror -- flipping U instead
	# moved that flank's head content to the opposite (tail) end of the
	# geometry, so the two flanks' heads landed a full body-length apart.
	# Identical UVs on both, each only visible from its own side via culling,
	# is what actually gives a consistent, correctly-aligned result from
	# either viewing angle.
	_make_side_sheet(root, 1.0, mat)
	_make_side_sheet(root, -1.0, mat)
	_build_core(root, texture)

## The two sheets never close across the centerline, so from dead ahead or
## dead astern (the chase camera's angle) the fish read as a hollow lens
## outline you could see straight through. This dark solid fills the
## interior. Its profile is derived from the photo's own alpha channel --
## for each image column, the longest contiguous opaque run gives that
## slice's body center and depth, and the core gets a shrunken elliptical
## ring there -- so it follows the real silhouette (deep near the head,
## thin at the peduncle) instead of a hand-guessed ellipsoid, which poked
## out through the transparent texels above the tail. Each ring vertex is
## additionally clamped to sit just inside the flank sheets so the core can
## never occlude the photo.
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
				continue # still before the snout proper; keep scanning
			break # body has thinned out toward the tail; stop the core here
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
	# Shallow domed end caps, in their own smooth group -- flat caps sharing
	# the rings' smooth group averaged normals across the 90-degree cap edge
	# and rendered as recessed hole-looking disks.
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
	mat.albedo_color = Color(0.22, 0.24, 0.27)
	mat.roughness = 0.8
	# The core is a closed-ish solid whose winding isn't hand-verified like
	# the sheets' -- double-sided rendering is safe here (no coplanar twin
	# surface to bleed through) and removes the risk entirely.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Core"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

## Outward bulge at a given point on the flank. An ellipse cross-section
## vertically (rounded back-to-belly) crossed with a blunt superellipse
## profile lengthwise (stays near full thickness through the mid-body, then
## rounds off toward snout and tail) -- a rough cylinder with smoothed ends.
## Returns 0 outside the body core so the fin regions of the photo stay flat.
func _half_thickness(y: float, z: float) -> float:
	var yn := absf(y) / (HEIGHT / 2.0 * BODY_HALF_HEIGHT_FRACTION)
	if yn >= 1.0:
		return 0.0
	var cross_section := sqrt(1.0 - yn * yn)
	var zn := absf(z) / (LENGTH / 2.0)
	var length_profile := sqrt(maxf(0.0, 1.0 - pow(zn, 2.5)))
	return MAX_HALF_THICKNESS * cross_section * length_profile

## Analytic surface normal for the sheet x = side * (SIDE_GAP + B(y, z)):
## the gradient of x - side*B is (1, -side*dB/dy, -side*dB/dz); orienting it
## outward for either side collapses to (side, -dB/dy, -dB/dz). Derivatives
## via central differences.
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
		var y := half_h - v * HEIGHT # v=0 is the top of the photo
		for c in range(cols):
			var u := c / float(LENGTH_SEGMENTS)
			# Head at +Z, tail at -Z (this project's authored-facing
			# convention); u=0 is the photo's head end.
			var z := half_l - u * LENGTH
			var x := side * (SIDE_GAP + _half_thickness(y, z))
			vertices.append(Vector3(x, y, z))
			normals.append(_sheet_normal(side, y, z))
			uvs.append(Vector2(u, v))

	# Per-cell triangle winding lifted directly from the previous flat-quad
	# version, whose facing was verified via a headless debug script --
	# (bl, tl, br)/(br, tl, tr) faces +X, (bl, br, tl)/(br, tr, tl) faces -X.
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

## anim_player is added under `root` (the flipped Visual node), not self, so
## its animation tracks' NodePaths (relative to the AnimationPlayer's parent)
## resolve against the Visual node itself.
func _build_animations(root: Node3D) -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	root.add_child(anim_player)

	var library := AnimationLibrary.new()
	library.add_animation("Swim_Idle", _make_swim_animation(1.1, 10.0))
	library.add_animation("Fast_Swim", _make_swim_animation(0.45, 18.0))
	library.add_animation("Bite", _make_bite_animation())
	library.add_animation("Death", _make_death_animation())
	library.add_animation("HitReact", _make_hit_react_animation())
	anim_player.add_animation_library("", library)

## There's no separate Tail node to wag anymore -- the tail is baked into
## the flat photo cutout -- so swimming motion is a whole-body side-to-side
## sway instead of a tail-only wag.
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

## A quick forward head-lunge, timed to line up with tuna_species.tres's
## attack_hit_*_fraction the same way every other species' attack is.
func _make_bite_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.4
	anim.loop_mode = Animation.LOOP_NONE
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:position:z"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.15, 0.3)
	anim.track_insert_key(track, 0.28, 0.3)
	anim.track_insert_key(track, 0.4, 0.0)
	return anim

func _make_death_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.8
	anim.loop_mode = Animation.LOOP_NONE
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:rotation:z"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.5, deg_to_rad(85))
	anim.track_insert_key(track, 0.8, deg_to_rad(90))
	return anim

func _make_hit_react_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.3
	anim.loop_mode = Animation.LOOP_NONE
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:rotation:x"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.1, deg_to_rad(-20))
	anim.track_insert_key(track, 0.3, 0.0)
	return anim
