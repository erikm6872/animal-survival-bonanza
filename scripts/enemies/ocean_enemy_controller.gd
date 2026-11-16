extends CharacterBody3D

## Hostile wildlife AI for the ocean biome (the Tiger Shark) -- same
## idle -> chase -> attack -> dead state machine as enemy_controller.gd,
## reusing the same Damageable/Hitbox/HealthBar3D/EnemySpecies wiring, but
## the movement itself is swim_controller.gd's full-3D, no-gravity model
## instead of enemy_controller.gd's gravity-plus-floor one: a shark chases
## in three dimensions (it dives and rises to the player's depth, not just
## turns toward their flattened XZ position), and stays clamped between
## the seafloor and the water surface via OceanHeight the same way the
## player's own Tuna does.

@export var species: EnemySpecies

@export var acceleration: float = 7.0
@export var rotation_speed: float = 5.0
@export var min_seafloor_clearance: float = 1.0
@export var min_depth_below_surface: float = 1.0

@onready var model: Node3D = $Model
@onready var hitbox: Hitbox = $Model/Hitbox
@onready var hitbox_shape: CollisionShape3D = $Model/Hitbox/CollisionShape3D
@onready var damageable: Damageable = $Damageable
@onready var body_collision: CollisionShape3D = $CollisionShape3D

var anim_player: AnimationPlayer

enum State { IDLE, CHASE, ATTACK, DEAD }
var state: State = State.IDLE

var home_position: Vector3

var is_attacking: bool = false
var attack_time: float = 0.0
var hitbox_open: bool = false
var attack_hit_start: float
var attack_hit_end: float

var is_hit_reacting: bool = false

const DEATH_RESPAWN_DELAY: float = 8.0
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
	health_bar.position = Vector3(0, species.hitbox_offset.y + 0.8, 0)
	health_bar.setup(damageable)

func _spawn_model() -> void:
	var instance: Node3D = species.model_scene.instantiate()
	model.add_child(instance)
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
	HitMarker.spawn(get_parent(), global_position + Vector3(0, species.hitbox_offset.y, 0), amount)
	is_hit_reacting = true
	is_attacking = false
	hitbox_open = false
	hitbox.deactivate()
	anim_player.play(species.anim_hit_react.pick_random())
	if state == State.IDLE:
		state = State.CHASE

func _on_died(_source: Node) -> void:
	state = State.DEAD
	is_attacking = false
	is_hit_reacting = false
	hitbox_open = false
	hitbox.deactivate()
	anim_player.play(species.anim_death)
	GameState.add_currency(species.currency_reward)
	await get_tree().create_timer(DEATH_RESPAWN_DELAY).timeout
	_respawn()

func _respawn() -> void:
	damageable.current_health = damageable.max_health
	damageable.is_dead = false
	state = State.IDLE
	global_position = home_position
	velocity = Vector3.ZERO
	model.transform.basis = Basis.IDENTITY
	model.scale = Vector3.ONE
	body_collision.disabled = false
	set_physics_process(true)
	anim_player.play(species.anim_idle)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = velocity.move_toward(Vector3.ZERO, acceleration * delta)
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
		velocity = velocity.move_toward(Vector3.ZERO, acceleration * delta)
	elif state == State.CHASE and player:
		var move_dir: Vector3 = (player.global_position - global_position).normalized()
		_face_toward(global_position + move_dir, delta)
		velocity = velocity.move_toward(move_dir * species.chase_speed, acceleration * delta * species.chase_speed)
		if not is_hit_reacting:
			anim_player.play(species.anim_chase)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, acceleration * delta)
		if not is_hit_reacting:
			anim_player.play(species.anim_idle)

	move_and_slide()
	_clamp_in_water()

func _face_toward(target: Vector3, delta: float) -> void:
	var dir := target - global_position
	if dir.length() < 0.01:
		return
	var target_basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	model.transform.basis = model.transform.basis.orthonormalized().slerp(target_basis, rotation_speed * delta)

## Same inverted clamp as swim_controller.gd -- keeps the shark fully
## submerged between the seafloor and just under the water surface.
func _clamp_in_water() -> void:
	var max_y := OceanHeight.WATER_LEVEL - min_depth_below_surface
	if global_position.y > max_y:
		global_position.y = max_y
		velocity.y = minf(velocity.y, 0.0)

	var min_y := OceanHeight.get_seafloor_height(global_position.x, global_position.z) + min_seafloor_clearance
	if global_position.y < min_y:
		global_position.y = min_y
		velocity.y = maxf(velocity.y, 0.0)
