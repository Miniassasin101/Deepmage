## PassiveSkillBar.gd
class_name PassiveSkillBar
extends PanelContainer

@export var label_node: Label

var tween_in: Tween = null
var tween_out: Tween = null

func set_text(skill_text: String) -> void:
	if label_node != null:
		label_node.text = skill_text

func play_in_from_right(final_position: Vector2) -> void:
	var start_position: Vector2 = Vector2(get_viewport_rect().size.x + 40.0, final_position.y)
	position = start_position
	modulate.a = 0.0
	visible = true

	if tween_in != null:
		tween_in.kill()
	tween_in = create_tween()
	tween_in.tween_property(self, "position", final_position, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_in.parallel().tween_property(self, "modulate:a", 1.0, 0.14)

func play_out_up_and_free() -> void:
	var target_position: Vector2 = position + Vector2(0.0, -18.0)
	if tween_out != null:
		tween_out.kill()
	tween_out = create_tween()
	tween_out.tween_property(self, "position", target_position, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween_out.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tween_out.finished.connect(_on_faded)

func _on_faded() -> void:
	queue_free()
