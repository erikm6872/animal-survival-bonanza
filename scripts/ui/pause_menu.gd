extends CanvasLayer

@onready var menu_panel: Control = $MenuPanel
@onready var settings_panel: SettingsPanel = $SettingsPanel
@onready var resume_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/SettingsButton
@onready var shop_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/ShopButton
@onready var change_animal_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/ChangeAnimalButton
@onready var quit_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/QuitButton
@onready var shop: Shop = $Shop

var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	menu_panel.visible = false
	settings_panel.visible = false

	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	change_animal_button.pressed.connect(_on_change_animal_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_panel.back_pressed.connect(_on_settings_back_pressed)
	shop.closed.connect(_on_shop_closed)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if shop.visible:
		shop.close()
	elif settings_panel.visible:
		_on_settings_back_pressed()
	else:
		set_paused(not is_paused)

func set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	visible = paused
	menu_panel.visible = paused
	settings_panel.visible = false
	shop.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void:
	set_paused(false)

func _on_settings_pressed() -> void:
	menu_panel.visible = false
	settings_panel.visible = true
	settings_panel.refresh()

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	menu_panel.visible = true

## Reusable Shop overlay (scenes/ui/shop.tscn) — see docs/GDD.md's Currency
## & progression section. Hides this menu's own panel underneath so the
## two don't visually overlap; _on_shop_closed() brings it back.
func _on_shop_pressed() -> void:
	menu_panel.visible = false
	shop.open()

func _on_shop_closed() -> void:
	menu_panel.visible = true

## Reuses the character select flow instead of a dedicated "switch species"
## path — it already does exactly this (set GameState.selected_species, load
## test_world.tscn) whenever it's entered, whether that's from launch or here.
func _on_change_animal_pressed() -> void:
	set_paused(false)
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
