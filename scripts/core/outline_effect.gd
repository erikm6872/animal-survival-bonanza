extends RefCounted
class_name OutlineEffect

## Adds a see-through-obstruction colored outline to a dynamically-instanced
## species model (player_controller.gd/flight_controller.gd/
## swim_controller.gd/enemy_controller.gd all instance species.model_scene
## at runtime, so this can't be baked into the .tscn files ahead of time).
##
## Builds an inverted-hull shell per MeshInstance3D using outline.gdshader
## (depth-test-disabled so it draws through obstruction once visible), kept
## hidden by default; scripts/core/outline_visibility.gd does the actual
## "only while obstructed" decision via a raycast against vegetation's
## dedicated collision layer and flips all the shells' `visible` together.

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const OUTLINE_VISIBILITY_SCRIPT := preload("res://scripts/core/outline_visibility.gd")
const WORLD_WIDTH: float = 0.035 ## desired on-screen outline thickness in meters, regardless of species size

const PLAYER_COLOR := Color(0.2, 0.9, 1.0)
const ENEMY_COLOR := Color(0.95, 0.15, 0.1) ## matches the hostile red hit_marker.gd already uses

static func apply(model_root: Node3D, color: Color, model_scale: float) -> void:
	var local_width := WORLD_WIDTH / maxf(model_scale, 0.01)
	var shells: Array[MeshInstance3D] = []
	_walk(model_root, color, local_width, shells)

	var visibility: OutlineVisibility = OUTLINE_VISIBILITY_SCRIPT.new()
	visibility.shells = shells
	visibility.target = model_root
	model_root.add_child(visibility)

static func _walk(node: Node, color: Color, local_width: float, shells: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			shells.append(_add_shell(child, color, local_width))
		_walk(child, color, local_width, shells)

## Added as a sibling (not a child) of the original MeshInstance3D so a
## relative `skeleton` NodePath (e.g. "../Skeleton3D") copied from it still
## resolves correctly -- these are animated, usually-skinned meshes.
static func _add_shell(mesh_instance: MeshInstance3D, color: Color, local_width: float) -> MeshInstance3D:
	var shell_material := ShaderMaterial.new()
	shell_material.shader = OUTLINE_SHADER
	shell_material.set_shader_parameter("outline_color", color)
	shell_material.set_shader_parameter("outline_width", local_width)

	var shell := MeshInstance3D.new()
	shell.mesh = mesh_instance.mesh
	shell.transform = mesh_instance.transform
	shell.skeleton = mesh_instance.skeleton
	shell.skin = mesh_instance.skin
	shell.material_override = shell_material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.visible = false
	mesh_instance.get_parent().add_child(shell)
	return shell
