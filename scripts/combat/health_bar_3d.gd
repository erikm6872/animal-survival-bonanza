extends Node3D
class_name HealthBar3D

## A small floating health bar above a Damageable, toggled by
## GameState.show_health_bars (pause menu Settings panel). Polls
## Damageable.current_health every frame rather than wiring to the
## damaged/died signals, so it also picks up enemy_controller.gd's
## _respawn() resetting current_health directly without its own signal.

const WIDTH: float = 0.6
const HEIGHT: float = 0.08

var _damageable: Damageable
var _fill: MeshInstance3D

func _ready() -> void:
	visible = GameState.show_health_bars
	GameState.show_health_bars_changed.connect(_on_show_changed)

func setup(damageable: Damageable) -> void:
	_damageable = damageable
	_build_bars()
	_update_fill()

func _build_bars() -> void:
	add_child(_make_bar_quad(WIDTH, HEIGHT, Color(0.1, 0.1, 0.1, 0.85), 0.0))
	_fill = _make_bar_quad(WIDTH, HEIGHT, Color(0.2, 0.85, 0.2, 0.95), 0.001)
	add_child(_fill)

func _make_bar_quad(width: float, height: float, color: Color, z_offset: float) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, height)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.position.z = z_offset
	return mesh_instance

func _process(_delta: float) -> void:
	if not visible or _damageable == null:
		return
	_update_fill()

## Left-aligned shrink: QuadMesh is centered by default, so scaling x down
## is re-centered to offset the bar back to its left edge instead of
## shrinking toward the middle.
func _update_fill() -> void:
	var fraction := clampf(_damageable.current_health / _damageable.max_health, 0.0, 1.0) if _damageable.max_health > 0.0 else 0.0
	_fill.scale.x = fraction
	_fill.position.x = -WIDTH * 0.5 * (1.0 - fraction)

func _on_show_changed(enabled: bool) -> void:
	visible = enabled
