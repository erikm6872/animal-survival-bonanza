extends Node3D

## Wanders within a circular area (a pond, or a stretch of river), picking a
## new random point to swim toward whenever it gets close to its current one.

@export var center: Vector3 = Vector3.ZERO
@export var radius: float = 2.0
@export var swim_speed: float = 0.6
@export var turn_speed: float = 2.0

var _target: Vector3
var _anim_player: AnimationPlayer

func _ready() -> void:
	_anim_player = _find_animation_player(self)
	if _anim_player:
		for anim_name in _anim_player.get_animation_list():
			_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
			_anim_player.play(anim_name)
	_pick_new_target()

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found:
			return found
	return null

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
