extends CanvasLayer

const SPECIES_PATHS: Array[String] = [
	"res://resources/species/wolf_species.tres",
	"res://resources/species/stag_species.tres",
	"res://resources/species/sparrow_species.tres",
	"res://resources/species/eagle_species.tres",
	"res://resources/species/chameleon_species.tres",
	"res://resources/species/komodo_dragon_species.tres",
	"res://resources/species/pelican_species.tres",
	"res://resources/species/tuna_species.tres",
	"res://resources/species/tiger_shark_species.tres",
	"res://resources/species/velociraptor_species.tres",
]

## Display order/labels for the filter tabs -- not the same order as the
## Category enum (AnimalSpecies.Category), since "All" isn't a real category.
const CATEGORY_TABS: Array[Dictionary] = [
	{"label": "All", "category": -1},
	{"label": "Land Mammals", "category": AnimalSpecies.Category.LAND_MAMMAL},
	{"label": "Birds", "category": AnimalSpecies.Category.BIRD},
	{"label": "Reptiles", "category": AnimalSpecies.Category.REPTILE},
	{"label": "Undersea", "category": AnimalSpecies.Category.UNDERSEA},
	{"label": "Dinosaurs", "category": AnimalSpecies.Category.DINOSAUR},
]

@onready var category_tabs: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/CategoryTabs
@onready var card_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/CardScroll/CardContainer

var _all_species: Array[AnimalSpecies] = []
var _selected_category: int = -1

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for path in SPECIES_PATHS:
		_all_species.append(load(path))
	_build_category_tabs()
	_refresh_cards()

func _build_category_tabs() -> void:
	for tab in CATEGORY_TABS:
		var button := Button.new()
		button.text = tab.label
		button.toggle_mode = true
		button.button_pressed = tab.category == _selected_category
		button.pressed.connect(_on_category_chosen.bind(tab.category))
		category_tabs.add_child(button)

func _on_category_chosen(category: int) -> void:
	_selected_category = category
	for button in category_tabs.get_children():
		button.button_pressed = (CATEGORY_TABS[button.get_index()].category == category)
	_refresh_cards()

func _refresh_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()
	for species in _all_species:
		if _selected_category == -1 or species.category == _selected_category:
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
	get_tree().change_scene_to_file(species.start_scene)
