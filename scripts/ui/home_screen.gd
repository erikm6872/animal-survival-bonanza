extends CanvasLayer

## Boot scene (see project.godot's run/main_scene) -- the game now opens
## here instead of straight into character select. Deliberately basic per
## request: a background and four buttons, no animation/polish pass.
##
## Background is a flat ColorRect for now, not an actual image -- no art
## asset exists yet for this. Swapping in a real background later is a
## one-node change (replace Background with a TextureRect), nothing else
## here depends on it being a solid color.
##
## Settings and Shop are the same reusable scenes the pause menu uses
## (SettingsPanel, Shop) -- this is the second caller proving they don't
## need to know who's hosting them.

@onready var menu_panel: Control = $MenuPanel
@onready var start_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/StartButton
@onready var shop_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/ShopButton
@onready var settings_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/QuitButton
@onready var settings_panel: SettingsPanel = $SettingsPanel
@onready var shop: Shop = $Shop

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	settings_panel.visible = false

	start_button.pressed.connect(_on_start_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
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

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

func _on_shop_pressed() -> void:
	menu_panel.visible = false
	shop.open()

func _on_shop_closed() -> void:
	menu_panel.visible = true

func _on_settings_pressed() -> void:
	menu_panel.visible = false
	settings_panel.visible = true
	settings_panel.refresh()

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	menu_panel.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()
