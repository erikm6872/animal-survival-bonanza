extends CanvasLayer
class_name PlayerHUD

@onready var health_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HealthLabel

func update_health(current: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current
	health_label.text = "HP: %d / %d" % [current, max_health]
