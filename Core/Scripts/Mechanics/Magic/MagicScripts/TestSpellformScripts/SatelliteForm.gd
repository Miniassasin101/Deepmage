# satellite_form.gd
class_name SatelliteForm
extends SpellForm

@export var hover_offset: Vector3 = Vector3(0, 1.3, 0)
@export var base_cost: int = 0
@export var base_speed_units: int = 0

func contribute(plan: SpellPlan, ctx: SpellBuildContext) -> void:
	var step := StepAttachSatellite.new()
	step.offset = hover_offset
	plan.add_step(step)

	ctx.delivery_type = "satellite"
	plan.add_cost(int(round(base_cost * cost_scale)))
	plan.add_speed(int(round(base_speed_units * speed_scale)))
