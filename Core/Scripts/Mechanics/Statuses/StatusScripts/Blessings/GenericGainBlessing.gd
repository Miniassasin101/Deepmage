class_name GenericGainBlessing
extends StackingStatus

@export var stat_name: String = "stat_name"

func _init() -> void:
	ui_name = "Flat Blessing"
	status_category = StatusCategory.BLESSING

func on_added(unit: Unit) -> void:
	_apply(unit, amount_per_stack_int * status_level)
	
	

func _on_stacks_changed(old_level: int, new_level: int) -> void:
	_apply(owner, amount_per_stack_int * (new_level - old_level))

func on_removed(unit: Unit) -> void:
	_apply(unit, -amount_per_stack_int * status_level)

func _apply(unit: Unit, delta: int) -> void:
	unit.get_attributes_container().change_attribute_current_value_by(stat_name, delta)
