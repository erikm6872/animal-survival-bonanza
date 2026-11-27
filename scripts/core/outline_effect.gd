extends RefCounted
class_name OutlineEffect

## Adds a see-through-obstruction colored outline to a dynamically-instanced
## species model (player_controller.gd/flight_controller.gd/
## swim_controller.gd/enemy_controller.gd all instance species.model_scene
## at runtime, so this can't be baked into the .tscn files ahead of time).
##
## Uses an inverted-hull shell per MeshInstance3D gated by
## shaders/outline.gdshader's depth_test_inverted, which only lets the
## shell survive where something nearer is already drawn (genuinely
## obstructed) -- see that shader for the depth-test reasoning. Draw order
## (scene, then shell, then the real body) is enforced purely via
## Material.render_priority, so the real body's own materials get bumped
## here too, not just the new shell's.

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const WORLD_WIDTH: float = 0.035 ## desired on-screen outline thickness in meters, regardless of species size
const SHELL_RENDER_PRIORITY: int = 1
const BODY_RENDER_PRIORITY: int = 2

const PLAYER_COLOR := Color(0.2, 0.9, 1.0)
const ENEMY_COLOR := Color(0.95, 0.15, 0.1) ## matches the hostile red hit_marker.gd already uses

static func apply(model_root: Node3D, color: Color, model_scale: float) -> void:
	var local_width := WORLD_WIDTH / maxf(model_scale, 0.01)
	_walk(model_root, color, local_width)

static func _walk(node: Node, color: Color, local_width: float) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			_add_shell(child, color, local_width)
		_walk(child, color, local_width)

## Added as a sibling (not a child) of the original MeshInstance3D so a
## relative `skeleton` NodePath (e.g. "../Skeleton3D") copied from it still
## resolves correctly -- these are animated, usually-skinned meshes.
static func _add_shell(mesh_instance: MeshInstance3D, color: Color, local_width: float) -> void:
	for i in mesh_instance.mesh.get_surface_count():
		var material := mesh_instance.get_active_material(i)
		if material:
			material.render_priority = BODY_RENDER_PRIORITY

	var shell_material := ShaderMaterial.new()
	shell_material.shader = OUTLINE_SHADER
	shell_material.set_shader_parameter("outline_color", color)
	shell_material.set_shader_parameter("outline_width", local_width)
	shell_material.render_priority = SHELL_RENDER_PRIORITY

	var shell := MeshInstance3D.new()
	shell.mesh = mesh_instance.mesh
	shell.transform = mesh_instance.transform
	shell.skeleton = mesh_instance.skeleton
	shell.skin = mesh_instance.skin
	shell.material_override = shell_material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.get_parent().add_child(shell)
