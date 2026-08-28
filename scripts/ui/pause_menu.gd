extends CanvasLayer

@onready var menu_panel: Control = $MenuPanel
@onready var settings_panel: Control = $SettingsPanel
@onready var resume_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/QuitButton
@onready var sensitivity_slider: HSlider = $SettingsPanel/PanelContainer/MarginContainer/VBoxContainer/SensitivityRow/SensitivitySlider
@onready var fullscreen_button: Button = $SettingsPanel/PanelContainer/MarginContainer/VBoxContainer/FullscreenRow/FullscreenButton
@onready var back_button: Button = $SettingsPanel/PanelContainer/MarginContainer/VBoxContainer/BackButton

var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	menu_panel.visible = false
	settings_panel.visible = false

	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	fullscreen_button.toggled.connect(_on_fullscreen_toggled)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_panel.visible:
		_on_back_pressed()
	else:
		set_paused(not is_paused)

func set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	visible = paused
	menu_panel.visible = paused
	settings_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void:
	set_paused(false)

func _on_settings_pressed() -> void:
	menu_panel.visible = false
	settings_panel.visible = true
	var player := get_tree().get_first_node_in_group("player")
	if player:
		sensitivity_slider.value = player.mouse_sensitivity
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_button.set_pressed_no_signal(is_fullscreen)
	fullscreen_button.text = "On" if is_fullscreen else "Off"

func _on_back_pressed() -> void:
	settings_panel.visible = false
	menu_panel.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_sensitivity_changed(value: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.mouse_sensitivity = value

func _on_fullscreen_toggled(is_fullscreen: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	fullscreen_button.text = "On" if is_fullscreen else "Off"
