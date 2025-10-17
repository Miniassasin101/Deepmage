class_name MoveToUnitAction
extends Action



@export_category("Action Specific Variables")
@export var limit_by_speed: bool = false

@export_group("Movement Settings")
@export var move_speed:                  float = 5.0
@export var rotate_speed:                float = 8.0
@export var acceleration_time:           float = 0.3
@export var rotation_acceleration_time:  float = 0.3
@export var stopping_distance:           float = 0.1

## Minimum distance from any unit that the final position can be to avoid overlap.
@export var unit_avoid_radius: float = 0.0
@export var unit_avoid_sample_number: int = 15

# Internal state:
var movement_curve:      Curve3D
var curve_length:        float
var current_speed:       float
var move_rotate_speed:   float
var acceleration_timer:  float
var rotation_acceleration_timer: float
var curve_travel_offset: float
var is_moving:           bool = false

var already_shortened: bool = false


func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	already_shortened = false
	var targ_unit: Unit = targ_pack.unit
	await _begin_movement(targ_unit)
	end_action()




func _begin_movement(targ_unit: Unit) -> void:

	# Target position is target unit
	var path_pack: PathPackage = get_path_pack_to_unit(targ_unit)
	movement_curve = path_pack.get_curve_3d_from_path()
	curve_length    = movement_curve.get_baked_length()
	
	if !already_shortened:
		curve_length = maxf(0.0, curve_length - unit_avoid_radius)
	
	
	
		# Optional limiting the movement by the speed
	if limit_by_speed:
		var unit_speed: float = float(unit.get_attributes_container().get_attribute_current_value("speed"))
		unit_speed *= 2 # Double as distance units are not a full grid square
		if curve_length > unit_speed:
			
			curve_length = unit_speed
		
			CombatLog.instance.add_log("Movement Cut Short For: " + unit.ui_name + " Due to Speed being: " + str(unit_speed))
		
		
		# User Visual Processing time
	
	
	
	
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
	CombatLog.instance.add_log(unit.ui_name + " Moved: " + str(rounded_curve_length))
	
	
	
	#end_action()

func get_path_pack_to_unit(in_unit: Unit) -> PathPackage:
	var to_pos: Vector3 = in_unit.get_global_position()
	

	
	var path_pack: PathPackage = PathfindingSystem.instance.get_path_package(to_pos, unit, true)
	
	var move_curve: Curve3D = path_pack.get_curve_3d_from_path()
	
	var curve_len: float = move_curve.get_baked_length() - unit_avoid_radius
	
	var sample_point: Vector3 = move_curve.sample_baked(maxf(curve_len, 0.0))
	
	
	if _is_too_close_to_any_unit(sample_point, in_unit):
		var new_point: Vector3 = get_new_valid_position(in_unit, sample_point)
		if new_point != Vector3(-1, -1, -1):
			path_pack = PathfindingSystem.instance.get_path_package(new_point, unit, true)
			already_shortened = true
	

	
	return path_pack


func get_new_valid_position(target_unit: Unit, ideal_position: Vector3) -> Vector3:
	var new_pos: Vector3 = Vector3(-1, -1, -1)
	
	var pathfind_sys: PathfindingSystem = PathfindingSystem.instance
	
	var test_positions: Array[Vector3] = \
	pathfind_sys.get_radial_points_surrounding_unit(target_unit, unit_avoid_radius, unit_avoid_sample_number)
	
	pathfind_sys.sort_positions_by_distance_inplace(test_positions, ideal_position)
	
	for pos in test_positions:
		Utilities.create_debug_sphere(pos, 5.0)
		if !_is_too_close_to_any_unit(pos, target_unit):
			new_pos = pos
			break
	
	return new_pos



func end_action() -> void:
	super.end_action()



func can_activate_on_target(target_pack: TargetPackage) -> bool:

	if !target_pack or !target_pack.has_tag("unit"):
		return false

	var targ_unit: Unit = target_pack.unit
	
	if !action_container:
		return false
	
	if targ_unit == unit:
		return false
	
	return true


func _is_too_close_to_any_unit(target_pos: Vector3, target_unit: Unit) -> bool:
	# Grab every unit in the world
	for other in UnitManager.instance.get_all_units():
		# skip ourselves
		if other == unit:
			continue
		if other == target_unit:
			continue
		# compare distance
		if other.global_transform.origin.distance_to(target_pos) < unit_avoid_radius:
			return true
	return false
#
