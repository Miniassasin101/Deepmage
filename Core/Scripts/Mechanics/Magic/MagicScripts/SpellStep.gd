# spell_step.gd
class_name SpellStep
extends Resource

func execute(plan: SpellPlan) -> void:
	# Override in concrete steps. May yield (await) or be instant.
	pass
