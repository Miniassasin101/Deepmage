class_name TeleportAction
extends Action



@export_category("Action Specific Variables")


## Minimum distance from any unit that the final position can be to avoid overlap.
@export var unit_avoid_radius: float = 0.0



func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	var to_pos: Vector3 = targ_pack.position
	_begin_movement(to_pos)
	end_action()




func _begin_movement(to_pos: Vector3) -> void:

	var new_pos: Vector3 = PathfindingSystem.instance.get_closest_nav_point_to(to_pos)
	
	unit.set_global_position(new_pos)
	
	_end_movement(new_pos)
	



func _end_movement(new_pos: Vector3) -> void:
	
	Utilities.spawn_text_line(unit, "Moved to: " + str(new_pos), Color.ALICE_BLUE)
	
	
	
	#end_action()








func end_action() -> void:
	super.end_action()



func can_activate_on_target(target_pack: TargetPackage) -> bool:

	if !target_pack or !target_pack.has_tag("position"):
		return false

	var target_pos: Vector3 = target_pack.position

	if _is_too_close_to_any_unit(target_pos):
		return false
	
	return true

func _is_too_close_to_any_unit(target_pos: Vector3) -> bool:
	# Grab every unit in the world
	for other in UnitManager.instance.get_all_units():
		# skip ourselves
		if other == unit:
			continue
		# compare distance
		if other.global_transform.origin.distance_to(target_pos) < unit_avoid_radius:
			return true
	return false

#
