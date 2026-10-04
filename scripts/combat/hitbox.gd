extends Area3D
class_name Hitbox

## Melee hit detector. Call activate() to open the damage window and
## deactivate() to close it; only reports hits while active. Targets need a
## child node named "Damageable" to be hittable.

@export var damage: float = 15.0
@export var owner_body: Node = null ## Body (and its descendants) to ignore, so an attacker can't hit itself.

var _active: bool = false
var _hit_targets: Array[Node] = []

var _collision_shape: CollisionShape3D
var _indicator: MeshInstance3D

func _ready() -> void:
	monitoring = true
	body_entered.connect(_try_hit)
	area_entered.connect(_try_hit)

	for child in get_children():
		if child is CollisionShape3D:
			_collision_shape = child
			break
	_indicator = _build_indicator()
	add_child(_indicator)
	GameState.hitbox_indicators_changed.connect(_on_show_hitbox_indicators_changed)

# Separate from the collision shape so players can actually see where a
# swing will land — feedback that "combat feels too hard" traced back to the
# hitbox being invisible as much as it being small (see hitbox_radius on
# AnimalSpecies/EnemySpecies, which this also follows the size of).
func _build_indicator() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	mesh_instance.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.25, 0.1, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material

	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visible = false
	return mesh_instance

func activate() -> void:
	_hit_targets.clear()
	_active = true
	_update_indicator()
	# Catch anything already overlapping when the window opens, since only
	# newly-entering bodies fire body_entered/area_entered.
	for body in get_overlapping_bodies():
		_try_hit(body)
	for area in get_overlapping_areas():
		_try_hit(area)

func deactivate() -> void:
	_active = false
	_indicator.visible = false

# Reads the collision shape's radius live (rather than caching it in
# _ready()) because controllers assign hitbox_shape.shape after this node's
# _ready() has already run — see player_controller.gd/_spawn_model().
func _update_indicator() -> void:
	if not GameState.show_hitbox_indicators:
		_indicator.visible = false
		return
	if _collision_shape == null or _collision_shape.shape == null:
		return
	var shape := _collision_shape.shape
	if shape is SphereShape3D:
		var radius: float = shape.radius
		_indicator.scale = Vector3.ONE * radius
		_indicator.visible = true

## The setting can flip mid-swing; re-run the same show/hide logic rather
## than just hiding, so turning it back on while a hitbox happens to be
## active doesn't leave it stuck invisible until the next attack.
func _on_show_hitbox_indicators_changed(_enabled: bool) -> void:
	if _active:
		_update_indicator()

func _try_hit(node: Node) -> void:
	if not _active:
		return
	if owner_body != null and (node == owner_body or owner_body.is_ancestor_of(node)):
		return
	if node in _hit_targets:
		return
	var damageable: Damageable = node.get_node_or_null("Damageable")
	if damageable == null:
		return
	_hit_targets.append(node)
	damageable.take_damage(damage, owner_body)
