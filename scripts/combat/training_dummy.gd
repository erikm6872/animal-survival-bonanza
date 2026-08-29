extends StaticBody3D

## Respawns a few seconds after death so it can be hit repeatedly while testing.

const RESPAWN_DELAY: float = 2.0

@onready var damageable: Damageable = $Damageable
@onready var label: Label3D = $HealthLabel
@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	global_position.y = TerrainHeight.get_height(global_position.x, global_position.z)

	damageable.damaged.connect(_on_damaged)
	damageable.died.connect(_on_died)
	_update_label()

func _on_damaged(_amount: float, _source: Node) -> void:
	_update_label()

func _on_died(_source: Node) -> void:
	_update_label()
	mesh.visible = false
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	damageable.current_health = damageable.max_health
	damageable.is_dead = false
	mesh.visible = true
	_update_label()

func _update_label() -> void:
	label.text = "%d / %d" % [damageable.current_health, damageable.max_health]
