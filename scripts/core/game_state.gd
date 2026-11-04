extends Node

## Autoload. Carries the player's chosen species from the character select
## screen into the gameplay scene. player_controller.gd falls back to its own
## default (Wolf) if this is left null, so scenes stay runnable standalone.

var selected_species: AnimalSpecies = null

## Winter/summer terrain palette, toggled from the pause menu's Settings
## panel. Persists across the character-select "Change Animal" flow (it's
## on this autoload, not the world scene) so switching species doesn't reset it.
signal season_changed(is_winter: bool)
var is_winter: bool = false

func set_winter(value: bool) -> void:
	if value == is_winter:
		return
	is_winter = value
	season_changed.emit(is_winter)

## Whether Hitbox (scripts/combat/hitbox.gd) shows its translucent
## attack-range indicator. Defaults on since it was added to make combat hit
## detection legible; toggled off from the pause menu's Settings panel for
## players who find it visually distracting.
signal hitbox_indicators_changed(enabled: bool)
var show_hitbox_indicators: bool = true

func set_show_hitbox_indicators(value: bool) -> void:
	if value == show_hitbox_indicators:
		return
	show_hitbox_indicators = value
	hitbox_indicators_changed.emit(show_hitbox_indicators)

## Whether hostile wildlife shows a permanent floating health bar
## (scripts/combat/health_bar_3d.gd), toggled from the pause menu's
## Settings panel. Defaults off so combat UI doesn't get busier unless
## asked for.
signal show_health_bars_changed(enabled: bool)
var show_health_bars: bool = false

func set_show_health_bars(value: bool) -> void:
	if value == show_health_bars:
		return
	show_health_bars = value
	show_health_bars_changed.emit(show_health_bars)

## Meta-progression wallet, spent in the Shop (scripts/ui/shop.gd) on
## Unlockables (scripts/core/unlockable.gd). Earned from confirmed enemy
## kills — see EnemySpecies.currency_reward and enemy_controller.gd's
## _on_died(). Persisted to a local save file (no server/accounts, matches
## this project's no-login design everywhere else); owned_unlockable_ids
## lives in the same file so it's one write, not two.
const SAVE_PATH := "user://save.cfg"

signal currency_changed(amount: int)
var currency: int = 0
var owned_unlockable_ids: Dictionary = {} # StringName id -> true

func _ready() -> void:
	_load_save()

func add_currency(amount: int) -> void:
	if amount <= 0:
		return
	currency += amount
	currency_changed.emit(currency)
	_save()

## Returns false (spending nothing) if currency is short — callers should
## check this before marking anything as purchased.
func spend_currency(amount: int) -> bool:
	if amount <= 0 or amount > currency:
		return false
	currency -= amount
	currency_changed.emit(currency)
	_save()
	return true

func is_unlocked(id: StringName) -> bool:
	return owned_unlockable_ids.has(id)

func unlock(id: StringName) -> void:
	owned_unlockable_ids[id] = true
	_save()

func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return # no save file yet -- fresh start, defaults above stand
	currency = config.get_value("progression", "currency", 0)
	owned_unlockable_ids = config.get_value("progression", "owned_unlockable_ids", {})

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("progression", "currency", currency)
	config.set_value("progression", "owned_unlockable_ids", owned_unlockable_ids)
	config.save(SAVE_PATH)
