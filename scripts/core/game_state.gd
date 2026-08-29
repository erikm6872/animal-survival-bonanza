extends Node

## Autoload. Carries the player's chosen species from the character select
## screen into the gameplay scene. player_controller.gd falls back to its own
## default (Wolf) if this is left null, so scenes stay runnable standalone.

var selected_species: AnimalSpecies = null
