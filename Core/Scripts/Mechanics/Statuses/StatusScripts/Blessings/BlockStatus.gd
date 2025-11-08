class_name BlockStatus
extends Status

@export var floating_text: bool = true

#func _init() -> void:
	#ui_name = "Block"
	# Not a Blessing on purpose (so standard Blessing cleanses won't remove it)
	# Common: block is consumed as it’s used; change in editor if you prefer
	#expire_timing = ExpireTiming.Never

func merge_with(other_status: Status) -> void:
	var other_block: BlockStatus = other_status as BlockStatus
	if other_block == null:
		return
	# Non-stacking: keep the higher value
	if other_block.status_level > status_level:
		status_level = other_block.status_level

func on_before_damage_applied(_unit: Unit, cd: CombatEventData) -> void:
	if cd == null:
		return
	if cd.effective_damage <= 0:
		return
	if status_level <= 0:
		return

	var absorb_amount: int = cd.effective_damage
	if absorb_amount > status_level:
		absorb_amount = status_level

	cd.effective_damage -= absorb_amount
	status_level -= absorb_amount

	if floating_text and absorb_amount > 0:
		Utilities.spawn_text_line(_unit, "BLOCK " + str(absorb_amount), Color.AQUA)
		CombatLog.instance.add_log(_unit.ui_name + " Blocked for " + str(absorb_amount))

	# If used fully this hit, remove; if you prefer one-shot even on partial, set expire_timing=OnUse
	if status_level <= 0 or expire_timing == ExpireTiming.OnUse:
		remove_self(_unit)
