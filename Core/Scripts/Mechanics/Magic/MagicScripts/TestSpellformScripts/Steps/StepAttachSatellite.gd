# step_attach_satellite.gd
class_name StepAttachSatellite
extends SpellStep

@export var offset: Vector3 = Vector3(0, 1.2, 0)

func execute(plan: SpellPlan) -> void:
	var ctx := plan.context
	if ctx.created_subject == null:
		return
	# Simple “follow” behavior: parent under the caster or use a follow script
	ctx.created_subject.set_as_toplevel(false)
	ctx.caster.add_child(ctx.created_subject)
	if ctx.created_subject is Node3D:
		var node3d: Node3D = ctx.created_subject
		node3d.transform.origin = offset
