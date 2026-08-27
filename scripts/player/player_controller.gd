extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 12.0
@export var jump_velocity: float = 4.5
@export var rotation_speed: float = 10.0
@export var mouse_sensitivity: float = 0.003
@export var camera_pitch_min: float = -60.0
@export var camera_pitch_max: float = 30.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var model: Node3D = $Model

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(camera_pitch_min), deg_to_rad(camera_pitch_max))
		camera_pivot.rotation.x = camera_pitch

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

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
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity := move_dir * target_speed

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta * target_speed)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta * target_speed)

	if move_dir.length() > 0.1:
		var target_angle := atan2(-move_dir.x, -move_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)

	move_and_slide()
