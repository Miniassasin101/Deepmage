class_name APGainBlessing
extends StackingStatus

func _init() -> void:
	ui_name = "AP Gain"
	status_category = StatusCategory.BLESSING

func on_added(unit: Unit) -> void:
	var delta_total: int = amount_per_stack_int * status_level
	var container: AttributesContainer = unit.get_attributes_container()
	container.change_attribute_current_value_by("active_points", delta_total)
	_spawn_float(unit, "+%d AP" % delta_total)
	remove_self.call_deferred(unit)

func merge_with(_other_status: Status) -> void:
	return
