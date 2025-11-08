class_name PotencyUpBlessing
extends StackingStatus

func _init() -> void:
	ui_name = "Potency Up"
	status_category = StatusCategory.BLESSING

func on_before_damage_applied(_unit: Unit, cd: CombatEventData) -> void:
	if not cd.is_hit:
		return
	var total_percent: float = percent_per_stack * float(status_level)
	
	cd.damage_multiplier += int(total_percent)
	
	#var scale: float = 1.0 + (total_percent / 100.0)
	#cd.effective_damage = int(floor(float(cd.effective_damage) * scale))
