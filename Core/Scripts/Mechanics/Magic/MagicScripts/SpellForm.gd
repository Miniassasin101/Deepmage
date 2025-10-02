# spell_form.gd
class_name SpellForm
extends Resource

@export var ui_name: String = "NullForm"
@export var power_scale: float = 1.0
@export var cost_scale: float = 1.0
@export var speed_scale: float = 1.0
@export var tags: Array[String] = []   # e.g. ["create","projectile","damage","utility"]

func contribute(plan: SpellPlan, ctx: SpellBuildContext) -> void:
	# Override in concrete forms to:
	# - push one or more SpellStep into plan.steps
	# - add target requirements
	# - modify ctx.derived values (delivery type, is_offensive, etc.)
	# - add to plan.mana_cost, plan.cast_speed_units
	pass
