extends CanvasLayer
class_name PlayerHUD

@onready var health_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HealthLabel
@onready var stamina_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/StaminaBar
@onready var stamina_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StaminaLabel

func update_health(current: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current
	health_label.text = "HP: %d / %d" % [current, max_health]

func update_stamina(current: float, max_stamina: float) -> void:
	stamina_bar.max_value = max_stamina
	stamina_bar.value = current
	stamina_label.text = "Stamina: %d / %d" % [current, max_stamina]
