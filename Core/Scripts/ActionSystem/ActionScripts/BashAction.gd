class_name BashAction
extends Action



@export_category("Action Variables")
@export var attack_success_animation: AnimationPackage
@export var attack_range: float = 2.0


 
func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	var target_unit: Unit = targ_pack.unit
	
	
	await turn_toward_target(target_unit)
	
	owner.animation_controller.play_animation_by_name(attack_success_animation.get_anim_name())
	
	await owner.get_tree().create_timer(1.5).timeout
	
	end_action()



func turn_toward_target(target_unit: Unit) -> void:
	owner.movement_controller.rotate_unit_towards_target_position(target_unit.get_global_position())
	await owner.movement_controller.rotation_complete
	Utilities.spawn_text_line(owner, "Rotation Complete")




func end_action() -> void:
	super.end_action()



func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if !target_pack or !target_pack.has_tag("unit"):
		return false
	
	var unit: Unit = target_pack.unit
	
	if !action_container:
		return false
	
	if unit == action_container.unit:
		return false
	
	if get_distance_to_owner(unit) > attack_range:
		return false
	
	
	return true



func get_distance_to_owner(unit: Unit) -> float:
	return unit.get_global_position().distance_to(owner.get_global_position())
