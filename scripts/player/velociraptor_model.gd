extends Node3D

## Photo-textured Velociraptor, built with the same technique as the
## playable Tuna/Tiger Shark (scripts/player/tuna_model.gd,
## tiger_shark_model.gd): two subdivided flank sheets sharing one real
## illustration (assets/textures/velociraptor_side.png, see
## assets/textures/ATTRIBUTION.md), inflated outward by an elliptical
## thickness profile, plus a dark interior core and rim derived from the
## texture's own alpha silhouette so the model doesn't read as a hollow lens
## from dead ahead or astern.
##
## Those two fish are torpedo-shaped with no limbs, so a single thickness
## profile centered on the vertical middle of the photo was enough. A biped
## has two anatomically distinct masses stacked in the same photo column --
## the torso/neck/tail above, the legs below -- and treating the whole
## column as one bulge would inflate the legs into a torso-sized sausage (a
## leg's full hip-to-foot opaque run is just as "tall" as the body is deep).
## So every alpha scan here (_half_thickness and _build_core) is split into
## two independent bands by a fixed row cutoff (LEG_ROW_FRACTION): rows above
## it profile the torso/neck/head/tail, rows below it profile the legs, each
## with their own measured center and depth per length-slice. Both bands
## taper to zero approaching their shared boundary, which leaves a soft,
## under-inflated "waist" at the hip height -- a visible but minor seam, not
## worth chasing further (see _half_thickness).
##
## Unlike the fish, this model stands on the ground: the photo's bottom edge
## (the feet) maps to y=0 and the top edge (the back/head) to y=HEIGHT,
## instead of straddling y=0 the way a mid-water swimmer does.
##
## Source illustration is head-on-the-left, tail-on-the-right (flipped from
## the original upload to match this project's existing texture convention),
## standing pose with both legs planted -- chosen over a more dynamic
## running-pose reference specifically because the legs attach to the belly
## with no daylight gap, which the single-contiguous-run assumption below
## depends on.
##
## Authored facing +Z, same as every imported model pack (see
## player_controller.gd's _spawn_model(): "Packs face +Z by default; flip
## X/Z to match this project's -Z-forward movement convention"). That flip
## is a full 180-degree turn (Basis.scaled(-1,1,-1) is numerically identical
## to a Y-axis rotation by PI), so it alone is enough to point a +Z-authored
## model at -Z -- no additional rotation needed here. Body geometry is still
## built under a "Visual" child (rather than directly on self), since
## player_controller.gd's _spawn_model() overwrites this node's own
## transform right after instancing it and would silently erase anything
## set here, but Visual itself is left at identity rotation.
##
## tuna_model.gd/tiger_shark_model.gd additionally rotate their Visual node
## by PI "to re-face +Z content at -Z" -- that second rotation cancels the
## controller's own flip straight back out (two 180-degree turns = net
## zero), leaving those models' heads on local +Z after all, not -Z. That
## pairing was carried over here at first and produced exactly that bug
## (head toward the camera while moving forward); removing the extra
## rotate_y(PI) fixed it. Left as-is for the fish rather than changed
## alongside this fix, since that's an unrelated correction to species this
## change wasn't asked to touch -- worth checking those two in-game too.

const TEXTURE_PATH := "res://assets/textures/velociraptor_side.png"

## Source photo cropped to its alpha bbox at 1200x393 -- LENGTH/HEIGHT match
## that aspect ratio so the model isn't stretched. LENGTH is picked as a
## plausible nose-to-tail-tip length in meters for a feathered dromaeosaur.
const LENGTH := 1.9
const HEIGHT := 0.6223
const SIDE_GAP := 0.035

## Row (as a 0..1 fraction of the photo's height, 0=top/back, 1=bottom/feet)
## that splits the torso band from the leg band. Picked by inspecting the
## actual photo: every leg column's opaque run reaches well past this row
## while every torso-only column (head, neck, tail) stays well above it, so
## the split lands in the gap between the two rather than slicing through
## either.
const LEG_ROW_FRACTION := 0.5

const TORSO_MAX_HALF_THICKNESS := 0.1
const TORSO_WIDTH_RATIO := 0.8
const TORSO_BAND_FRACTION := 0.85

## Legs read much "taller" than they are thick in a single column scan (a
## whole hip-to-foot run), so they get their own, much smaller depth cap
## rather than sharing the torso's.
const LEG_MAX_HALF_THICKNESS := 0.045
const LEG_WIDTH_RATIO := 0.3
const LEG_BAND_FRACTION := 0.85

const LENGTH_SEGMENTS := 40
const HEIGHT_SEGMENTS := 20

const CORE_RING_SEGMENTS := 12
const CORE_TORSO_WIDTH_RATIO := 0.7
const CORE_TORSO_MIN_HALF_HEIGHT := 0.018
const CORE_LEG_WIDTH_RATIO := 0.5
const CORE_LEG_MIN_HALF_HEIGHT := 0.012
const CORE_INSET := 0.004

## Per-length-segment profile, precomputed once in _build_body and reused by
## both _half_thickness (the flank bulge) and _build_core (the interior
## fill) -- one scan of the texture's alpha channel instead of two.
var _torso_center_y: PackedFloat32Array
var _torso_half_h: PackedFloat32Array
var _leg_center_y: PackedFloat32Array
var _leg_half_h: PackedFloat32Array

var anim_player: AnimationPlayer

func _ready() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	_build_body(visual)
	_build_animations(visual)

func _build_body(root: Node3D) -> void:
	var texture: Texture2D = load(TEXTURE_PATH)
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()

	_scan_profile(img)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5

	_make_side_sheet(root, 1.0, mat)
	_make_side_sheet(root, -1.0, mat)
	_build_core(root)
	_build_rim(root, img)
	_build_mouth_seal(root, img)

## For each length-segment slice, finds the longest contiguous opaque run
## within a row sub-range (same technique tuna_model.gd's _build_core uses
## for the whole column) -- once restricted to rows above LEG_ROW_FRACTION
## (torso: head/neck/body/tail), once below it (legs). A slice with no
## opaque pixels in that sub-range gets half_h = 0, which _half_thickness and
## _build_core both treat as "this band doesn't reach here."
func _scan_profile(img: Image) -> void:
	var img_w := img.get_width()
	var img_h := img.get_height()
	var cutoff_row := int(round(LEG_ROW_FRACTION * (img_h - 1)))

	_torso_center_y.resize(LENGTH_SEGMENTS + 1)
	_torso_half_h.resize(LENGTH_SEGMENTS + 1)
	_leg_center_y.resize(LENGTH_SEGMENTS + 1)
	_leg_half_h.resize(LENGTH_SEGMENTS + 1)

	for c in range(LENGTH_SEGMENTS + 1):
		var u := c / float(LENGTH_SEGMENTS)
		var col := int(round(u * (img_w - 1)))

		var torso := _longest_run(img, col, 0, cutoff_row)
		_torso_center_y[c] = HEIGHT - (torso.y / float(img_h - 1)) * HEIGHT
		_torso_half_h[c] = (torso.z / 2.0) / float(img_h - 1) * HEIGHT

		var legs := _longest_run(img, col, cutoff_row, img_h)
		_leg_center_y[c] = HEIGHT - (legs.y / float(img_h - 1)) * HEIGHT
		_leg_half_h[c] = (legs.z / 2.0) / float(img_h - 1) * HEIGHT

## Returns Vector3(unused, center_row, run_length) for the longest
## contiguous run of alpha>0.5 pixels in column `col`, rows [row_lo, row_hi).
func _longest_run(img: Image, col: int, row_lo: int, row_hi: int) -> Vector3:
	var best_start := -1
	var best_len := 0
	var run_start := -1
	for row in range(row_lo, row_hi + 1):
		var opaque := row < row_hi and img.get_pixel(col, row).a > 0.5
		if opaque and run_start < 0:
			run_start = row
		elif not opaque and run_start >= 0:
			if row - run_start > best_len:
				best_len = row - run_start
				best_start = run_start
			run_start = -1
	if best_len == 0:
		return Vector3.ZERO
	return Vector3(0.0, best_start + best_len / 2.0, best_len)

## Interpolates a precomputed per-slice profile array at an arbitrary z.
func _sample(arr: PackedFloat32Array, z: float) -> float:
	var half_l := LENGTH / 2.0
	var u := clampf((half_l - z) / LENGTH, 0.0, 1.0)
	var f := u * LENGTH_SEGMENTS
	var i0 := clampi(int(floor(f)), 0, LENGTH_SEGMENTS)
	var i1 := clampi(i0 + 1, 0, LENGTH_SEGMENTS)
	return lerpf(arr[i0], arr[i1], f - i0)

## Outward bulge at a given point on the flank -- the max of two
## independently-profiled lobes (torso, legs; see _scan_profile), each an
## elliptical cross-section vertically (rounded) crossed with the real
## measured depth lengthwise, clamped to that band's own thickness cap.
## Returns 0 outside both bands (wingtips/tail-tip feather fringe stay flat,
## same as the fish's fins).
func _half_thickness(y: float, z: float) -> float:
	var torso := _band_thickness(y, z, _sample(_torso_center_y, z), _sample(_torso_half_h, z),
		TORSO_BAND_FRACTION, TORSO_MAX_HALF_THICKNESS, TORSO_WIDTH_RATIO)
	var legs := _band_thickness(y, z, _sample(_leg_center_y, z), _sample(_leg_half_h, z),
		LEG_BAND_FRACTION, LEG_MAX_HALF_THICKNESS, LEG_WIDTH_RATIO)
	return maxf(torso, legs)

func _band_thickness(y: float, z: float, center_y: float, half_h: float,
		band_fraction: float, max_half_thickness: float, width_ratio: float) -> float:
	if half_h < 0.001:
		return 0.0
	var yn := absf(y - center_y) / (half_h * band_fraction)
	if yn >= 1.0:
		return 0.0
	var cross_section := sqrt(1.0 - yn * yn)
	var depth := minf(max_half_thickness, half_h * width_ratio)
	return depth * cross_section

func _sheet_normal(side: float, y: float, z: float) -> Vector3:
	var e := 0.005
	var db_dy := (_half_thickness(y + e, z) - _half_thickness(y - e, z)) / (2.0 * e)
	var db_dz := (_half_thickness(y, z + e) - _half_thickness(y, z - e)) / (2.0 * e)
	return Vector3(side, -db_dy, -db_dz).normalized()

func _make_side_sheet(root: Node3D, side: float, mat: StandardMaterial3D) -> void:
	var cols := LENGTH_SEGMENTS + 1
	var rows := HEIGHT_SEGMENTS + 1

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for r in range(rows):
		var v := r / float(HEIGHT_SEGMENTS)
		# v=0 is the top of the photo (back/head); y=HEIGHT there, y=0 at
		# the bottom (feet) -- the model stands on the ground, unlike the
		# fish's y=0-centered midline.
		var y := HEIGHT - v * HEIGHT
		for c in range(cols):
			var u := c / float(LENGTH_SEGMENTS)
			var z := LENGTH / 2.0 - u * LENGTH
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

## Fills both bands' interiors so the model doesn't read as a hollow lens
## from dead ahead/astern -- one tube for the torso/neck/head/tail, a second
## for the legs, built from the same precomputed profile _half_thickness
## uses. Each ring vertex is clamped to sit just inside the flank sheets.
func _build_core(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var built_any := false
	built_any = _build_core_band(st, _torso_center_y, _torso_half_h,
		CORE_TORSO_WIDTH_RATIO, CORE_TORSO_MIN_HALF_HEIGHT) or built_any
	built_any = _build_core_band(st, _leg_center_y, _leg_half_h,
		CORE_LEG_WIDTH_RATIO, CORE_LEG_MIN_HALF_HEIGHT) or built_any
	if not built_any:
		return
	st.generate_normals()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.27, 0.2)
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Core"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

## Appends one band's solid tube (rings + end caps) into `st`. Returns false
## if the band never exceeds min_half_height anywhere (nothing to build).
func _build_core_band(st: SurfaceTool, center_y: PackedFloat32Array, half_h: PackedFloat32Array,
		width_ratio: float, min_half_height: float) -> bool:
	var ring_z: Array[float] = []
	var ring_yc: Array[float] = []
	var ring_hh: Array[float] = []
	for c in range(LENGTH_SEGMENTS + 1):
		if half_h[c] < min_half_height:
			if ring_z.is_empty():
				continue # before this band has started yet
			break # band has thinned out; stop here
		var u := c / float(LENGTH_SEGMENTS)
		ring_z.append(LENGTH / 2.0 - u * LENGTH)
		ring_yc.append(center_y[c])
		ring_hh.append(half_h[c])
	if ring_z.size() < 2:
		return false

	var ring_pts: Array[PackedVector3Array] = []
	for i in range(ring_z.size()):
		var pts := PackedVector3Array()
		var hw := ring_hh[i] * width_ratio
		for s in range(CORE_RING_SEGMENTS):
			var a := TAU * s / CORE_RING_SEGMENTS
			var y := ring_yc[i] + ring_hh[i] * sin(a)
			var limit := SIDE_GAP + _half_thickness(y, ring_z[i]) - CORE_INSET
			var x := clampf(hw * cos(a), -limit, limit)
			pts.append(Vector3(x, y, ring_z[i]))
		ring_pts.append(pts)

	st.set_smooth_group(0)
	for i in range(ring_pts.size() - 1):
		for s in range(CORE_RING_SEGMENTS):
			var s2 := (s + 1) % CORE_RING_SEGMENTS
			var a := ring_pts[i][s]
			var b := ring_pts[i][s2]
			var c2 := ring_pts[i + 1][s]
			var d := ring_pts[i + 1][s2]
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c2)
			st.add_vertex(c2)
			st.add_vertex(b)
			st.add_vertex(d)
	st.set_smooth_group(-1)
	var head_center := Vector3(0, ring_yc[0], ring_z[0] + 0.02)
	var tail_center := Vector3(0, ring_yc[ring_yc.size() - 1], ring_z[ring_z.size() - 1] - 0.02)
	for s in range(CORE_RING_SEGMENTS):
		var s2 := (s + 1) % CORE_RING_SEGMENTS
		st.add_vertex(head_center)
		st.add_vertex(ring_pts[0][s])
		st.add_vertex(ring_pts[0][s2])
		st.add_vertex(tail_center)
		st.add_vertex(ring_pts[ring_pts.size() - 1][s2])
		st.add_vertex(ring_pts[ring_pts.size() - 1][s])
	return true

## Traces the true top/bottom alpha boundary per image column (full
## resolution, not per mesh segment) and stitches a thin strip connecting
## the two flanks along it, plus end caps at nose/tail tip -- sealing the
## perimeter neither band's Core was built to reach (see tuna_model.gd's
## _build_rim for the full rationale; identical technique, unaffected by the
## torso/leg band split since it works from the real silhouette extremes).
func _build_rim(root: Node3D, img: Image) -> void:
	var img_w := img.get_width()
	var img_h := img.get_height()

	var top_pts: Array[Vector2] = []
	var bottom_pts: Array[Vector2] = []
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
		var z := LENGTH / 2.0 - u * LENGTH
		top_pts.append(Vector2(HEIGHT - top_row / float(img_h - 1) * HEIGHT, z))
		bottom_pts.append(Vector2(HEIGHT - bottom_row / float(img_h - 1) * HEIGHT, z))
	if top_pts.size() < 2:
		return

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.27, 0.2)
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_rim_strip(st, top_pts)
	_add_rim_strip(st, bottom_pts)
	_add_rim_strip(st, [top_pts[0], bottom_pts[0]])
	_add_rim_strip(st, [top_pts[top_pts.size() - 1], bottom_pts[bottom_pts.size() - 1]])
	st.generate_normals()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Rim"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

## The mouth is drawn open: within a narrow band near the snout (image
## columns ~16-88 of 1200, empirically -- roughly the first 7% of the
## image), each column's opaque pixels split into two separate runs (the
## upper jaw/skull above, the lower jaw below) with a real transparent gap
## between them, unlike every other column which has one contiguous run.
## _build_rim's top/bottom traces only follow the OUTERMOST edge per
## column, so they correctly never cross this gap -- but nothing seals the
## gap's own INNER boundary (the underside of the upper jaw, the top of the
## lower jaw), the same "hollow lens" problem _build_rim exists to fix for
## the body's outer silhouette, just turned up at the mouth cavity instead.
## Left alone, that read as a visible line/gap cutting between the jaws
## from the wrong angle. This traces and seals that inner boundary the same
## way, restricted to just this column range so it doesn't touch the many
## much-smaller multi-run columns elsewhere (between toes, around tooth
## serrations further back) -- sealing those would look like webbing that
## doesn't belong there.
const MOUTH_GAP_MAX_U := 0.1
const MOUTH_SEAL_MIN_RUN_PX := 3 ## ignores single-pixel antialiasing/tooth-serration noise

func _build_mouth_seal(root: Node3D, img: Image) -> void:
	var img_w := img.get_width()
	var img_h := img.get_height()
	var max_col := int(MOUTH_GAP_MAX_U * (img_w - 1))

	var inner_top_pts: Array[Vector2] = []
	var inner_bottom_pts: Array[Vector2] = []
	for col in range(max_col + 1):
		var first_start := -1
		var first_end := -1
		var last_start := -1
		var in_run := false
		var run_start := 0
		for row in range(img_h + 1):
			var opaque := row < img_h and img.get_pixel(col, row).a > 0.5
			if opaque and not in_run:
				run_start = row
				in_run = true
			elif not opaque and in_run:
				if row - run_start >= MOUTH_SEAL_MIN_RUN_PX:
					if first_start < 0:
						first_start = run_start
						first_end = row
					last_start = run_start
				in_run = false
		if first_start < 0 or last_start <= first_end:
			continue # one run (or none) here -- mouth is closed at this column
		var u := col / float(img_w - 1)
		var z := LENGTH / 2.0 - u * LENGTH
		inner_top_pts.append(Vector2(HEIGHT - first_end / float(img_h - 1) * HEIGHT, z))
		inner_bottom_pts.append(Vector2(HEIGHT - last_start / float(img_h - 1) * HEIGHT, z))
	if inner_top_pts.size() < 2:
		return

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.27, 0.2)
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_rim_strip(st, inner_top_pts)
	_add_rim_strip(st, inner_bottom_pts)
	_add_rim_strip(st, [inner_top_pts[0], inner_bottom_pts[0]])
	_add_rim_strip(st, [inner_top_pts[inner_top_pts.size() - 1], inner_bottom_pts[inner_bottom_pts.size() - 1]])
	st.generate_normals()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MouthSeal"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

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

## No skeleton (the body is a flat cutout, like the fish), so running is
## faked the same way they fake swimming: whole-body motion rather than
## animated limbs. A forward pitch + vertical bob reads as a running stride
## well enough at the game's chase-camera distance; a per-leg stride cycle
## isn't possible without separate leg geometry this technique doesn't build.
func _build_animations(root: Node3D) -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	root.add_child(anim_player)
	var library := AnimationLibrary.new()
	library.add_animation("Idle", _make_idle_animation())
	library.add_animation("Walk", _make_run_animation(0.55, 4.0, 0.015))
	library.add_animation("Gallop", _make_run_animation(0.32, 7.0, 0.03))
	library.add_animation("BiteAttack", _make_bite_animation())
	library.add_animation("Pounce", _make_pounce_animation())
	library.add_animation("Death", _make_death_animation())
	library.add_animation("HitReact", _make_hit_react_animation())
	anim_player.add_animation_library("", library)

func _make_idle_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 2.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:rotation:x"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 1.0, deg_to_rad(2.0))
	anim.track_insert_key(track, 2.0, 0.0)
	return anim

func _make_run_animation(cycle_length: float, pitch_deg: float, bob_height: float) -> Animation:
	var anim := Animation.new()
	anim.length = cycle_length
	anim.loop_mode = Animation.LOOP_LINEAR

	var pitch := deg_to_rad(pitch_deg)
	var pitch_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pitch_track, NodePath(".:rotation:x"))
	anim.track_insert_key(pitch_track, 0.0, pitch)
	anim.track_insert_key(pitch_track, cycle_length * 0.5, -pitch * 0.4)
	anim.track_insert_key(pitch_track, cycle_length, pitch)

	var bob_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(bob_track, NodePath(".:position:y"))
	anim.track_insert_key(bob_track, 0.0, 0.0)
	anim.track_insert_key(bob_track, cycle_length * 0.25, bob_height)
	anim.track_insert_key(bob_track, cycle_length * 0.5, 0.0)
	anim.track_insert_key(bob_track, cycle_length * 0.75, bob_height)
	anim.track_insert_key(bob_track, cycle_length, 0.0)

	return anim

## Stakeholder-specified special move (unlockable, see
## player_controller.gd's KILLS_NEEDED_TO_POUNCE/can_pounce): four phases in
## whole-body position/rotation tracks (no jaw bone to animate independently
## -- same constraint as every other whole-body-rotation clip here): a
## crouched windup, a forward-and-down tackle that drives the body low as if
## pinning prey to the ground, a clamping hold, and a sideways wrench
## ("rip") before recovering back to idle. pounce_hit_start/end_fraction in
## velociraptor_species.tres are timed to the clamp+rip span (not the
## windup/tackle travel or the recovery), since that's the part that's
## actually supposed to connect.
const POUNCE_LENGTH := 0.8

func _make_pounce_animation() -> Animation:
	var anim := Animation.new()
	anim.length = POUNCE_LENGTH
	anim.loop_mode = Animation.LOOP_NONE

	# Phase timings, as fractions of POUNCE_LENGTH -- kept named rather than
	# inlined so the four phases below (and pounce_hit_*_fraction in the
	# species resource, which must line up with t_clamp/t_rip_end) stay
	# readable as the same handful of beats the stakeholder described.
	var t_crouch := POUNCE_LENGTH * 0.12
	var t_impact := POUNCE_LENGTH * 0.30 ## tackle lands -- prey hits the ground
	var t_clamp := POUNCE_LENGTH * 0.40 ## jaws have closed, hold begins
	var t_rip_end := POUNCE_LENGTH * 0.68 ## wrench to the side finishes
	var t_end := POUNCE_LENGTH

	# Forward lunge: a brief pull-back (anticipation) then the tackle drives
	# the body forward, holds through the clamp+rip, then releases back.
	var z := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(z, NodePath(".:position:z"))
	anim.track_insert_key(z, 0.0, 0.0)
	anim.track_insert_key(z, t_crouch, -0.06)
	anim.track_insert_key(z, t_impact, 0.55)
	anim.track_insert_key(z, t_rip_end, 0.6)
	anim.track_insert_key(z, t_end, 0.0)

	# Downward drive: the tackle drives low, as if forcing prey down to the
	# ground, then holds down through the bite/rip before standing back up.
	var y := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(y, NodePath(".:position:y"))
	anim.track_insert_key(y, 0.0, 0.0)
	anim.track_insert_key(y, t_crouch, -0.02)
	anim.track_insert_key(y, t_impact, -0.19)
	anim.track_insert_key(y, t_clamp, -0.15) ## small rebound settling after impact
	anim.track_insert_key(y, t_rip_end, -0.15)
	anim.track_insert_key(y, t_end, 0.0)

	# Forward pitch: head-down diving posture through the tackle and bite,
	# easing back upright during the rip (the wrench is mostly yaw, not
	# more pitch) and fully through recovery.
	var rx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rx, NodePath(".:rotation:x"))
	anim.track_insert_key(rx, 0.0, 0.0)
	anim.track_insert_key(rx, t_crouch, deg_to_rad(-8.0))
	anim.track_insert_key(rx, t_impact, deg_to_rad(32.0))
	anim.track_insert_key(rx, t_clamp, deg_to_rad(28.0))
	anim.track_insert_key(rx, t_rip_end, deg_to_rad(18.0))
	anim.track_insert_key(rx, t_end, 0.0)

	# The rip itself: jaws are clamped (held by the z/y/rx tracks above)
	# while the body wrenches sideways around the vertical axis, tearing
	# rather than just biting straight down -- this is the move's actual
	# signature beat, so it gets the fastest, largest motion of the clip.
	var ry := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ry, NodePath(".:rotation:y"))
	anim.track_insert_key(ry, 0.0, 0.0)
	anim.track_insert_key(ry, t_clamp, 0.0)
	anim.track_insert_key(ry, t_rip_end, deg_to_rad(-34.0))
	anim.track_insert_key(ry, t_end, 0.0)

	# A little roll riding along with the yaw wrench sells it as a
	# whole-body tear rather than the head spinning in place.
	var rz := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rz, NodePath(".:rotation:z"))
	anim.track_insert_key(rz, 0.0, 0.0)
	anim.track_insert_key(rz, t_clamp, 0.0)
	anim.track_insert_key(rz, t_rip_end, deg_to_rad(11.0))
	anim.track_insert_key(rz, t_end, 0.0)

	return anim

## The everyday attack (anim_attack, every attack-stamina-cost swing) --
## deliberately much smaller than the Pounce above: a quick lunge forward,
## then a snap back in as if closing in to grab and yank prey toward the
## mouth, rather than the Pounce's full tackle-to-the-ground. There's no
## separate arm/claw geometry on this model to actually close independently
## (the source photo doesn't draw a visible foreleg at all, unlike some
## restorations -- see assets/textures/ATTRIBUTION.md), so "arms closing to
## grab" reads through the same whole-body language as the rest of this
## script's clips: the forward reach is the "reaching," the quick pull-back-
## in right after is the "closing/grab," sold with a touch of roll so it
## doesn't read as a pure straight-line lunge.
const BITE_LENGTH := 0.4

func _make_bite_animation() -> Animation:
	var anim := Animation.new()
	anim.length = BITE_LENGTH
	anim.loop_mode = Animation.LOOP_NONE

	var t_crouch := BITE_LENGTH * 0.2
	var t_reach := BITE_LENGTH * 0.45 ## arms/mouth extend out toward prey
	var t_grab := BITE_LENGTH * 0.65 ## snaps back in as if yanking prey close
	var t_end := BITE_LENGTH

	var z := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(z, NodePath(".:position:z"))
	anim.track_insert_key(z, 0.0, 0.0)
	anim.track_insert_key(z, t_crouch, -0.03)
	anim.track_insert_key(z, t_reach, 0.35)
	anim.track_insert_key(z, t_grab, 0.22)
	anim.track_insert_key(z, t_end, 0.0)

	var y := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(y, NodePath(".:position:y"))
	anim.track_insert_key(y, 0.0, 0.0)
	anim.track_insert_key(y, t_crouch, -0.015)
	anim.track_insert_key(y, t_reach, -0.05)
	anim.track_insert_key(y, t_grab, -0.03)
	anim.track_insert_key(y, t_end, 0.0)

	var rx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rx, NodePath(".:rotation:x"))
	anim.track_insert_key(rx, 0.0, 0.0)
	anim.track_insert_key(rx, t_crouch, deg_to_rad(-5.0))
	anim.track_insert_key(rx, t_reach, deg_to_rad(18.0))
	anim.track_insert_key(rx, t_grab, deg_to_rad(10.0))
	anim.track_insert_key(rx, t_end, 0.0)

	# A small roll riding along with the grab-snap -- a pure forward/back
	# lunge alone reads as a bite, the added twist is what sells "closing
	# in on" prey rather than just poking at it.
	var rz := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rz, NodePath(".:rotation:z"))
	anim.track_insert_key(rz, 0.0, 0.0)
	anim.track_insert_key(rz, t_reach, 0.0)
	anim.track_insert_key(rz, t_grab, deg_to_rad(6.0))
	anim.track_insert_key(rz, t_end, 0.0)

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
