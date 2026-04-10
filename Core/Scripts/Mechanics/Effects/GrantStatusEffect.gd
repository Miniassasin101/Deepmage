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

	# Resolve effective values: effect-level overrides take priority over status defaults.
	var effective_category: String = resistance_category_override if resistance_category_override != "" \
		else status.resistance_category
	var effective_chance: int = infliction_chance_override if infliction_chance_override >= 0 \
		else status.infliction_chance

	# Resistance check — only runs when the status has a category assigned.
	# get_attribute_current_value returns 0 for unknown attributes, so units
	# on profiles without resistance stats get 0 resistance (full chance).
	if effective_category != "":
		var attr_name: String = effective_category + "_resistance"
		var resistance_value: int = int(target_unit.get_attributes_container() \
			.get_attribute_current_value(attr_name))
		var final_chance: int = clampi(effective_chance - resistance_value, 0, 100)
		if randi_range(1, 100) > final_chance:
			var status_name: String = status.ui_name
			Utilities.spawn_text_line(target_unit, (status_name + " Resisted!"), Color.AQUA)
			emit_signal("effect_finished")
			return

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
	
