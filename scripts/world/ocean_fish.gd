extends Node3D

## Open-water variant of fish.gd for the ocean biome -- wanders a full 3D
## volume (sphere) instead of a flat pond/river patch, since there's no
## single shallow depth fish would stay at out in open ocean. Eatable by the
## same Area3D+Damageable pattern (not species-exclusive, same reasoning as
## fish.gd and fly.gd).

const STAMINA_RESTORE_AMOUNT: float = 20.0

@export var center: Vector3 = Vector3.ZERO
@export var radius: float = 4.0
@export var swim_speed: float = 1.2
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
	area.collision_layer = 1 # must match Hitbox's collision_mask
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
	var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var dist := randf_range(0.0, radius)
	_target = center + dir * dist
	_target.y = minf(_target.y, OceanHeight.WATER_LEVEL - 1.0) # never wander above the surface

func _process(delta: float) -> void:
	var to_target := _target - global_position
	if to_target.length() < 0.3:
		_pick_new_target()
		return
	var dir := to_target.normalized()
	global_position += dir * swim_speed * delta
	var target_basis := Basis.looking_at(dir, Vector3.UP)
	transform.basis = transform.basis.orthonormalized().slerp(target_basis, turn_speed * delta)
