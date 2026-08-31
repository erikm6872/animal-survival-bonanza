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
