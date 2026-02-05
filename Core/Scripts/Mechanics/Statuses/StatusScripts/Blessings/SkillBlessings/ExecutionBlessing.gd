class_name ExecutionBlessing
extends Status

@export var bonus_power_percent: int = 50	# +50 => 100 -> 150

func before_attack_roll(unit: Unit, cd: CombatEventData) -> void:
	if !_conditions_pass(cd):
		return

	cd.pending_power_percent += bonus_power_percent
	cd.pre_roll_notes.append("ExecutionBlessing: power +" + str(bonus_power_percent))
	
	remove_self(unit)
