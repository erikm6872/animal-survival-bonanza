extends Node3D

## Flat photo-cutout tuna, not primitive-mesh geometry -- a stakeholder
## (animal enthusiast) flagged that the all-primitives version didn't read
## as a real tuna, specifically asking for the snout/fin/tail outline and a
## photo texture mirrored onto both flanks. Two quads (one per side) share
## the same real-tuna photo (assets/textures/tuna_side.png, see
## assets/textures/ATTRIBUTION.md for the public-domain source) with a thin
## gap between them for a sliver of depth -- the photo's silhouette already
## covers the snout, dorsal/pectoral/anal fins, finlets, and forked tail, so
## there's no separate fin geometry to build.
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
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Right flank: normal points +X, UVs read head-to-tail left-to-right,
	# matching the photo as-is.
	_make_side_quad(root, SIDE_GAP, mat, false)
	# Left flank: normal points -X, UVs mirrored (U flipped) so this side
	# shows the same photo as a mirror image -- without the flip, this face
	# would show the tail where the other side shows the head.
	_make_side_quad(root, -SIDE_GAP, mat, true)

func _make_side_quad(root: Node3D, x: float, mat: StandardMaterial3D, mirrored: bool) -> void:
	var half_l := LENGTH / 2.0
	var half_h := HEIGHT / 2.0
	# Head at +Z, tail at -Z (this project's authored-facing convention).
	var head_bottom := Vector3(x, -half_h, half_l)
	var tail_bottom := Vector3(x, -half_h, -half_l)
	var head_top := Vector3(x, half_h, half_l)
	var tail_top := Vector3(x, half_h, -half_l)

	var u_head := 1.0 if mirrored else 0.0
	var u_tail := 0.0 if mirrored else 1.0
	var uv_head_bottom := Vector2(u_head, 1.0)
	var uv_tail_bottom := Vector2(u_tail, 1.0)
	var uv_head_top := Vector2(u_head, 0.0)
	var uv_tail_top := Vector2(u_tail, 0.0)

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	if mirrored:
		# Winding order verified via a headless debug script computing the
		# face normal -- this order faces -X, the other faces +X.
		vertices.append_array([head_bottom, tail_bottom, head_top, tail_top])
		uvs.append_array([uv_head_bottom, uv_tail_bottom, uv_head_top, uv_tail_top])
		indices.append_array([0, 1, 2, 1, 3, 2])
	else:
		vertices.append_array([head_bottom, head_top, tail_bottom, tail_top])
		uvs.append_array([uv_head_bottom, uv_head_top, uv_tail_bottom, uv_tail_top])
		indices.append_array([0, 1, 2, 2, 1, 3])

	var normal := Vector3(-1, 0, 0) if mirrored else Vector3(1, 0, 0)
	var normals := PackedVector3Array([normal, normal, normal, normal])

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
