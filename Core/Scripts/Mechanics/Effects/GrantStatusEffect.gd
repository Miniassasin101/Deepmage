class_name GrantStatusEffect
extends Effect

@export var status: Status = null

@export var show_text: bool = true

## Overrides the status's own infliction_chance for this specific effect instance.
## Set to -1 to use the status's own infliction_chance value instead.
@export var infliction_chance_override: int = -1

## Overrides the status's own resistance_category for this specific effect instance.
## Leave empty to use the status's own resistance_category instead.
@export var resistance_category_override: String = ""

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
	
	var color: Color = Color.WHITE
	
	match status.status_category:
		Status.StatusCategory.SPECIAL:
			color = Color.ALICE_BLUE
		Status.StatusCategory.BLESSING:
			color = Color.SPRING_GREEN
		Status.StatusCategory.AFFLICTION:
			color = Color.WEB_PURPLE
	
	if show_text:
		Utilities.spawn_text_line(target_unit, status.ui_name, color)

	emit_signal("effect_finished")
	
