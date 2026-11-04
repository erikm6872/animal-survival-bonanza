extends Control
class_name SettingsPanel

## All the settings toggles, factored out of the pause menu so the home
## screen's Settings button (docs/GDD.md's Home screen scoping) can share
## this instead of duplicating six rows of toggles. Caller owns
## visibility/navigation entirely: call refresh() before showing this to
## pull current values into the controls, and listen for back_pressed to
## decide what "back" means in that context (the pause menu shows its own
## panel again; the home screen would show its own button row again).
##
## The player-specific rows (sensitivity, fur color) silently no-op when
## no "player" group member exists, which is already true whenever this is
## shown from a context with no gameplay running (e.g. the home screen).

signal back_pressed

@onready var sensitivity_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/SensitivityRow/SensitivitySlider
@onready var fullscreen_button: Button = $PanelContainer/MarginContainer/VBoxContainer/FullscreenRow/FullscreenButton
@onready var season_button: Button = $PanelContainer/MarginContainer/VBoxContainer/SeasonRow/SeasonButton
@onready var hitbox_indicators_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HitboxIndicatorsRow/HitboxIndicatorsButton
@onready var health_bars_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HealthBarsRow/HealthBarsButton
@onready var wolf_color_picker: ColorPickerButton = $PanelContainer/MarginContainer/VBoxContainer/WolfColorRow/WolfColorPicker
@onready var back_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	fullscreen_button.toggled.connect(_on_fullscreen_toggled)
	season_button.toggled.connect(_on_season_toggled)
	hitbox_indicators_button.toggled.connect(_on_hitbox_indicators_toggled)
	health_bars_button.toggled.connect(_on_health_bars_toggled)
	wolf_color_picker.color_changed.connect(_on_wolf_color_changed)
	back_button.pressed.connect(func(): back_pressed.emit())

## Pulls current values (GameState + the active player, if any) into the
## controls. Call before showing this panel.
func refresh() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		sensitivity_slider.value = player.mouse_sensitivity
		wolf_color_picker.color = player.get_fur_color()
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_button.set_pressed_no_signal(is_fullscreen)
	fullscreen_button.text = "On" if is_fullscreen else "Off"
	season_button.set_pressed_no_signal(GameState.is_winter)
	season_button.text = "On" if GameState.is_winter else "Off"
	hitbox_indicators_button.set_pressed_no_signal(GameState.show_hitbox_indicators)
	hitbox_indicators_button.text = "On" if GameState.show_hitbox_indicators else "Off"
	health_bars_button.set_pressed_no_signal(GameState.show_health_bars)
	health_bars_button.text = "On" if GameState.show_health_bars else "Off"

func _on_sensitivity_changed(value: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.mouse_sensitivity = value

func _on_fullscreen_toggled(is_fullscreen: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	fullscreen_button.text = "On" if is_fullscreen else "Off"

func _on_season_toggled(is_winter: bool) -> void:
	GameState.set_winter(is_winter)
	season_button.text = "On" if is_winter else "Off"

func _on_hitbox_indicators_toggled(enabled: bool) -> void:
	GameState.set_show_hitbox_indicators(enabled)
	hitbox_indicators_button.text = "On" if enabled else "Off"

func _on_health_bars_toggled(enabled: bool) -> void:
	GameState.set_show_health_bars(enabled)
	health_bars_button.text = "On" if enabled else "Off"

func _on_wolf_color_changed(color: Color) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_fur_color(color)
