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
