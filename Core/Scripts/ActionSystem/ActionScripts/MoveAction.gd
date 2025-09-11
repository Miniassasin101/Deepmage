class_name MoveAction
extends Action



@export_category("Action Specific Variables")
@export var move_speed:                  float = 5.0
@export var rotate_speed:                float = 8.0
@export var acceleration_time:           float = 0.3
@export var rotation_acceleration_time:  float = 0.3
@export var stopping_distance:           float = 0.1

## Minimum distance from any unit that the final position can be to avoid overlap.
@export var unit_avoid_radius: float = 0.0

# Internal state:
var movement_curve:      Curve3D
var curve_length:        float
var current_speed:       float
var move_rotate_speed:   float
var acceleration_timer:  float
var rotation_acceleration_timer: float
var curve_travel_offset: float
var is_moving:           bool = false



func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	var to_pos: Vector3 = targ_pack.position
	await _begin_movement(to_pos)
	end_action()




func _begin_movement(to_pos: Vector3) -> void:

	#	return
	var path_pack: PathPackage = PathfindingSystem.instance.get_path_package(to_pos as Vector3, unit, true)
	movement_curve = path_pack.get_curve_3d_from_path()
	curve_length    = movement_curve.get_baked_length()
	
	
	# 2) make movement along curve request
	var move_controller: MovementController = unit.movement_controller
	move_controller.animate_movement_along_curve(
		move_speed, movement_curve, curve_length, acceleration_timer, rotation_acceleration_timer, stopping_distance, rotate_speed)
	
	await move_controller.movement_complete
	
	_end_movement()
	



func _end_movement() -> void:
	# Loop until move_along_curve_process flips is_moving to false
	var rounded_curve_length: float = snappedf(curve_length, 0.01)
	Utilities.spawn_text_line(unit, "Moved: " + str(rounded_curve_length), Color.ALICE_BLUE)
	
	
	
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
