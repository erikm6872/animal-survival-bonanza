extends Node3D
class_name HitMarker

## Floating "-N" damage number, spawned at the point of impact when hostile
## wildlife takes damage (see enemy_controller.gd's _on_damaged()). Not a
## scene — built procedurally like the rest of this project's visual
## components, so there's nothing to instantiate but the script itself.

const RISE_HEIGHT: float = 0.8
const DURATION: float = 0.7

static func spawn(parent: Node, world_position: Vector3, amount: float) -> void:
	var marker := HitMarker.new()
	parent.add_child(marker)
	marker.global_position = world_position
	marker._animate(amount)

func _animate(amount: float) -> void:
	var label := Label3D.new()
	label.text = "-%d" % int(round(amount))
	label.modulate = Color(1.0, 0.2, 0.15)
	label.outline_modulate = Color(0, 0, 0)
	label.font_size = 64
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + RISE_HEIGHT, DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, DURATION * 0.6).set_delay(DURATION * 0.4)
	await tween.finished
	queue_free()
