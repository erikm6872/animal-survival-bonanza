extends Node3D

## Procedurally built low-poly pelican — same technique as the Sparrow
## (simple_bird_model.gd): no CC0/commercial-safe rigged pelican model
## exists, so primitive meshes + code-driven animation instead of an
## imported model. Reuses the Sparrow's wing-flap/ground-idle/hop
## construction directly (same WingLeft/WingRight node + track naming) since
## that solved "procedural flying bird" already; only the body proportions,
## the long bill + throat pouch, and the coloring are pelican-specific.
##
## Authored facing +Z to match the rest of the project's model convention —
## flight_controller.gd negates X/Z scale on every species model to align it
## to this project's -Z-forward movement.

const BODY_COLOR := Color(0.92, 0.92, 0.88)
const WING_COLOR := Color(0.55, 0.56, 0.58)
const BILL_COLOR := Color(0.85, 0.6, 0.2)
const POUCH_COLOR := Color(0.75, 0.55, 0.5)
const LEG_COLOR := Color(0.65, 0.55, 0.3)
const EYE_COLOR := Color(0.05, 0.05, 0.05)

var anim_player: AnimationPlayer
var pouch: MeshInstance3D

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
	# Bulkier and longer than the Sparrow's body -- a pelican reads as a
	# heavy-bodied bird, not a small songbird.
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.16
	body_mesh.height = 0.75
	_make_part(body_mesh, BODY_COLOR, self, Vector3(0, 0, -0.04), Vector3(deg_to_rad(90), 0, 0))

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.1
	head_mesh.height = 0.2
	_make_part(head_mesh, BODY_COLOR, self, Vector3(0, 0.1, 0.36))

	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.02
	eye_mesh.height = 0.04
	_make_part(eye_mesh, EYE_COLOR, self, Vector3(-0.08, 0.13, 0.42))
	_make_part(eye_mesh, EYE_COLOR, self, Vector3(0.08, 0.13, 0.42))

	# The bill is a separate node (not just a mesh) so the attack animation
	# can dip it independently of the head/body, same reason the Komodo
	# Dragon's jaw is its own node.
	var bill := Node3D.new()
	bill.name = "Bill"
	bill.position = Vector3(0, 0.07, 0.44)
	add_child(bill)
	var bill_mesh := CylinderMesh.new()
	bill_mesh.top_radius = 0.0
	bill_mesh.bottom_radius = 0.045
	bill_mesh.height = 0.5
	_make_part(bill_mesh, BILL_COLOR, bill, Vector3(0, 0, 0.25), Vector3(deg_to_rad(90), 0, 0))

	# The signature throat pouch -- a flattened blob slung under the bill.
	# Scaled up briefly during the Scoop attack to read as "catching a fish".
	pouch = _make_part(SphereMesh.new(), POUCH_COLOR, bill, Vector3(0, -0.05, 0.22))
	pouch.name = "Pouch" # referenced by name in _make_scoop_animation()'s track path
	pouch.mesh.radius = 0.055
	pouch.mesh.height = 0.08
	pouch.scale = Vector3(1.0, 0.6, 1.4)

	var tail_mesh := PrismMesh.new()
	tail_mesh.size = Vector3(0.18, 0.03, 0.26)
	_make_part(tail_mesh, WING_COLOR, self, Vector3(0, 0, -0.46))

## Identical structure/track-naming to simple_bird_model.gd's _build_wings()
## on purpose -- _make_flap_animation()/_add_folded_wing_keys() below are
## copied from there rather than shared, since this project builds each
## procedural model standalone (same call made for the Chameleon vs. the
## Komodo Dragon not sharing a base class).
func _build_wings() -> void:
	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(0.5, 0.02, 0.15)

	var sweep := Vector3(0, deg_to_rad(-25), deg_to_rad(8))
	var wing_left := Node3D.new()
	wing_left.name = "WingLeft"
	wing_left.position = Vector3(-0.13, 0.03, -0.03)
	wing_left.rotation = sweep
	add_child(wing_left)
	_make_part(wing_mesh, WING_COLOR, wing_left, Vector3(-0.25, 0, 0))

	var wing_right := Node3D.new()
	wing_right.name = "WingRight"
	wing_right.position = Vector3(0.13, 0.03, -0.03)
	wing_right.rotation = Vector3(sweep.x, -sweep.y, -sweep.z)
	add_child(wing_right)
	_make_part(wing_mesh, WING_COLOR, wing_right, Vector3(0.25, 0, 0))

func _build_legs() -> void:
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.025
	leg_mesh.bottom_radius = 0.025
	leg_mesh.height = 0.3
	_make_part(leg_mesh, LEG_COLOR, self, Vector3(-0.07, -0.28, 0.03))
	_make_part(leg_mesh, LEG_COLOR, self, Vector3(0.07, -0.28, 0.03))

	var foot_mesh := BoxMesh.new()
	foot_mesh.size = Vector3(0.05, 0.015, 0.1)
	_make_part(foot_mesh, LEG_COLOR, self, Vector3(-0.07, -0.43, 0.07))
	_make_part(foot_mesh, LEG_COLOR, self, Vector3(0.07, -0.43, 0.07))

func _build_animations() -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)

	var library := AnimationLibrary.new()
	library.add_animation("Flying_Idle", _make_flap_animation(1.0, 22.0))
	library.add_animation("Fast_Flying", _make_flap_animation(0.4, 40.0))
	library.add_animation("Scoop", _make_scoop_animation())
	library.add_animation("Death", _make_death_animation())
	library.add_animation("HitReact", _make_hit_react_animation())
	library.add_animation("Ground_Idle", _make_ground_idle_animation())
	library.add_animation("Hop", _make_hop_animation())
	anim_player.add_animation_library("", library)

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

## The bill dips down-and-forward and the pouch balloons briefly, reading
## as scooping up a fish -- timed to line up with
## pelican_species.tres's attack_hit_*_fraction the same way every other
## species' attack is.
func _make_scoop_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.5
	anim.loop_mode = Animation.LOOP_NONE

	var bill_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(bill_track, NodePath("Bill:rotation:x"))
	anim.track_insert_key(bill_track, 0.0, 0.0)
	anim.track_insert_key(bill_track, 0.18, deg_to_rad(40))
	anim.track_insert_key(bill_track, 0.32, deg_to_rad(40))
	anim.track_insert_key(bill_track, 0.5, 0.0)

	var pouch_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pouch_track, NodePath("Bill/Pouch:scale"))
	anim.track_insert_key(pouch_track, 0.0, Vector3(1.0, 0.6, 1.4))
	anim.track_insert_key(pouch_track, 0.22, Vector3(1.8, 1.3, 1.6))
	anim.track_insert_key(pouch_track, 0.35, Vector3(1.8, 1.3, 1.6))
	anim.track_insert_key(pouch_track, 0.5, Vector3(1.0, 0.6, 1.4))

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

func _add_folded_wing_keys(anim: Animation, at_time: float) -> void:
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
