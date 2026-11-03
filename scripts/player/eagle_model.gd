extends Node3D

## Hybrid bird model: a real rigged mesh (Quaternius's Eagle.fbx, see
## assets/models/ATTRIBUTION.md) for the body/wings and its own Idle/Flying
## animations, plus code-generated attack/death/hit-react/hop clips added at
## runtime — the source pack has no combat animations at all. Those extra
## clips use the same whole-body-rotation trick as simple_bird_model.gd's
## (the fully-procedural Sparrow), just applied to the imported mesh's root
## instead of a from-scratch one. One real gap versus the Sparrow: there are
## no separate wing nodes to fold for a grounded pose, so Hop/ground-idle
## keep the flight silhouette instead of folding wings — a visual compromise
## accepted when choosing to reuse this model rather than build fully
## procedurally (see docs/wiki/Design-Decisions.md).

const EAGLE_SCENE_PATH := "res://assets/models/Eagle.fbx"

## Surface indices from the source FBX (Wings/Beak/Head/Claws, in that
## order) — the model ships flat gray, so every surface needs a color
## override to read as a bald eagle rather than a generic eagle.
const SURFACE_COLORS: Array[Color] = [
	Color(0.16, 0.13, 0.11), # Wings (body + wings + tail, all one mesh island)
	Color(0.92, 0.7, 0.12),  # Beak
	Color(0.95, 0.95, 0.9),  # Head (the pack has no separate white tail surface)
	Color(0.85, 0.65, 0.1),  # Claws
]

var anim_player: AnimationPlayer
var eagle_root: Node3D

func _ready() -> void:
	var eagle_scene: PackedScene = load(EAGLE_SCENE_PATH)
	eagle_root = eagle_scene.instantiate()
	add_child(eagle_root)
	# This pack's model faces -Z locally, the opposite of the +Z convention
	# every other species' pack uses — the generic +Z-assuming flip in
	# player_controller.gd/flight_controller.gd (see their _spawn_model())
	# would otherwise end up facing the camera instead of away from it.
	eagle_root.rotate_y(PI)

	_recolor_surfaces()
	_build_eyes()
	anim_player = _find_animation_player(eagle_root)
	_add_custom_animations()

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

## The source FBX has no eye geometry at all (just the flat-colored head
## surface) — add simple white-and-black sphere eyes as extra mesh parts so
## the eagle doesn't look blank-faced.
##
## These are children of eagle_root, which sits *inside* the model_scale
## (0.15) multiplier player_controller.gd/flight_controller.gd apply
## externally to this whole script's root node — unlike hitbox_offset above,
## which is set directly on the sibling Hitbox node and already lives in
## final, post-model_scale space. A first attempt positioned/sized these
## eyes using hitbox_offset-like numbers directly, which put them at
## roughly (0.009, 0.015, 0.03) relative to the player — practically at the
## model's origin, buried inside the torso — instead of out at the head.
## Dividing the intended final position/radius by model_scale (i.e.
## multiplying by ~6.67) here corrects for that, since eagle_root has no
## scale of its own to absorb it.
##
## A second attempt used +Z as "forward," copying hitbox_offset's sign —
## which put the eyes on the back of the head (facing the trailing camera
## instead of the direction of travel). Tracing the actual Skeleton3D bones
## (skeleton.get_bone_global_pose()) showed the spine/neck chain runs to
## its highest, most-forward point at *negative* Z in this frame — matching
## every other species' -Z-forward convention and revealing hitbox_offset's
## sign was itself backwards (fixed alongside this in eagle_species.tres).
func _build_eyes() -> void:
	var white_mat := StandardMaterial3D.new()
	white_mat.albedo_color = Color(1, 1, 1)
	var pupil_mat := StandardMaterial3D.new()
	pupil_mat.albedo_color = Color(0.05, 0.05, 0.05)

	var model_scale_inverse := 1.0 / 0.15 # matches eagle_species.tres's model_scale
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.035 * model_scale_inverse
	eye_mesh.height = eye_mesh.radius * 2.0
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.016 * model_scale_inverse
	pupil_mesh.height = pupil_mesh.radius * 2.0

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = eye_mesh
		eye.set_surface_override_material(0, white_mat)
		eye.position = Vector3(side * 0.05, 0.07, -0.13) * model_scale_inverse
		eagle_root.add_child(eye)

		var pupil := MeshInstance3D.new()
		pupil.mesh = pupil_mesh
		pupil.set_surface_override_material(0, pupil_mat)
		pupil.position = Vector3(side * 0.05, 0.07, -0.15) * model_scale_inverse
		eagle_root.add_child(pupil)

func _recolor_surfaces() -> void:
	var mesh_instance := _find_mesh_instance(eagle_root)
	if mesh_instance == null:
		return
	for i in mini(SURFACE_COLORS.size(), mesh_instance.mesh.get_surface_count()):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = SURFACE_COLORS[i]
		mesh_instance.set_surface_override_material(i, mat)

func _add_custom_animations() -> void:
	var library := anim_player.get_animation_library("")
	library.add_animation("Peck", _make_peck_animation())
	library.add_animation("Death", _make_death_animation())
	library.add_animation("HitReact", _make_hit_react_animation())
	library.add_animation("Hop", _make_hop_animation())

## NodePath(".") here resolves against eagle_root (the AnimationPlayer's
## root_node is ".." relative to itself, i.e. its own parent, same as it
## resolved before this model got reparented under this wrapper node) — so
## these rotate/move the whole imported mesh, not this wrapper.
func _make_peck_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.45
	anim.loop_mode = Animation.LOOP_NONE
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:rotation:x"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.18, deg_to_rad(40))
	anim.track_insert_key(track, 0.3, deg_to_rad(40))
	anim.track_insert_key(track, 0.45, 0.0)
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

func _make_hop_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.35
	anim.loop_mode = Animation.LOOP_LINEAR
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(".:position:y"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 0.15, 0.07)
	anim.track_insert_key(track, 0.35, 0.0)
	return anim
