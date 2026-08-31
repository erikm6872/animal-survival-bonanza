extends Node3D

## Instances whichever player scene the chosen species specifies (ground vs.
## flight controller) at this node's position, since that's no longer a
## fixed scene the level can just embed directly.

func _ready() -> void:
	var species: AnimalSpecies = GameState.selected_species
	if not species:
		species = load("res://resources/species/wolf_species.tres")

	var player: Node3D = species.player_scene.instantiate()
	var spawn_position := global_position
	get_parent().add_child.call_deferred(player)
	await player.tree_entered
	player.global_position = spawn_position
