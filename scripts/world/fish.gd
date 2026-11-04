extends Node3D

## Wanders within a circular area (a pond, or a stretch of river), picking a
## new random point to swim toward whenever it gets close to its current one.
##
## Also hittable by any Hitbox now (see _build_hitbox_target(), same
## Area3D+Damageable pattern as fly.gd) -- added for the Pelican, whose
## whole point is eating fish, but not restricted to it: any species'
## attack that happens to land in the water can eat a fish, matching how
## the Chameleon's flies were never exclusive to the Chameleon either.

const STAMINA_RESTORE_AMOUNT: float = 30.0

@export var center: Vector3 = Vector3.ZERO
@export var radius: float = 2.0
@export var swim_speed: float = 0.6
@export var turn_speed: float = 2.0

var _target: Vector3
var _anim_player: AnimationPlayer
var damageable: Damageable

func _ready() -> void:
	_anim_player = _find_animation_player(self)
	if _anim_player:
		for anim_name in _anim_player.get_animation_list():
			_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
			_anim_player.play(anim_name)
	_build_hitbox_target()
	_pick_new_target()

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _build_hitbox_target() -> void:
	var area := Area3D.new()
	area.name = "HitArea"
	area.collision_layer = 1 # must match Hitbox's collision_mask (see player.tscn/enemy.tscn)
	area.collision_mask = 0
	add_child(area)

	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.15
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
	queue_free()

func _pick_new_target() -> void:
	var angle := randf_range(0.0, TAU)
	var dist := randf_range(0.0, radius)
	_target = center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

func _process(delta: float) -> void:
	var to_target := _target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.3:
		_pick_new_target()
		return
	var dir := to_target.normalized()
	global_position += dir * swim_speed * delta
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)
