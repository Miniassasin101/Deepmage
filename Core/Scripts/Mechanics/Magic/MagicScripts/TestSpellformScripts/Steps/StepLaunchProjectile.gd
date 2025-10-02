# step_launch_projectile.gd
class_name StepLaunchProjectile
extends SpellStep

func execute(plan: SpellPlan) -> void:
	var ctx := plan.context
	# For spell delivery we do not launch here directly; we let the Action’s
	# animation timing release the projectile (like your RangedAttackAction).
	# So this step is a no-op at runtime and acts as a marker during compile.
	pass
