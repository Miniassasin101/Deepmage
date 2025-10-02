# launch_form.gd
class_name LaunchForm
extends SpellForm

@export var projectile_speed_units: float = 26.0
@export var projectile_scene: PackedScene
@export var base_cost: int = 1
@export var base_speed_units: int = 1

# If you want unit targeting by default:
@export var requires_unit_target: bool = true
@export var requires_position_target: bool = false

func contribute(plan: SpellPlan, ctx: SpellBuildContext) -> void:
	ctx.delivery_type = "projectile"
	ctx.projectile_scene = projectile_scene
	ctx.projectile_speed = projectile_speed_units

	plan.set_needs_target(requires_unit_target, requires_position_target)
	plan.uses_projectile = true

	var step := StepLaunchProjectile.new()
	plan.add_step(step)

	plan.add_cost(int(round(base_cost * cost_scale)))
	plan.add_speed(int(round(base_speed_units * speed_scale)))
