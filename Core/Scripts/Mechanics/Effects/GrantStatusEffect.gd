class_name GrantStatusEffect
extends Effect

@export var status: Status = null

@export var show_text: bool = true

func apply() -> void:
	var target_unit: Unit = _resolve_target_unit()
	if target_unit == null:
		emit_signal("effect_finished")
		return

	var controller: StatusController = target_unit.get_status_controller()
	if controller == null:
		emit_signal("effect_finished")
		return

	if status == null:
		push_error("No Status Resource in: " + self.to_string())

	controller.add_status(status)

	if show_text:
		Utilities.spawn_text_line(target_unit, "Gained " + status.ui_name.to_pascal_case(), Color.AQUA)

	emit_signal("effect_finished")
