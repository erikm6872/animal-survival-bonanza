extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
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
@onready var anim_player: AnimationPlayer = $Model/Wolf/AnimationPlayer
@onready var hitbox: Hitbox = $Model/Hitbox

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch: float = 0.0

# Far distance is whatever the scene's SpringArm3D was authored with; mid/close
# are scaled down from that so tuning the scene's spring_length rescales all three.
var camera_distances: Array[float] = []
var camera_distance_index: int = 0

# The Attack clip has no keyframes between these two points (0.6-0.8s) — the
# bite lunge — so that's the window the hitbox is live for.
const ATTACK_HIT_START: float = 0.55
const ATTACK_HIT_END: float = 0.85

var is_attacking: bool = false
var attack_time: float = 0.0
var hitbox_open: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The pack's animations import with loop_mode off; movement loops need it on.
	anim_player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	anim_player.get_animation("Walk").loop_mode = Animation.LOOP_LINEAR
	anim_player.get_animation("Gallop").loop_mode = Animation.LOOP_LINEAR
	anim_player.play("Idle")
	anim_player.animation_finished.connect(_on_animation_finished)
	hitbox.owner_body = self

	var far_distance := spring_arm.spring_length
	camera_distances = [far_distance, far_distance * 2.0 / 3.0, far_distance / 3.0]

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Attack":
		is_attacking = false
		hitbox_open = false
		hitbox.deactivate()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

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

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		attack_time = 0.0
		anim_player.play("Attack")

	if is_attacking:
		attack_time += delta
		if not hitbox_open and attack_time >= ATTACK_HIT_START and attack_time < ATTACK_HIT_END:
			hitbox_open = true
			hitbox.activate()
		elif hitbox_open and attack_time >= ATTACK_HIT_END:
			hitbox_open = false
			hitbox.deactivate()

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := camera_pivot.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0
	right = right.normalized()

	var is_sprinting := Input.is_action_pressed("sprint")
	var move_dir := (forward * -input_dir.y + right * input_dir.x)
	var target_speed := sprint_speed if is_sprinting else walk_speed
	var target_velocity := move_dir * target_speed

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta * target_speed)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta * target_speed)

	if move_dir.length() > 0.1:
		var target_angle := atan2(-move_dir.x, -move_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)
		if not is_attacking:
			anim_player.play("Gallop" if is_sprinting else "Walk")
	elif not is_attacking:
		anim_player.play("Idle")

	move_and_slide()
