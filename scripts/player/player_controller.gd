extends CharacterBody3D

## Falls back to Wolf if nothing else assigns a species before _ready() runs
## (e.g. GameState.selected_species from the character select screen) — keeps
## this scene runnable directly for quick testing.
@export var species: AnimalSpecies = preload("res://resources/species/wolf_species.tres")

@export var acceleration: float = 12.0
@export var jump_velocity: float = 4.5
@export var rotation_speed: float = 10.0
@export var mouse_sensitivity: float = 0.003
@export var camera_pitch_min: float = -60.0
@export var camera_pitch_max: float = 30.0
@export var camera_zoom_speed: float = 8.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var model: Node3D = $Model
@onready var hitbox: Hitbox = $Model/Hitbox
@onready var hitbox_shape: CollisionShape3D = $Model/Hitbox/CollisionShape3D
@onready var damageable: Damageable = $Damageable
@onready var stamina: Stamina = $Stamina
@onready var hud: PlayerHUD = $PlayerHUD

var anim_player: AnimationPlayer
var fur_mesh: MeshInstance3D

var walk_speed: float
var sprint_speed: float

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch: float = 0.0

# Far distance is whatever the scene's SpringArm3D was authored with; mid/close
# are scaled down from that so tuning the scene's spring_length rescales all three.
var camera_distances: Array[float] = []
var camera_distance_index: int = 0

var attack_hit_start: float
var attack_hit_end: float

const DEATH_RESPAWN_DELAY: float = 3.0

const ATTACK_STAMINA_COST: float = 15.0
const SPRINT_STAMINA_DRAIN_RATE: float = 25.0 ## per second, while actively sprinting

const DODGE_STAMINA_COST: float = 25.0
const DODGE_SPEED: float = 14.0
const DODGE_DURATION: float = 0.6 ## also how long the i-frames last
# The roll pivots around the model's origin, which sits at ground level (feet),
# so without this the body sweeps below the floor as it rotates through
# upside-down. This arcs it up and back down over the roll instead — also
# just looks more like an actual tumble than a rotation-in-place.
const DODGE_HOP_HEIGHT: float = 0.7

var is_attacking: bool = false
var attack_time: float = 0.0
var hitbox_open: bool = false

var is_hit_reacting: bool = false
var is_dead: bool = false

var is_dodging: bool = false
var dodge_time: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	if GameState.selected_species:
		species = GameState.selected_species

	_spawn_model()

	global_position.y = TerrainHeight.get_height(global_position.x, global_position.z) + 1.0

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	walk_speed = species.walk_speed
	sprint_speed = species.sprint_speed
	damageable.max_health = species.max_health
	damageable.current_health = species.max_health
	hitbox.damage = species.attack_damage
	hitbox.owner_body = self

	# The pack's animations import with loop_mode off; movement loops need it on.
	anim_player.get_animation(species.anim_idle).loop_mode = Animation.LOOP_LINEAR
	anim_player.get_animation(species.anim_walk).loop_mode = Animation.LOOP_LINEAR
	anim_player.get_animation(species.anim_gallop).loop_mode = Animation.LOOP_LINEAR
	anim_player.play(species.anim_idle)
	anim_player.animation_finished.connect(_on_animation_finished)

	var attack_length := anim_player.get_animation(species.anim_attack).length
	attack_hit_start = attack_length * species.attack_hit_start_fraction
	attack_hit_end = attack_length * species.attack_hit_end_fraction

	damageable.damaged.connect(_on_damaged)
	damageable.died.connect(_on_died)
	hud.update_health(damageable.current_health, damageable.max_health)

	stamina.changed.connect(hud.update_stamina)
	hud.update_stamina(stamina.current_stamina, stamina.max_stamina)

	var far_distance := spring_arm.spring_length
	camera_distances = [far_distance, far_distance * 2.0 / 3.0, far_distance / 3.0]

func _spawn_model() -> void:
	var instance: Node3D = species.model_scene.instantiate()
	model.add_child(instance)
	# Packs face +Z by default; flip X/Z to match this project's -Z-forward
	# movement convention (see docs/GDD.md).
	instance.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(-species.model_scale, species.model_scale, -species.model_scale)), Vector3.ZERO)

	anim_player = _find_animation_player(instance)
	if species.fur_mesh_path != NodePath(""):
		fur_mesh = instance.get_node(species.fur_mesh_path)

	hitbox.transform = Transform3D(Basis.IDENTITY, species.hitbox_offset)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
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

func _on_damaged(_amount: float, _source: Node) -> void:
	hud.update_health(damageable.current_health, damageable.max_health)
	if is_dead:
		return
	is_hit_reacting = true
	is_attacking = false
	hitbox_open = false
	hitbox.deactivate()
	anim_player.play(species.anim_hit_react.pick_random())

func _on_died(_source: Node) -> void:
	is_dead = true
	is_attacking = false
	is_hit_reacting = false
	is_dodging = false
	damageable.is_invulnerable = false
	hitbox_open = false
	hitbox.deactivate()
	anim_player.play(species.anim_death)
	await get_tree().create_timer(DEATH_RESPAWN_DELAY).timeout
	_respawn()

## Plain-color tint for now; a real fur texture can replace this later without
## changing the caller (pause menu) — it only knows about get/set color.
func set_fur_color(color: Color) -> void:
	if not fur_mesh:
		return
	for i in species.fur_surfaces.size():
		var surface: int = species.fur_surfaces[i]
		var lighten: float = species.fur_lighten[i] if i < species.fur_lighten.size() else 0.0
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.lerp(Color.WHITE, lighten)
		fur_mesh.set_surface_override_material(surface, mat)

func get_fur_color() -> Color:
	if not fur_mesh or species.fur_surfaces.is_empty():
		return Color.WHITE
	var main_surface: int = species.fur_surfaces[0]
	var override := fur_mesh.get_surface_override_material(main_surface)
	if override:
		return override.albedo_color
	return fur_mesh.mesh.surface_get_material(main_surface).albedo_color

func _respawn() -> void:
	damageable.current_health = damageable.max_health
	damageable.is_dead = false
	is_dead = false
	hud.update_health(damageable.current_health, damageable.max_health)
	anim_player.play(species.anim_idle)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_camera_distance"):
		camera_distance_index = (camera_distance_index + 1) % camera_distances.size()

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(camera_pitch_min), deg_to_rad(camera_pitch_max))
		camera_pivot.rotation.x = camera_pitch

func _physics_process(delta: float) -> void:
	spring_arm.spring_length = lerp(spring_arm.spring_length, camera_distances[camera_distance_index], camera_zoom_speed * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta * walk_speed)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta * walk_speed)
		move_and_slide()
		return

	if Input.is_action_just_pressed("debug_damage_self"):
		damageable.take_damage(10.0)
		if is_dead:
			# take_damage() may have killed the player synchronously (via the
			# damaged/died signals) partway through this frame; bail out now so
			# the movement/animation code below doesn't stomp the Death clip
			# with Idle/Walk before the next frame's early-return catches it.
			return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := camera_pivot.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0
	right = right.normalized()
	var move_dir := (forward * -input_dir.y + right * input_dir.x)

	if Input.is_action_just_pressed("dodge") and not is_dodging and not is_attacking and not is_hit_reacting \
			and stamina.try_spend(DODGE_STAMINA_COST):
		is_dodging = true
		dodge_time = 0.0
		dodge_direction = move_dir.normalized() if move_dir.length() > 0.1 else -forward
		damageable.is_invulnerable = true
		var dodge_anim_speed := anim_player.get_animation(species.anim_dodge).length / DODGE_DURATION
		anim_player.play(species.anim_dodge, -1, dodge_anim_speed)

	if is_dodging:
		dodge_time += delta
		velocity.x = dodge_direction.x * DODGE_SPEED
		velocity.z = dodge_direction.z * DODGE_SPEED
		model.rotation.y = atan2(-dodge_direction.x, -dodge_direction.z)
		var roll_progress := dodge_time / DODGE_DURATION
		# Full end-over-end roll along the travel direction, timed to finish
		# with the dodge.
		model.rotation.x = -roll_progress * TAU
		model.position.y = sin(roll_progress * PI) * DODGE_HOP_HEIGHT
		if dodge_time >= DODGE_DURATION:
			is_dodging = false
			damageable.is_invulnerable = false
			model.rotation.x = 0.0
			model.position.y = 0.0
		move_and_slide()
		return

	if Input.is_action_just_pressed("attack") and not is_attacking and not is_hit_reacting \
			and stamina.try_spend(ATTACK_STAMINA_COST):
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

	var is_sprinting := Input.is_action_pressed("sprint") and not stamina.is_exhausted and move_dir.length() > 0.1
	if is_sprinting:
		stamina.drain(SPRINT_STAMINA_DRAIN_RATE * delta)

	var target_speed := sprint_speed if is_sprinting else walk_speed
	var target_velocity := move_dir * target_speed

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta * target_speed)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta * target_speed)

	if move_dir.length() > 0.1:
		var target_angle := atan2(-move_dir.x, -move_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)
		if not is_attacking and not is_hit_reacting:
			anim_player.play(species.anim_gallop if is_sprinting else species.anim_walk)
	elif not is_attacking and not is_hit_reacting:
		anim_player.play(species.anim_idle)

	move_and_slide()
