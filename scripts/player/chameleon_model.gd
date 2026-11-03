extends Node3D

## Procedurally built low-poly chameleon — no CC0 rigged chameleon model was
## found (searched the same Quaternius/poly.pizza/OpenGameArt sources used
## for the Fox/Eagle), and the tongue-extend attack needs a custom animation
## no stock pack would have anyway. Built the same way as the terrain/water/
## fish/Sparrow: primitive meshes + code-driven animation.
##
## Authored facing +Z to match the rest of the project's model convention —
## player_controller.gd negates X/Z scale on every species model to align it
## to this project's -Z-forward movement, so a model authored facing -Z
## directly would end up backwards (see the Bald Eagle's orientation fix in
## docs/wiki/Design-Decisions.md for what happens when a model doesn't
## follow this convention).

const BODY_COLOR := Color(0.25, 0.55, 0.25)
const BELLY_COLOR := Color(0.55, 0.75, 0.35)
const EYE_COLOR := Color(0.9, 0.85, 0.2)
const PUPIL_COLOR := Color(0.05, 0.05, 0.05)
const TONGUE_COLOR := Color(0.85, 0.25, 0.3)
const CLAW_COLOR := Color(0.2, 0.45, 0.2)

## Tongue extended length when fully shot out — also how far the hitbox
## reach (chameleon_species.tres's hitbox_offset) assumes it travels.
const TONGUE_EXTEND_LENGTH := 1.3

var anim_player: AnimationPlayer
var tongue: Node3D

func _ready() -> void:
	_build_body()
	_build_legs()
	_build_tail()
	_build_tongue()
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
	body_mesh.radius = 0.11
	body_mesh.height = 0.42
	# CapsuleMesh's long axis is Y by default; rotate to lie along Z (forward/back).
	_make_part(body_mesh, BODY_COLOR, self, Vector3(0, 0.14, -0.02), Vector3(deg_to_rad(90), 0, 0))

	var belly_mesh := BoxMesh.new()
	belly_mesh.size = Vector3(0.14, 0.08, 0.3)
	_make_part(belly_mesh, BELLY_COLOR, self, Vector3(0, 0.08, -0.02))

	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.1, 0.1, 0.13)
	_make_part(head_mesh, BODY_COLOR, self, Vector3(0, 0.16, 0.2))

	var snout_mesh := PrismMesh.new()
	snout_mesh.size = Vector3(0.07, 0.07, 0.12)
	_make_part(snout_mesh, BODY_COLOR, self, Vector3(0, 0.15, 0.3), Vector3(0, 0, deg_to_rad(90)))

	# Bulging, independently-aimed eyes are the single most recognizable
	# chameleon trait — oversized on purpose relative to the head.
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.045
	eye_mesh.height = 0.09
	_make_part(eye_mesh, EYE_COLOR, self, Vector3(-0.09, 0.22, 0.18))
	_make_part(eye_mesh, EYE_COLOR, self, Vector3(0.09, 0.22, 0.18))

	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.016
	pupil_mesh.height = 0.032
	_make_part(pupil_mesh, PUPIL_COLOR, self, Vector3(-0.12, 0.22, 0.19))
	_make_part(pupil_mesh, PUPIL_COLOR, self, Vector3(0.12, 0.22, 0.19))

	# The casque — the helmet-like crest on a chameleon's head.
	var casque_mesh := PrismMesh.new()
	casque_mesh.size = Vector3(0.06, 0.06, 0.1)
	_make_part(casque_mesh, BODY_COLOR, self, Vector3(0, 0.23, 0.12), Vector3(deg_to_rad(180), 0, 0))

func _build_legs() -> void:
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.016
	leg_mesh.bottom_radius = 0.02
	leg_mesh.height = 0.16
	# Splayed out and angled, the way a chameleon's legs actually attach
	# (nearly perpendicular to the body), not hanging straight down.
	var front_angle := deg_to_rad(35)
	_make_part(leg_mesh, CLAW_COLOR, self, Vector3(-0.13, 0.05, 0.13), Vector3(0, 0, front_angle))
	_make_part(leg_mesh, CLAW_COLOR, self, Vector3(0.13, 0.05, 0.13), Vector3(0, 0, -front_angle))
	_make_part(leg_mesh, CLAW_COLOR, self, Vector3(-0.13, 0.05, -0.18), Vector3(0, 0, front_angle))
	_make_part(leg_mesh, CLAW_COLOR, self, Vector3(0.13, 0.05, -0.18), Vector3(0, 0, -front_angle))

func _build_tail() -> void:
	# A curled chameleon tail with real curve geometry is a lot of extra
	# segments for a low-poly creature seen mostly from behind/above during
	## play; a tapered tail angled up and back reads as "chameleon tail"
	# clearly enough at this art scale (same simplification call as
	# Sparrow's non-curled tail feathers).
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.0
	tail_mesh.bottom_radius = 0.05
	tail_mesh.height = 0.32
	_make_part(tail_mesh, BODY_COLOR, self, Vector3(0, 0.22, -0.32), Vector3(deg_to_rad(-60), 0, 0))

## A CylinderMesh's long axis is local Y, which survives as the *scale*
## axis regardless of how the node itself is rotated (scale applies in the
## mesh's own pre-rotation local space) — so animating this MeshInstance3D's
## own scale directly would stretch its radius, not its length. A wrapper
## node sidesteps that: the wrapper is what's rotated to point forward and
## animated for length, while the mesh inside it stays un-rotated with Y
## still meaning "length". The mesh is also offset by half its height so it
## grows outward from the mouth (the wrapper's origin) instead of from its
## own center in both directions at once.
func _build_tongue() -> void:
	var wrapper := Node3D.new()
	wrapper.name = "Tongue" # referenced by name in _make_tongue_attack_animation()'s track path
	wrapper.position = Vector3(0, 0.15, 0.36)
	# 90deg would shoot the tongue dead level; pitching up to 60deg angles it
	# ~30deg above horizontal instead, since flies hover well above the
	# Chameleon's low mouth height (see fly_spawner.gd's hover_height_min/max)
	# and a flat-forward tongue couldn't reach them.
	wrapper.rotation = Vector3(deg_to_rad(60), 0, 0)
	add_child(wrapper)

	var tongue_mesh := CylinderMesh.new()
	tongue_mesh.top_radius = 0.012
	tongue_mesh.bottom_radius = 0.016
	tongue_mesh.height = 1.0
	_make_part(tongue_mesh, TONGUE_COLOR, wrapper, Vector3(0, tongue_mesh.height / 2.0, 0))

	tongue = wrapper
	# Retracted by default: scaled to ~0 length so it's invisible until the
	# attack animation extends it. Scaling (not hiding) so the same track
	# can animate scale.y smoothly for the shoot-out/snap-back motion.
	tongue.scale.y = 0.02

func _build_animations() -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)

	var library := AnimationLibrary.new()
	library.add_animation("Idle", _make_idle_animation())
	library.add_animation("Walk", _make_walk_animation(0.5, deg_to_rad(4)))
	library.add_animation("Gallop", _make_walk_animation(0.28, deg_to_rad(7)))
	library.add_animation("TongueAttack", _make_tongue_attack_animation())
	library.add_animation("Death", _make_death_animation())
	library.add_animation("HitReact", _make_hit_react_animation())
	anim_player.add_animation_library("", library)

func _make_idle_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 2.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:position:y"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 1.0, 0.012)
	anim.track_insert_key(track, 2.0, 0.0)
	return anim

## Shared by Walk/Gallop — a slow, deliberate side-to-side rock (real
## chameleons famously sway as they walk) rather than articulated per-leg
## stepping, which would need a lot more rigging for a background movement
## clip. Same complexity trade-off simple_bird_model.gd made for its wings.
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
	anim.track_insert_key(bob_track, cycle_length * 0.25, 0.015)
	anim.track_insert_key(bob_track, cycle_length * 0.5, 0.0)
	anim.track_insert_key(bob_track, cycle_length * 0.75, 0.015)
	anim.track_insert_key(bob_track, cycle_length, 0.0)
	return anim

## Timed to line up with chameleon_species.tres's attack_hit_*_fraction:
## the tongue needs to actually be extended (not mid-snap) during the
## window the Hitbox is active, or the attack will look right but miss
## visually like the Fox's original attack_range/hitbox_reach mismatch did.
func _make_tongue_attack_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.5
	anim.loop_mode = Animation.LOOP_NONE
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("Tongue:scale:y"))
	anim.track_insert_key(track, 0.0, 0.02)
	anim.track_insert_key(track, 0.12, TONGUE_EXTEND_LENGTH) # fast shoot-out
	anim.track_insert_key(track, 0.3, TONGUE_EXTEND_LENGTH) # brief hold at full reach
	anim.track_insert_key(track, 0.5, 0.02) # snap back
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
