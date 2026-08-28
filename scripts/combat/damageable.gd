extends Node
class_name Damageable

## Attach to any StaticBody3D/CharacterBody3D/Area3D that should be able to take damage.

signal damaged(amount: float, source: Node)
signal died(source: Node)

@export var max_health: float = 100.0

var current_health: float = max_health
var is_dead: bool = false
var is_invulnerable: bool = false ## e.g. during a dodge's i-frames

func _ready() -> void:
	current_health = max_health

func take_damage(amount: float, source: Node = null) -> void:
	if is_dead or is_invulnerable:
		return
	current_health = maxf(current_health - amount, 0.0)
	damaged.emit(amount, source)
	if current_health <= 0.0:
		is_dead = true
		died.emit(source)
