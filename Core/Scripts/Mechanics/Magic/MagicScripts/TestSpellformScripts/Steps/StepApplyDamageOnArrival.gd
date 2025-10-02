# step_apply_damage_on_arrival.gd
class_name StepApplyDamageOnArrival
extends SpellStep

func execute(plan: SpellPlan) -> void:
	# Also a marker: actual damage resolution is done by the Action exactly “on hit”
	pass
