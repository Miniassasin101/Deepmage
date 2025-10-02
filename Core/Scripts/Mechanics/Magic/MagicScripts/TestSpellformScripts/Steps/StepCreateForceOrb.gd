# step_create_force_orb.gd
class_name StepCreateForceOrb
extends SpellStep

@export var orb_scene: PackedScene
@export var intensity: int = 1

func execute(plan: SpellPlan) -> void:
	var ctx := plan.context
	if orb_scene == null:
		return
	var parent_node: Node = ctx.caster.get_tree().current_scene
	var orb_instance := orb_scene.instantiate()
	parent_node.add_child(orb_instance)
	orb_instance.global_transform.origin = ctx.caster.get_global_position() + Vector3(0, 1.0, 0)
	# If orb has a script with “set_intensity(int)” call it here.
	if orb_instance.has_method("set_intensity"):
		orb_instance.call("set_intensity", intensity)
	ctx.created_subject = orb_instance
	ctx.conjured_nodes.append(orb_instance)
