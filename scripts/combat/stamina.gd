extends Node
class_name Stamina

## Attach to anything that spends stamina (sprinting, attacking, dodging...).

signal changed(current: float, max_stamina: float)

@export var max_stamina: float = 100.0
@export var regen_rate: float = 20.0 ## per second
@export var regen_delay: float = 0.6 ## seconds after the last spend before regen resumes
@export var exhausted_recovery_fraction: float = 0.25 ## must regen back above this fraction of max to stop being exhausted

var current_stamina: float = max_stamina
var is_exhausted: bool = false

var _regen_cooldown: float = 0.0

func _ready() -> void:
	current_stamina = max_stamina

func _process(delta: float) -> void:
	if _regen_cooldown > 0.0:
		_regen_cooldown -= delta
		return
	if current_stamina >= max_stamina:
		return
	current_stamina = minf(current_stamina + regen_rate * delta, max_stamina)
	if is_exhausted and current_stamina >= max_stamina * exhausted_recovery_fraction:
		is_exhausted = false
	changed.emit(current_stamina, max_stamina)

## For one-shot costs (attack, dodge). Refuses and changes nothing if there
## isn't enough stamina.
func try_spend(amount: float) -> bool:
	if is_exhausted or current_stamina < amount:
		return false
	_spend(amount)
	return true

## For continuous drains (sprinting) where partial availability is fine.
## Drains up to `amount`, clamped at 0, and marks exhausted on hitting empty.
func drain(amount: float) -> void:
	if amount <= 0.0 or is_exhausted:
		return
	_spend(amount)

func _spend(amount: float) -> void:
	current_stamina = maxf(current_stamina - amount, 0.0)
	_regen_cooldown = regen_delay
	if current_stamina <= 0.0:
		is_exhausted = true
	changed.emit(current_stamina, max_stamina)
