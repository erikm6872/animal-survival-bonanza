extends CharacterBody3D

## Basic hostile wildlife AI: idle -> chase -> attack, looping, plus a dead
## state that respawns after a delay (same pattern as training_dummy.gd, so
## a single enemy can be fought repeatedly during testing/play rather than
## being a one-shot kill with nothing else to fight). Reuses the same
## Damageable/Hitbox components and gravity/floor movement the ground
## player controller uses, but doesn't need dodge/stamina/species
## switching, so it's a much smaller script rather than another branch on
## player_controller.gd.

@export var species: EnemySpecies

@export var acceleration: float = 10.0
@export var rotation_speed: float = 8.0

@onready var model: Node3D = $Model
@onready var hitbox: Hitbox = $Model/Hitbox
@onready var hitbox_shape: CollisionShape3D = $Model/Hitbox/CollisionShape3D
@onready var damageable: Damageable = $Damageable
@onready var body_collision: CollisionShape3D = $CollisionShape3D

var anim_player: AnimationPlayer
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

enum State { IDLE, CHASE, ATTACK, DEAD }
var state: State = State.IDLE

var home_position: Vector3

var is_attacking: bool = false
var attack_time: float = 0.0
var hitbox_open: bool = false
var attack_hit_start: float
var attack_hit_end: float

var is_hit_reacting: bool = false

const DEATH_RESPAWN_DELAY: float = 5.0
## Once attacking, the player has to back off this much further than
## attack_range before it breaks off — otherwise standing right at the
## range boundary flickers between chase/attack every frame.
const ATTACK_RANGE_SLACK: float = 1.3

func _ready() -> void:
	home_position = global_position
	_spawn_model()

	damageable.max_health = species.max_health
	damageable.current_health = species.max_health
	hitbox.damage = species.attack_damage
	hitbox.owner_body = self

	anim_player.get_animation(species.anim_idle).loop_mode = Animation.LOOP_LINEAR
	anim_player.get_animation(species.anim_chase).loop_mode = Animation.LOOP_LINEAR
	anim_player.play(species.anim_idle)
	anim_player.animation_finished.connect(_on_animation_finished)

	var attack_length := anim_player.get_animation(species.anim_attack).length
	attack_hit_start = attack_length * species.attack_hit_start_fraction
	attack_hit_end = attack_length * species.attack_hit_end_fraction

	damageable.damaged.connect(_on_damaged)
	damageable.died.connect(_on_died)

	var health_bar := HealthBar3D.new()
	add_child(health_bar)
	health_bar.position = Vector3(0, species.hitbox_offset.y + 0.6, 0)
	health_bar.setup(damageable)

func _spawn_model() -> void:
	var instance: Node3D = species.model_scene.instantiate()
	model.add_child(instance)
	# Packs face +Z by default; flip X/Z to match this project's -Z-forward
	# movement convention (see docs/GDD.md).
	instance.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(-species.model_scale, species.model_scale, -species.model_scale)), Vector3.ZERO)

	anim_player = _find_animation_player(instance)

	hitbox.transform = Transform3D(Basis.IDENTITY, species.hitbox_offset)
	var sphere := SphereShape3D.new()
	sphere.radius = species.hitbox_radius
	hitbox_shape.shape = sphere

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == species.anim_attack:
		is_attacking = false
		hitbox_open = false
		hitbox.deactivate()
	elif anim_name in species.anim_hit_react:
		is_hit_reacting = false

func _on_damaged(amount: float, _source: Node) -> void:
	if state == State.DEAD:
		return
	# hitbox here is this enemy's own attack hitbox (for hitting the player),
	# not where the player's attack landed on it — Damageable has no
	# position of its own (it's a plain Node), so this approximates the
	# impact point at roughly chest height instead.
	HitMarker.spawn(get_parent(), global_position + Vector3(0, species.hitbox_offset.y, 0), amount)
	is_hit_reacting = true
	is_attacking = false
	hitbox_open = false
	hitbox.deactivate()
	anim_player.play(species.anim_hit_react.pick_random())
	# Getting hit is as good as a detection trigger — an idle animal that
	# gets attacked should fight back, not stand there ignoring it.
	if state == State.IDLE:
		state = State.CHASE

func _on_died(_source: Node) -> void:
	state = State.DEAD
	is_attacking = false
	is_hit_reacting = false
	hitbox_open = false
	hitbox.deactivate()
	anim_player.play(species.anim_death)
	await get_tree().create_timer(DEATH_RESPAWN_DELAY).timeout
	_respawn()

func _respawn() -> void:
	damageable.current_health = damageable.max_health
	damageable.is_dead = false
	state = State.IDLE
	global_position = home_position
	velocity = Vector3.ZERO
	model.visible = true
	model.scale = Vector3.ONE
	body_collision.disabled = false
	set_physics_process(true)
	anim_player.play(species.anim_idle)

## Secret mechanic (see player_controller.gd's _on_hitbox_landed_hit): an
## outright devour instead of a normal death — the model squishes down and
## is pulled toward the attacker's mouth over `duration`, timed to match
## the Chameleon's tongue retracting, then respawns same as a normal death.
## Disables physics processing for the duration so a direct global_position
## tween isn't fought by gravity/move_and_slide in _physics_process().
func begin_devoured(mouth_position: Vector3, duration: float) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	is_attacking = false
	is_hit_reacting = false
	hitbox_open = false
	hitbox.deactivate()
	damageable.is_dead = true
	damageable.current_health = 0.0
	anim_player.stop()
	set_physics_process(false)
	body_collision.disabled = true

	var start_position := global_position
	var start_scale := model.scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_method(func(t: float): global_position = start_position.lerp(mouth_position, t), 0.0, 1.0, duration)
	# Lerping to exactly zero scale makes Godot choke trying to invert the
	# resulting singular transform matrix (logs a "det == 0" engine error
	# every frame); a tiny non-zero target avoids that while still reading
	# as "gone" once hidden below.
	tween.tween_method(func(t: float): model.scale = start_scale.lerp(Vector3.ONE * 0.001, t), 0.0, 1.0, duration)
	await tween.finished

	model.visible = false
	await get_tree().create_timer(DEATH_RESPAWN_DELAY).timeout
	_respawn()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if state == State.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var player := get_tree().get_first_node_in_group("player")
	var dist_to_player: float = global_position.distance_to(player.global_position) if player else INF

	match state:
		State.IDLE:
			if player and dist_to_player <= species.detection_radius:
				state = State.CHASE
		State.CHASE:
			if not player or dist_to_player > species.leash_radius:
				state = State.IDLE
			elif dist_to_player <= species.attack_range:
				state = State.ATTACK
		State.ATTACK:
			if not player or dist_to_player > species.attack_range * ATTACK_RANGE_SLACK:
				state = State.CHASE
				is_attacking = false
				hitbox_open = false
				hitbox.deactivate()

	if state == State.ATTACK and player:
		_face_toward(player.global_position, delta)
		if not is_attacking and not is_hit_reacting:
			is_attacking = true
			attack_time = 0.0
			anim_player.play(species.anim_attack)
		if is_attacking:
			attack_time += delta
			if not hitbox_open and attack_time >= attack_hit_start and attack_time < attack_hit_end:
				hitbox_open = true
				hitbox.activate()
			elif hitbox_open and attack_time >= attack_hit_end:
				hitbox_open = false
				hitbox.deactivate()
		velocity.x = 0.0
		velocity.z = 0.0
	elif state == State.CHASE and player:
		var move_dir: Vector3 = player.global_position - global_position
		move_dir.y = 0.0
		move_dir = move_dir.normalized()
		_face_toward(global_position + move_dir, delta)
		velocity.x = move_toward(velocity.x, move_dir.x * species.chase_speed, acceleration * delta * species.chase_speed)
		velocity.z = move_toward(velocity.z, move_dir.z * species.chase_speed, acceleration * delta * species.chase_speed)
		if not is_hit_reacting:
			anim_player.play(species.anim_chase)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if not is_hit_reacting:
			anim_player.play(species.anim_idle)

	move_and_slide()

func _face_toward(target: Vector3, delta: float) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var target_angle := atan2(-dir.x, -dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)
