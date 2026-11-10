extends Node3D

## Procedurally built low-poly tuna -- same technique as the Sparrow/Pelican
## (primitive meshes + code-driven Animation tracks instead of an imported
## rig). A torpedo-shaped body with a separate swaying Tail node (the fish
## equivalent of the bird models' flapping wings) plus static dorsal/pectoral
## fins and yellow finlets for the classic yellowfin-tuna silhouette.
##
## Authored facing +Z to match the rest of the project's model convention --
## swim_controller.gd negates X/Z scale on the model to align it to this
## project's -Z-forward movement. In-game testing showed the Tuna still
## facing the camera despite that, so everything below is built under a
## "Visual" child (rather than directly on self) that gets an extra 180
## flip -- putting the flip on self directly doesn't work, since
## swim_controller.gd's _spawn_model() *overwrites* this node's whole
## transform right after instancing it (same as every other species), which
## would silently erase a rotation set here in _ready().

const BODY_TOP_COLOR := Color(0.07, 0.18, 0.32)
const BODY_SIDE_COLOR := Color(0.75, 0.8, 0.85)
const FIN_COLOR := Color(0.05, 0.12, 0.22)
const FINLET_COLOR := Color(0.95, 0.8, 0.1)
const EYE_COLOR := Color(0.05, 0.05, 0.05)

var anim_player: AnimationPlayer

func _ready() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.rotate_y(PI)
	add_child(visual)

	_build_body(visual)
	_build_fins(visual)
	_build_animations(visual)

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

func _build_body(root: Node3D) -> void:
	# Long, tapered capsule stretched along Z -- reads as a torpedo-bodied
	# pelagic fish rather than a round pond fish.
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.2
	body_mesh.height = 1.1
	_make_part(body_mesh, BODY_SIDE_COLOR, root, Vector3.ZERO, Vector3(deg_to_rad(90), 0, 0))

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.32
	_make_part(head_mesh, BODY_TOP_COLOR, root, Vector3(0, 0.02, 0.42))

	# A tapering snout at the very front -- without this the body reads as a
	# symmetric capsule with no obvious "pointy end", which is what made the
	# model hard to read as facing one particular way.
	var snout_mesh := CylinderMesh.new()
	snout_mesh.top_radius = 0.0
	snout_mesh.bottom_radius = 0.1
	snout_mesh.height = 0.22
	_make_part(snout_mesh, BODY_TOP_COLOR, root, Vector3(0, 0.0, 0.58), Vector3(deg_to_rad(90), 0, 0))

	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.03
	eye_mesh.height = 0.06
	_make_part(eye_mesh, EYE_COLOR, root, Vector3(-0.12, 0.04, 0.5))
	_make_part(eye_mesh, EYE_COLOR, root, Vector3(0.12, 0.04, 0.5))

	# The tail is its own node (not just a mesh) so the swim animation can
	# sway it independently of the body, same reason the Pelican's bill is
	# its own node.
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0, -0.6)
	root.add_child(tail)
	# No extra rotation here -- size.x is already the thin left-right
	# dimension, size.y the vertical height, size.z the length trailing back
	# along the swim axis, which is what a vertical caudal fin needs.
	var tail_mesh := PrismMesh.new()
	tail_mesh.size = Vector3(0.05, 0.5, 0.3)
	_make_part(tail_mesh, FIN_COLOR, tail, Vector3(0, 0, -0.1))

func _build_fins(root: Node3D) -> void:
	var dorsal_mesh := PrismMesh.new()
	dorsal_mesh.size = Vector3(0.03, 0.22, 0.22)
	_make_part(dorsal_mesh, FIN_COLOR, root, Vector3(0, 0.22, 0.05))

	var pectoral_mesh := PrismMesh.new()
	pectoral_mesh.size = Vector3(0.02, 0.1, 0.3)

	var fin_left := Node3D.new()
	fin_left.name = "FinLeft"
	fin_left.position = Vector3(-0.18, -0.02, 0.2)
	fin_left.rotation = Vector3(0, 0, deg_to_rad(-70))
	root.add_child(fin_left)
	_make_part(pectoral_mesh, FIN_COLOR, fin_left, Vector3(-0.1, 0, 0), Vector3(0, deg_to_rad(90), 0))

	var fin_right := Node3D.new()
	fin_right.name = "FinRight"
	fin_right.position = Vector3(0.18, -0.02, 0.2)
	fin_right.rotation = Vector3(0, 0, deg_to_rad(70))
	root.add_child(fin_right)
	_make_part(pectoral_mesh, FIN_COLOR, fin_right, Vector3(0.1, 0, 0), Vector3(0, deg_to_rad(90), 0))

	# Small yellow finlets trailing toward the tail -- the signature detail
	# that reads "tuna" at a glance even on a low-poly model.
	var finlet_mesh := PrismMesh.new()
	finlet_mesh.size = Vector3(0.015, 0.05, 0.08)
	for i in 4:
		var z := -0.15 - i * 0.1
		_make_part(finlet_mesh, FINLET_COLOR, root, Vector3(0, -0.2, z), Vector3(deg_to_rad(180), 0, 0))

## anim_player is added under `root` (the flipped Visual node), not self, so
## its animation tracks' NodePaths (relative to the AnimationPlayer's parent)
## still resolve correctly against Tail/FinLeft/etc, which all live there too.
func _build_animations(root: Node3D) -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	root.add_child(anim_player)

	var library := AnimationLibrary.new()
	library.add_animation("Swim_Idle", _make_swim_animation(1.1, 18.0))
	library.add_animation("Fast_Swim", _make_swim_animation(0.45, 32.0))
	library.add_animation("Bite", _make_bite_animation())
	library.add_animation("Death", _make_death_animation())
	library.add_animation("HitReact", _make_hit_react_animation())
	anim_player.add_animation_library("", library)

func _make_swim_animation(cycle_length: float, max_angle_deg: float) -> Animation:
	var anim := Animation.new()
	anim.length = cycle_length
	anim.loop_mode = Animation.LOOP_LINEAR

	var max_angle := deg_to_rad(max_angle_deg)
	var tail_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tail_track, NodePath("Tail:rotation:y"))
	anim.track_insert_key(tail_track, 0.0, 0.0)
	anim.track_insert_key(tail_track, cycle_length * 0.25, max_angle)
	anim.track_insert_key(tail_track, cycle_length * 0.5, 0.0)
	anim.track_insert_key(tail_track, cycle_length * 0.75, -max_angle)
	anim.track_insert_key(tail_track, cycle_length, 0.0)

	var body_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(body_track, NodePath(".:rotation:y"))
	anim.track_insert_key(body_track, 0.0, 0.0)
	anim.track_insert_key(body_track, cycle_length * 0.25, -max_angle * 0.25)
	anim.track_insert_key(body_track, cycle_length * 0.5, 0.0)
	anim.track_insert_key(body_track, cycle_length * 0.75, max_angle * 0.25)
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
