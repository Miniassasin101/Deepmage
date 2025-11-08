class_name InitiativeUpBlessing
extends StackingStatus

func _init() -> void:
	ui_name = "Initiative Up"
	status_category = StatusCategory.BLESSING

func on_added(unit: Unit) -> void:
	_apply_delta(unit, amount_per_stack_int * status_level)

func _on_stacks_changed(old_level: int, new_level: int) -> void:
	var unit_ref: Unit = owner
	if unit_ref == null:
		return
	var delta_levels: int = new_level - old_level
	if delta_levels != 0:
		_apply_delta(unit_ref, amount_per_stack_int * delta_levels)

func on_removed(unit: Unit) -> void:
	_apply_delta(unit, -amount_per_stack_int * status_level)

func _apply_delta(unit: Unit, delta: int) -> void:
	var container: AttributesContainer = unit.get_attributes_container()
	container.change_attribute_current_value_by("initiative", delta)
	TurnSystem.instance.resort_initiative_mid_round(true)
