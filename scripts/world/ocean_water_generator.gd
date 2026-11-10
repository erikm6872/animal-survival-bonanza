extends Node3D

## Builds the ocean biome's water surface: a single large plane at
## OceanHeight.WATER_LEVEL using the same ripple/fresnel shader as the land
## map's river/ponds (water_generator.gd), just a simpler single mesh since
## the ocean has no channel/bank shape to follow.

const WATER_SIZE: float = 200.0
const WATER_SHADER := preload("res://shaders/water.gdshader")

func _ready() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(WATER_SIZE, WATER_SIZE)
	mesh.subdivide_width = 40
	mesh.subdivide_depth = 40

	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mesh.surface_set_material(0, mat)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, OceanHeight.WATER_LEVEL, 0)
	add_child(mesh_instance)
