# damage_on_impact_form.gd
class_name DamageOnImpactForm
extends SpellForm

@export var base_damage_pool: int = 3
@export var accuracy_attribute_1: String = "willpower"
@export var accuracy_attribute_2: String = "spellcasting"
@export var base_cost: int = 1
@export var base_speed_units: int = 0

func contribute(plan: SpellPlan, ctx: SpellBuildContext) -> void:
	plan.mark_offensive()
	plan.base_damage_pool += roundi(base_damage_pool * power_scale)
	plan.accuracy_attribute_1 = accuracy_attribute_1
	plan.accuracy_attribute_2 = accuracy_attribute_2

	var step := StepApplyDamageOnArrival.new()
	plan.add_step(step)

	plan.add_costi(roundi(base_cost * cost_scale))
	plan.add_speedi(roundi(base_speed_units * speed_scale))
