extends Node3D

## Procedurally built low-poly Komodo dragon — same from-scratch technique as
## the Chameleon (scripts/player/chameleon_model.gd): no CC0 rigged Komodo
## model was found, and a separately-animated jaw for the bite attack needs
## a custom clip no stock pack would have anyway.
##
## Authored facing +Z to match the rest of the project's model convention —
## player_controller.gd negates X/Z scale on every species model to align it
## to this project's -Z-forward movement.

const BODY_COLOR := Color(0.33, 0.32, 0.22)
const BELLY_COLOR := Color(0.55, 0.52, 0.4)
const EYE_COLOR := Color(0.85, 0.75, 0.15)
const PUPIL_COLOR := Color(0.05, 0.05, 0.05)
const CLAW_COLOR := Color(0.25, 0.22, 0.15)

var anim_player: AnimationPlayer
var jaw: Node3D

func _ready() -> void:
	_build_body()
	_build_legs()
	_build_tail()
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
	# Long, low-slung body — a bigger, flatter capsule than the Chameleon's,
	# sitting closer to the ground the way a monitor lizard's sprawl does.
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.16
	body_mesh.height = 0.6
	_make_part(body_mesh, BODY_COLOR, self, Vector3(0, 0.17, -0.02), Vector3(deg_to_rad(90), 0, 0))

	var belly_mesh := BoxMesh.new()
	belly_mesh.size = Vector3(0.2, 0.08, 0.42)
	_make_part(belly_mesh, BELLY_COLOR, self, Vector3(0, 0.1, -0.02))

	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.14, 0.11, 0.18)
	_make_part(head_mesh, BODY_COLOR, self, Vector3(0, 0.2, 0.32))

	# Upper snout, fixed to the head.
	var snout_mesh := PrismMesh.new()
	snout_mesh.size = Vector3(0.1, 0.06, 0.14)
	_make_part(snout_mesh, BODY_COLOR, self, Vector3(0, 0.21, 0.44), Vector3(0, 0, deg_to_rad(90)))

	# Lower jaw as its own node so the bite attack can hinge it open.
	jaw = Node3D.new()
	jaw.name = "Jaw"
	jaw.position = Vector3(0, 0.16, 0.27)
	add_child(jaw)
	var jaw_mesh := BoxMesh.new()
	jaw_mesh.size = Vector3(0.12, 0.04, 0.22)
	_make_part(jaw_mesh, BELLY_COLOR, jaw, Vector3(0, -0.02, 0.09))

	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.03
	eye_mesh.height = 0.06
	_make_part(eye_mesh, EYE_COLOR, self, Vector3(-0.08, 0.26, 0.32))
	_make_part(eye_mesh, EYE_COLOR, self, Vector3(0.08, 0.26, 0.32))

	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.012
	pupil_mesh.height = 0.024
	_make_part(pupil_mesh, PUPIL_COLOR, self, Vector3(-0.1, 0.26, 0.34))
	_make_part(pupil_mesh, PUPIL_COLOR, self, Vector3(0.1, 0.26, 0.34))

func _build_legs() -> void:
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.03
	leg_mesh.bottom_radius = 0.035
	leg_mesh.height = 0.2
	# A wide, sprawling lizard stance — legs angled out further than the
	# Chameleon's near-perpendicular attachment, closer to flat-out sideways.
	var angle := deg_to_rad(55)
	_make_part(leg_mesh, CLAW_COLOR, self, Vector3(-0.19, 0.07, 0.2), Vector3(0, 0, angle))
	_make_part(leg_mesh, CLAW_COLOR, self, Vector3(0.19, 0.07, 0.2), Vector3(0, 0, -angle))
	_make_part(leg_mesh, CLAW_COLOR, self, Vector3(-0.19, 0.07, -0.26), Vector3(0, 0, angle))
	_make_part(leg_mesh, CLAW_COLOR, self, Vector3(0.19, 0.07, -0.26), Vector3(0, 0, -angle))

func _build_tail() -> void:
	# Long, straight, tapered tail trailing flat behind — a monitor lizard's
	# tail is nearly as long as its body, unlike the Chameleon's short curl.
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.0
	tail_mesh.bottom_radius = 0.07
	tail_mesh.height = 0.55
	_make_part(tail_mesh, BODY_COLOR, self, Vector3(0, 0.14, -0.55), Vector3(deg_to_rad(-88), 0, 0))

func _build_animations() -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)

	var library := AnimationLibrary.new()
	library.add_animation("Idle", _make_idle_animation())
	library.add_animation("Walk", _make_walk_animation(0.6, deg_to_rad(5)))
	library.add_animation("Gallop", _make_walk_animation(0.32, deg_to_rad(9)))
	library.add_animation("BiteAttack", _make_bite_attack_animation())
	library.add_animation("Death", _make_death_animation())
	library.add_animation("HitReact", _make_hit_react_animation())
	anim_player.add_animation_library("", library)

func _make_idle_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 2.2
	anim.loop_mode = Animation.LOOP_LINEAR
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:position:y"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 1.1, 0.01)
	anim.track_insert_key(track, 2.2, 0.0)
	return anim

## Same side-to-side rock + bob as the Chameleon's walk, just slower and
## wider to read as a heavier sprawling gait instead of a dainty sway.
func _make_walk_animation(cycle_length: float, max_rock_angle: float) -> Animation:
	var anim := Animation.new()
	anim.length = cycle_length
	anim.loop_mode = Animation.LOOP_LINEAR
	var rock_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rock_track, NodePath(".:rotation:z"))
	anim.track_insert_key(rock_track, 0.0, 0.0)
	anim.track_insert_key(rock_track, cycle_length * 0.25, -max_rock_angle)
	anim.track_insert_key(rock_track, cycle_length * 0.5, 0.0)
	anim.track_insert_key(rock_track, cycle_length * 0.75, max_rock_angle)
	anim.track_insert_key(rock_track, cycle_length, 0.0)

	var bob_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(bob_track, NodePath(".:position:y"))
	anim.track_insert_key(bob_track, 0.0, 0.0)
	anim.track_insert_key(bob_track, cycle_length * 0.25, 0.02)
	anim.track_insert_key(bob_track, cycle_length * 0.5, 0.0)
	anim.track_insert_key(bob_track, cycle_length * 0.75, 0.02)
	anim.track_insert_key(bob_track, cycle_length, 0.0)
	return anim

## Jaw hinges open while the whole body lunges forward, then snaps shut.
## Timed to line up with komodo_dragon_species.tres's attack_hit_*_fraction
## so the Hitbox is active while the jaw is actually open (see the same
## timing note on chameleon_model.gd's tongue attack).
func _make_bite_attack_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.5
	anim.loop_mode = Animation.LOOP_NONE

	var jaw_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(jaw_track, NodePath("Jaw:rotation:x"))
	anim.track_insert_key(jaw_track, 0.0, 0.0)
	anim.track_insert_key(jaw_track, 0.1, deg_to_rad(-45))
	anim.track_insert_key(jaw_track, 0.3, deg_to_rad(-45))
	anim.track_insert_key(jaw_track, 0.5, 0.0)

	var lunge_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(lunge_track, NodePath(".:position:z"))
	anim.track_insert_key(lunge_track, 0.0, 0.0)
	anim.track_insert_key(lunge_track, 0.15, 0.15)
	anim.track_insert_key(lunge_track, 0.35, 0.15)
	anim.track_insert_key(lunge_track, 0.5, 0.0)
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
	anim.track_insert_key(track, 0.1, deg_to_rad(-15))
	anim.track_insert_key(track, 0.3, 0.0)
	return anim
