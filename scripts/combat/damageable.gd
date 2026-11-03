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

## Starts a delayed damage-over-time effect (e.g. the Komodo Dragon's bite).
## Each poison application runs as its own independent timer loop, so
## stacking multiple bites stacks multiple concurrent DoTs rather than
## refreshing a single one.
func apply_poison(damage_per_tick: float, tick_interval: float, duration: float, delay: float, source: Node = null) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var elapsed := 0.0
	while elapsed < duration:
		if is_dead:
			return
		await get_tree().create_timer(tick_interval).timeout
		elapsed += tick_interval
		take_damage(damage_per_tick, source)
