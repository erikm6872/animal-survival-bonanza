extends Node3D

## Ambient, eatable prey for the Chameleon. Movement is the same
## wander-within-a-radius pattern as fish.gd, just in 3D (adds a vertical
## bob) since flies hover instead of swimming at a fixed depth.
##
## Unlike fish (purely decorative, no collision at all), a fly needs to be
## hittable by the Chameleon's tongue Hitbox — same Hitbox/Damageable
## system used everywhere else, not a special case. Area3D (not a
## CharacterBody3D) on purpose: Hitbox listens for both body_entered and
## area_entered, and an Area3D never physically collides with the player's
## movement, so flies never act like solid obstacles while wandering
## through the world.

const BODY_COLOR := Color(0.1, 0.1, 0.12)
const WING_COLOR := Color(0.85, 0.9, 0.95, 0.5)

## How much Stamina.restore() the eater gets — tuned higher than a single
## attack's stamina cost (see player_controller.gd's ATTACK_STAMINA_COST)
## so hunting flies is a real stamina top-up, not a rounding error.
const STAMINA_RESTORE_AMOUNT: float = 20.0

@export var center: Vector3 = Vector3.ZERO
@export var radius: float = 3.0
@export var fly_speed: float = 0.8
@export var turn_speed: float = 3.0
@export var bob_height: float = 0.15
@export var bob_speed: float = 4.0

var _target: Vector3
var _time: float = 0.0
var _wing_left: MeshInstance3D
var _wing_right: MeshInstance3D
var damageable: Damageable

func _ready() -> void:
	_build_visual()
	_build_hitbox_target()
	_time = randf_range(0.0, TAU) # desync wingbeats/bob across flies
	_pick_new_target()

func _build_visual() -> void:
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.02
	body_mesh.height = 0.04
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = BODY_COLOR
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.set_surface_override_material(0, body_mat)
	add_child(body)

	var wing_mesh := QuadMesh.new()
	wing_mesh.size = Vector2(0.05, 0.02)
	var wing_mat := StandardMaterial3D.new()
	wing_mat.albedo_color = WING_COLOR
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_wing_left = MeshInstance3D.new()
	_wing_left.mesh = wing_mesh
	_wing_left.set_surface_override_material(0, wing_mat)
	_wing_left.position = Vector3(-0.025, 0.01, 0)
	add_child(_wing_left)

	_wing_right = MeshInstance3D.new()
	_wing_right.mesh = wing_mesh
	_wing_right.set_surface_override_material(0, wing_mat)
	_wing_right.position = Vector3(0.025, 0.01, 0)
	add_child(_wing_right)

func _build_hitbox_target() -> void:
	var area := Area3D.new()
	area.name = "HitArea"
	area.collision_layer = 1 # must match Hitbox's collision_mask (see player.tscn/enemy.tscn)
	area.collision_mask = 0
	add_child(area)

	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.06
	shape_node.shape = sphere
	area.add_child(shape_node)

	damageable = Damageable.new()
	damageable.name = "Damageable"
	damageable.max_health = 1.0
	damageable.died.connect(_on_eaten)
	area.add_child(damageable)

func _on_eaten(source: Node) -> void:
	if source:
		var stamina: Stamina = source.get_node_or_null("Stamina")
		if stamina:
			stamina.restore(STAMINA_RESTORE_AMOUNT)
		if source.has_method("_on_fly_eaten"):
			source._on_fly_eaten()
	queue_free()

func _pick_new_target() -> void:
	var offset := Vector3(
		randf_range(-radius, radius),
		randf_range(-bob_height, bob_height),
		randf_range(-radius, radius)
	)
	_target = center + offset

func _process(delta: float) -> void:
	_time += delta
	var wing_angle := sin(_time * bob_speed * 3.0) * deg_to_rad(50)
	_wing_left.rotation.z = wing_angle
	_wing_right.rotation.z = -wing_angle

	var to_target := _target - global_position
	if to_target.length() < 0.2:
		_pick_new_target()
		return
	var dir := to_target.normalized()
	global_position += dir * fly_speed * delta
	var flat_dir := Vector3(dir.x, 0, dir.z)
	if flat_dir.length() > 0.01:
		var target_yaw := atan2(-flat_dir.x, -flat_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)
