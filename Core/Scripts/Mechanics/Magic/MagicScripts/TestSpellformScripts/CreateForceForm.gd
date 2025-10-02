# create_force_form.gd
class_name CreateForceForm
extends SpellForm

@export var orb_scene: PackedScene
@export var intensity_per_mag: float = 1.0
@export var base_cost: int = 2
@export var base_speed_units: int = 1

func contribute(plan: SpellPlan, ctx: SpellBuildContext) -> void:
	var create_step := StepCreateForceOrb.new()
	create_step.orb_scene = orb_scene
	create_step.intensity = int(round(power_scale * ctx.base_magnitude * intensity_per_mag))
	plan.add_step(create_step)

	plan.add_cost(int(round(base_cost * cost_scale)))
	plan.add_speed(int(round(base_speed_units * speed_scale)))
	# Not offensive by itself
