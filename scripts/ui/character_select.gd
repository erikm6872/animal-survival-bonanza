extends CanvasLayer

const SPECIES_PATHS: Array[String] = [
	"res://resources/species/wolf_species.tres",
	"res://resources/species/stag_species.tres",
]

@onready var card_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/CardContainer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for path in SPECIES_PATHS:
		var species: AnimalSpecies = load(path)
		_add_card(species)

func _add_card(species: AnimalSpecies) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(260, 70)
	button.text = "%s\nHealth: %d   Damage: %d   Walk/Sprint: %.0f / %.0f" % [
		species.display_name, species.max_health, species.attack_damage,
		species.walk_speed, species.sprint_speed,
	]
	button.pressed.connect(_on_species_chosen.bind(species))
	card_container.add_child(button)

func _on_species_chosen(species: AnimalSpecies) -> void:
	GameState.selected_species = species
	get_tree().change_scene_to_file("res://scenes/world/test_world.tscn")
