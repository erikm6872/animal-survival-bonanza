extends CharacterBody3D

## Swimming movement for aquatic species (the Tuna). Mirrors
## flight_controller.gd's shape closely -- full 3D movement, no floor, same
## Damageable/Stamina/Hitbox/HUD wiring and AnimalSpecies schema -- but
## inverts its land/air relationship: the normal state here is submerged
## (clamped between the seafloor and just under the water surface), and
## breaching above the surface is the special, gravity-affected state,
## instead of flight's landed-on-the-ground being the special case.

@export var species: AnimalSpecies

@export var acceleration: float = 9.0
@export var rotation_speed: float = 6.0
@export var mouse_sensitivity: float = 0.003
@export var camera_pitch_min: float = -80.0
@export var camera_pitch_max: float = 80.0
@export var camera_zoom_speed: float = 8.0
@export var min_seafloor_clearance: float = 1.0
@export var min_depth_below_surface: float = 0.6 ## how deep the body stays under water while submerged

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
var model_instance: Node3D ## reset on respawn -- see _respawn()

var cruise_speed: float
var fast_speed: float

var camera_pitch: float = 0.0
var camera_distances: Array[float] = []
var camera_distance_index: int = 0

var attack_hit_start: float
var attack_hit_end: float

const SPAWN_DEPTH_BELOW_SURFACE: float = 3.0
const DEATH_RESPAWN_DELAY: float = 3.0

var is_breaching: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

const BREACH_TRIGGER_DEPTH: float = 2.0 ## must be this close to the surface to breach
const BREACH_VELOCITY: float = 9.0
const AIR_SPEED_SCALE: float = 0.6 ## flopping through the air is slower/clumsier than swimming

const ATTACK_STAMINA_COST: float = 15.0
const SPRINT_STAMINA_DRAIN_RATE: float = 25.0

const DODGE_STAMINA_COST: float = 25.0
const DODGE_SPEED: float = 18.0
const DODGE_DURATION: float = 0.4

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
	elif not species:
		species = load("res://resources/species/tuna_species.tres")

	_spawn_model()
	_reset_position()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	cruise_speed = species.walk_speed
	fast_speed = species.sprint_speed
	damageable.max_health = species.max_health
	damageable.current_health = species.max_health
	hitbox.damage = species.attack_damage
	hitbox.owner_body = self
	hitbox.poison_damage_per_tick = species.poison_damage_per_tick
	hitbox.poison_tick_interval = species.poison_tick_interval
	hitbox.poison_duration = species.poison_duration
	hitbox.poison_delay = species.poison_delay

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

func _reset_position() -> void:
	global_position.y = OceanHeight.WATER_LEVEL - SPAWN_DEPTH_BELOW_SURFACE

func _spawn_model() -> void:
	var instance: Node3D = species.model_scene.instantiate()
	model.add_child(instance)
	# Packs face +Z by default; flip X/Z to match this project's -Z-forward
	# movement convention (see docs/GDD.md).
	instance.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(-species.model_scale, species.model_scale, -species.model_scale)), Vector3.ZERO)
	model_instance = instance

	anim_player = _find_animation_player(instance)
	if species.fur_mesh_path != NodePath(""):
		fur_mesh = instance.get_node(species.fur_mesh_path)

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

## Plain-color tint for now; matches the other controllers' interface so the
## pause menu doesn't need to know which controller is active.
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
	is_breaching = false
	hud.update_health(damageable.current_health, damageable.max_health)
	velocity = Vector3.ZERO
	_reset_position()
	model.transform.basis = Basis.IDENTITY
	model_instance.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(-species.model_scale, species.model_scale, -species.model_scale)), Vector3.ZERO)
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

	if is_dead:
		velocity = velocity.move_toward(Vector3.ZERO, acceleration * delta)
		move_and_slide()
		return

	if Input.is_action_just_pressed("debug_damage_self"):
		damageable.take_damage(10.0)
		if is_dead:
			return

	if Input.is_action_just_pressed("jump") and not is_breaching \
			and global_position.y >= OceanHeight.WATER_LEVEL - BREACH_TRIGGER_DEPTH:
		is_breaching = true
		velocity.y = BREACH_VELOCITY

	if is_breaching:
		velocity.y -= gravity * delta
		if global_position.y <= OceanHeight.WATER_LEVEL and velocity.y <= 0.0:
			# Splashed back below the surface -- resume normal swim clamping.
			is_breaching = false

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := camera_pivot.global_transform.basis
	# Full 3D (not flattened) swim direction -- looking up/down and pressing
	# forward dives/climbs, same trick flight_controller.gd uses.
	var forward := -cam_basis.z
	var right := cam_basis.x
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
		velocity = dodge_direction * DODGE_SPEED
		_face_direction(dodge_direction, delta)
		if dodge_time >= DODGE_DURATION:
			is_dodging = false
			damageable.is_invulnerable = false
		move_and_slide()
		if not is_breaching:
			_clamp_in_water()
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

	var is_fast := Input.is_action_pressed("sprint") and not stamina.is_exhausted and move_dir.length() > 0.1
	if is_fast:
		stamina.drain(SPRINT_STAMINA_DRAIN_RATE * delta)

	var has_input := move_dir.length() > 0.1
	var speed_scale := AIR_SPEED_SCALE if is_breaching else 1.0
	var target_speed := (fast_speed if is_fast else cruise_speed) * speed_scale
	var target_velocity := move_dir.normalized() * target_speed if has_input else Vector3.ZERO
	if is_breaching:
		# Vertical speed is gravity's job while breaching, not the movement
		# acceleration below.
		target_velocity.y = velocity.y

	velocity = velocity.move_toward(target_velocity, acceleration * delta)

	if has_input:
		_face_direction(move_dir, delta)
		if not is_attacking and not is_hit_reacting:
			anim_player.play(species.anim_gallop if is_fast else species.anim_walk)
	elif not is_attacking and not is_hit_reacting:
		anim_player.play(species.anim_idle)

	move_and_slide()
	if not is_breaching:
		_clamp_in_water()

func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var target_basis := Basis.looking_at(direction.normalized(), Vector3.UP)
	model.transform.basis = model.transform.basis.orthonormalized().slerp(target_basis, rotation_speed * delta)

## Keeps the Tuna fully submerged -- below the water surface and above the
## seafloor -- the inverse of flight_controller.gd's _clamp_above_ground().
func _clamp_in_water() -> void:
	var max_y := OceanHeight.WATER_LEVEL - min_depth_below_surface
	if global_position.y > max_y:
		global_position.y = max_y
		velocity.y = minf(velocity.y, 0.0)

	var min_y := OceanHeight.get_seafloor_height(global_position.x, global_position.z) + min_seafloor_clearance
	if global_position.y < min_y:
		global_position.y = min_y
		velocity.y = maxf(velocity.y, 0.0)
