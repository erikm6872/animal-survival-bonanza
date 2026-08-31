extends Node3D

## Procedurally built low-poly bird — no CC0 or commercial-use-safe rigged
## bird asset could be found (Quaternius's animal packs have none, and their
## "Monsters" pack's Flying category is fantasy creatures only). Built the
## same way as the terrain/water/fish: primitive meshes + code-driven
## animation instead of an imported model. See docs/GDD.md and
## assets/models/ATTRIBUTION.md for the search notes.
##
## Authored facing +Z to match the rest of the project's model convention —
## player_controller.gd/flight_controller.gd negate X/Z scale on every
## species model to align it to this project's -Z-forward movement, so a
## model authored facing -Z directly would end up backwards.

const BODY_COLOR := Color(0.45, 0.38, 0.3)
const BEAK_COLOR := Color(0.85, 0.6, 0.15)
const WING_COLOR := Color(0.38, 0.32, 0.25)
const LEG_COLOR := Color(0.75, 0.5, 0.15)
const EYE_COLOR := Color(0.05, 0.05, 0.05)

var anim_player: AnimationPlayer

func _ready() -> void:
	_build_body()
	_build_wings()
	_build_legs()
	_build_animations()

func _make_part(mesh: Mesh, color: Color, parent: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, mat)
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	parent.add_child(mesh_instance)
	return mesh_instance

func _build_body() -> void:
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.09
	body_mesh.height = 0.5
	# CapsuleMesh's long axis is Y by default; rotate to lie along Z (forward/back).
	_make_part(body_mesh, BODY_COLOR, self, Vector3(0, 0, -0.03), Vector3(deg_to_rad(90), 0, 0))

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.07
	head_mesh.height = 0.14
	_make_part(head_mesh, BODY_COLOR, self, Vector3(0, 0.06, 0.22))

	# Sitting just on the surface of the head sphere, front-and-outward of center.
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.016
	eye_mesh.height = 0.032
	_make_part(eye_mesh, EYE_COLOR, self, Vector3(-0.05, 0.08, 0.27))
	_make_part(eye_mesh, EYE_COLOR, self, Vector3(0.05, 0.08, 0.27))

	var beak_mesh := CylinderMesh.new()
	beak_mesh.top_radius = 0.0
	beak_mesh.bottom_radius = 0.045
	beak_mesh.height = 0.16
	# CylinderMesh points along +Y by default; rotate 90 around X (same as the
	# body) so its tip points forward along +Z instead.
	_make_part(beak_mesh, BEAK_COLOR, self, Vector3(0, 0.04, 0.34), Vector3(deg_to_rad(90), 0, 0))

	var tail_mesh := PrismMesh.new()
	tail_mesh.size = Vector3(0.14, 0.025, 0.24)
	_make_part(tail_mesh, WING_COLOR, self, Vector3(0, 0, -0.34))

func _build_wings() -> void:
	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(0.36, 0.015, 0.11)

	# Swept back (rotated around Y) and angled up slightly (dihedral) so the
	# rest pose reads as a soaring bird silhouette rather than a flat cross.
	var sweep := Vector3(0, deg_to_rad(-25), deg_to_rad(8))
	var wing_left := Node3D.new()
	wing_left.name = "WingLeft"
	wing_left.position = Vector3(-0.09, 0.02, -0.02)
	wing_left.rotation = sweep
	add_child(wing_left)
	_make_part(wing_mesh, WING_COLOR, wing_left, Vector3(-0.18, 0, 0))

	var wing_right := Node3D.new()
	wing_right.name = "WingRight"
	wing_right.position = Vector3(0.09, 0.02, -0.02)
	wing_right.rotation = Vector3(sweep.x, -sweep.y, -sweep.z)
	add_child(wing_right)
	_make_part(wing_mesh, WING_COLOR, wing_right, Vector3(0.18, 0, 0))

func _build_legs() -> void:
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.018
	leg_mesh.bottom_radius = 0.018
	leg_mesh.height = 0.22
	# CylinderMesh already points along Y by default, so these hang straight
	# down from the belly with no rotation needed.
	_make_part(leg_mesh, LEG_COLOR, self, Vector3(-0.045, -0.21, 0.02))
	_make_part(leg_mesh, LEG_COLOR, self, Vector3(0.045, -0.21, 0.02))

	var foot_mesh := BoxMesh.new()
	foot_mesh.size = Vector3(0.03, 0.012, 0.07)
	_make_part(foot_mesh, LEG_COLOR, self, Vector3(-0.045, -0.32, 0.05))
	_make_part(foot_mesh, LEG_COLOR, self, Vector3(0.045, -0.32, 0.05))

func _build_animations() -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)

	var library := AnimationLibrary.new()
	library.add_animation("Flying_Idle", _make_flap_animation(0.9, 25.0))
	library.add_animation("Fast_Flying", _make_flap_animation(0.35, 45.0))
	library.add_animation("Headbutt", _make_peck_animation())
	library.add_animation("Death", _make_death_animation())
	library.add_animation("HitReact", _make_hit_react_animation())
	library.add_animation("Ground_Idle", _make_ground_idle_animation())
	library.add_animation("Hop", _make_hop_animation())
	anim_player.add_animation_library("", library)

## Wings flap in sync: WingLeft:rotation:z and WingRight:rotation:z need
## opposite signs to both move up/down together, since they're mirrored
## around the body's X axis.
func _make_flap_animation(cycle_length: float, max_angle_deg: float) -> Animation:
	var anim := Animation.new()
	anim.length = cycle_length
	anim.loop_mode = Animation.LOOP_LINEAR

	var max_angle := deg_to_rad(max_angle_deg)
	var left_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(left_track, NodePath("WingLeft:rotation:z"))
	anim.track_insert_key(left_track, 0.0, 0.0)
	anim.track_insert_key(left_track, cycle_length * 0.25, -max_angle)
	anim.track_insert_key(left_track, cycle_length * 0.5, 0.0)
	anim.track_insert_key(left_track, cycle_length * 0.75, max_angle)
	anim.track_insert_key(left_track, cycle_length, 0.0)

	var right_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(right_track, NodePath("WingRight:rotation:z"))
	anim.track_insert_key(right_track, 0.0, 0.0)
	anim.track_insert_key(right_track, cycle_length * 0.25, max_angle)
	anim.track_insert_key(right_track, cycle_length * 0.5, 0.0)
	anim.track_insert_key(right_track, cycle_length * 0.75, -max_angle)
	anim.track_insert_key(right_track, cycle_length, 0.0)

	return anim

func _make_peck_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.5
	anim.loop_mode = Animation.LOOP_NONE
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:rotation:x"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.2, deg_to_rad(35))
	anim.track_insert_key(track, 0.35, deg_to_rad(35))
	anim.track_insert_key(track, 0.5, 0.0)
	return anim

func _make_death_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.8
	anim.loop_mode = Animation.LOOP_NONE
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:rotation:z"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.5, deg_to_rad(80))
	anim.track_insert_key(track, 0.8, deg_to_rad(85))
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

## Wings folded against the body — held pose used whenever the bird is
## standing/hopping on the ground instead of flying.
func _add_folded_wing_keys(anim: Animation, at_time: float) -> void:
	# Positive WingLeft/negative WingRight rotation.z folds down against the
	# body (see _make_flap_animation) — negative angle here would swing them
	# up like antennae instead. Kept moderate (not a full 90) so the tips
	# settle alongside the body instead of swinging under it like legs.
	var fold := deg_to_rad(50.0)
	var left_track := anim.find_track(NodePath("WingLeft:rotation:z"), Animation.TYPE_VALUE)
	if left_track == -1:
		left_track = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(left_track, NodePath("WingLeft:rotation:z"))
	anim.track_insert_key(left_track, at_time, fold)

	var right_track := anim.find_track(NodePath("WingRight:rotation:z"), Animation.TYPE_VALUE)
	if right_track == -1:
		right_track = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(right_track, NodePath("WingRight:rotation:z"))
	anim.track_insert_key(right_track, at_time, -fold)

func _make_ground_idle_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.3
	anim.loop_mode = Animation.LOOP_LINEAR
	_add_folded_wing_keys(anim, 0.0)
	_add_folded_wing_keys(anim, 0.3)
	return anim

func _make_hop_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.35
	anim.loop_mode = Animation.LOOP_LINEAR
	_add_folded_wing_keys(anim, 0.0)
	_add_folded_wing_keys(anim, 0.35)

	var hop_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(hop_track, NodePath(".:position:y"))
	anim.track_insert_key(hop_track, 0.0, 0.0)
	anim.track_insert_key(hop_track, 0.15, 0.07)
	anim.track_insert_key(hop_track, 0.35, 0.0)
	return anim
