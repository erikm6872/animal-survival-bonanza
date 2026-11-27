extends Node
class_name OutlineVisibility

## Toggles a set of outline "shell" MeshInstance3Ds (see outline_effect.gd)
## on only while a physics raycast from the active camera to this
## character's reference point is blocked by scattered vegetation --
## biome_populator.gd puts trees/bushes/rocks on a dedicated collision
## layer (VISION_BLOCKER_MASK) just for this check, separate from normal
## movement collision, so this never makes vegetation solid to walk
## through, only to see through-with-an-outline around.

const VISION_BLOCKER_MASK: int = 1 << 9 ## bit 10 -- must match biome_populator.gd
const CHEST_HEIGHT_OFFSET: float = 1.0 ## aim the raycast at roughly chest height, not the model's ground-level origin
const CHECK_INTERVAL: float = 0.1 ## re-check 10x/sec; obstruction state doesn't need per-frame precision

var shells: Array[MeshInstance3D] = []
var target: Node3D ## the character's model root -- raycast aims at its position + CHEST_HEIGHT_OFFSET

var _time_since_check: float = 0.0

func _process(delta: float) -> void:
	_time_since_check += delta
	if _time_since_check < CHECK_INTERVAL:
		return
	_time_since_check = 0.0

	var camera := get_viewport().get_camera_3d()
	if camera == null or target == null:
		return

	var to_point := target.global_position + Vector3(0, CHEST_HEIGHT_OFFSET, 0)
	var space_state := target.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, to_point, VISION_BLOCKER_MASK)
	query.hit_from_inside = true ## the close-in camera frequently ends up embedded in foliage; without this, a ray starting inside a vision-blocker collider reports no hit at all, missing the most common obstruction case
	var result := space_state.intersect_ray(query)
	var obstructed := not result.is_empty()
	for shell in shells:
		shell.visible = obstructed
