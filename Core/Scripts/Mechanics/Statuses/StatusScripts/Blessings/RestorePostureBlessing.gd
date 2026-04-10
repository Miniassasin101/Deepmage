class_name RestorePostureBlessing
extends StackingStatus

## A one-shot blessing that immediately restores posture by (amount_per_stack_int * status_level).
## Removes itself right after applying so the stat change is permanent (not reversed on expiry).
## If posture was at 0, the AttributesContainer.track_restored signal fires automatically,
## which triggers Unit.revive() — so this same blessing handles both healing and revival.


func _init() -> void:
	ui_name = "Restore Posture"
	status_category = StatusCategory.BLESSING


func on_added(unit: Unit) -> void:
	var container: AttributesContainer = unit.get_attributes_container()
	var posture_attr: Attribute = container.get_attribute("posture")
	if posture_attr == null:
		remove_self.call_deferred(unit)
		return

	var current: int = posture_attr.get_current_modified_value()
	var max_val: int = posture_attr.get_max_value()
	var room: int = max_val - current

	# Already at full posture — nothing to heal.
	if room <= 0:
		remove_self.call_deferred(unit)
		return

	var delta_total: int = amount_per_stack_int * status_level
	var actual_heal: int = mini(delta_total, room)  # Never overheal past maximum.

	container.change_attribute_current_value_by("posture", actual_heal)
	_spawn_float(unit, "+%d Posture" % actual_heal)
	remove_self.call_deferred(unit)


## Block stacking — each cast is independent; stacks don't accumulate.
func merge_with(_other_status: Status) -> void:
	return
