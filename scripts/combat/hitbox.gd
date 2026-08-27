extends Area3D
class_name Hitbox

## Melee hit detector. Call activate() to open the damage window and
## deactivate() to close it; only reports hits while active. Targets need a
## child node named "Damageable" to be hittable.

@export var damage: float = 15.0
@export var owner_body: Node = null ## Body (and its descendants) to ignore, so an attacker can't hit itself.

var _active: bool = false
var _hit_targets: Array[Node] = []

func _ready() -> void:
	monitoring = true
	body_entered.connect(_try_hit)
	area_entered.connect(_try_hit)

func activate() -> void:
	_hit_targets.clear()
	_active = true
	# Catch anything already overlapping when the window opens, since only
	# newly-entering bodies fire body_entered/area_entered.
	for body in get_overlapping_bodies():
		_try_hit(body)
	for area in get_overlapping_areas():
		_try_hit(area)

func deactivate() -> void:
	_active = false

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
