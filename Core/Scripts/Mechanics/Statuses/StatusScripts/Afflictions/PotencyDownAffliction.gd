class_name PotencyDownAffliction
extends StackingStatus

func _init() -> void:
	ui_name = "Potency Down"
	status_category = StatusCategory.AFFLICTION

func on_before_damage_applied(_unit: Unit, cd: CombatEventData) -> void:
	if not cd.is_hit:
		return
	var total_percent: float = percent_per_stack * float(status_level)
	#var scale: float = 1.0 - (total_percent / 100.0)
	#if scale < 0.0:
	#	scale = 0.0
	cd.damage_multiplier -= int(total_percent)
	#cd.effective_damage = int(floor(float(cd.effective_damage) * scale))
