class_name ManaCostDiscountStatus
extends Status

## Only apply to spells of this type. Example: &"fire"
@export var magic_type_filter: StringName = &""

## Flat reduction. (Clamped at 0 cost.)
@export var flat_reduction: int = 1


func _init() -> void:
	ui_name = "Mana Cost Discount"
	status_category = StatusCategory.SPECIAL
	expire_timing = ExpireTiming.Never


## Called by StatusController.modify_mana_cost().
func modify_mana_cost(_unit: Unit, skill: Skill, cost: int) -> int:
	if skill == null or cost <= 0:
		return cost

	if magic_type_filter != &"" and skill.magic_type != magic_type_filter:
		return cost

	var new_cost := cost - flat_reduction
	if new_cost < 0:
		new_cost = 0
	return new_cost
