class_name MoveAction
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
@export var unit_avoid_radius: float = 1.6
@export var unit_avoid_sample_number: int = 15
@export_group("")


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




func _begin_movement_dep(to_pos: Vector3) -> void:

	#	return
	var path_pack: PathPackage = PathfindingSystem.instance.get_path_package(to_pos as Vector3, unit, true)
	movement_curve = path_pack.get_curve_3d_from_path()
	curve_length    = movement_curve.get_baked_length()
	
	# Optional limiting the movement by the speed
	if limit_by_speed:
		var unit_speed: float = float(unit.get_attributes_container().get_attribute_current_value("speed"))
		unit_speed *= 2 # Double as distance units are not a full grid square
		if curve_length > unit_speed:
			
			curve_length = unit_speed
		
			CombatLog.instance.add_log("Movement Cut Short For: " + unit.ui_name + " Due to Speed being: " + str(unit_speed))
	
	
	# 2) make movement along curve request
	var move_controller: MovementController = unit.movement_controller
	move_controller.animate_movement_along_curve(
		move_speed, movement_curve, curve_length, acceleration_timer, rotation_acceleration_timer, stopping_distance, rotate_speed)
	
	await move_controller.movement_complete
	
	_end_movement()
	


func _begin_movement(to_pos: Vector3) -> void:
	var initial_pack: PathPackage = PathfindingSystem.instance.get_path_package(to_pos, unit, true)
	movement_curve = initial_pack.get_curve_3d_from_path()
	curve_length = movement_curve.get_baked_length()

	var max_travel_distance: float = curve_length

	if limit_by_speed:
		var attribute_speed: float = float(unit.get_attributes_container().get_attribute_current_value("speed"))
		var world_units_per_turn: float = attribute_speed * 2.0
		max_travel_distance = minf(max_travel_distance, world_units_per_turn)

		var _chosen_pack: PathPackage = _pick_safe_speed_limited_endpoint_for_position(
			to_pos,
			max_travel_distance
		)
		# movement_curve + curve_length set in helper


	var move_controller: MovementController = unit.movement_controller
	move_controller.animate_movement_along_curve(
		move_speed,
		movement_curve,
		curve_length,
		acceleration_timer,            # fix param names to exported values
		rotation_acceleration_timer,
		stopping_distance,
		rotate_speed
	)

	await move_controller.movement_complete
	_end_movement()



func _end_movement() -> void:
	# Loop until move_along_curve_process flips is_moving to false
	var rounded_curve_length: float = snappedf(curve_length, 0.01)
	Utilities.spawn_text_line(unit, "Moved: " + str(rounded_curve_length), Color.ALICE_BLUE)
	
	
	#show_unit_move_ranges(unit)
	#end_action()

func show_unit_move_ranges(in_unit: Unit) -> void:
	if in_unit == null:
		return
	#var speed_val: float = float(in_unit.get_attributes_container().get_attribute_current_value("speed"))
	#var budget: float = speed_val * 2.0







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


func _get_blocking_unit_at_position(test_position: Vector3) -> Unit:
	var nearest_blocker: Unit = null
	var nearest_dist_sq: float = INF
	for other_unit in UnitManager.instance.get_all_units():
		if other_unit == unit:
			continue
		var dist_sq: float = other_unit.global_transform.origin.distance_squared_to(test_position)
		if dist_sq < unit_avoid_radius * unit_avoid_radius:
			if dist_sq < nearest_dist_sq:
				nearest_dist_sq = dist_sq
				nearest_blocker = other_unit
	return nearest_blocker


func _is_point_reachable_within(point_world: Vector3, max_distance: float) -> bool:
	var path_pack: PathPackage = PathfindingSystem.instance.get_path_package(point_world, unit, true)
	var path_length: float = path_pack.get_curve_3d_from_path().get_baked_length()
	return path_length <= max_distance + 0.01


func _pick_safe_speed_limited_endpoint_for_position(original_target_position: Vector3, max_distance: float) -> PathPackage:
	var pf: PathfindingSystem = PathfindingSystem.instance
	var path_to_original: PathPackage = pf.get_path_package(original_target_position, unit, true)
	var original_curve: Curve3D = path_to_original.get_curve_3d_from_path()
	var clamped_travel: float = minf(max_distance, original_curve.get_baked_length())
	var tentative_end: Vector3 = original_curve.sample_baked(maxf(clamped_travel, 0.0))

	var blocker: Unit = _get_blocking_unit_at_position(tentative_end)
	if blocker == null:
		movement_curve = original_curve
		curve_length = clamped_travel
		return path_to_original

	var ring_points: Array[Vector3] = pf.get_radial_points_surrounding_unit(
		blocker, unit_avoid_radius, unit_avoid_sample_number
	)
	pf.sort_positions_by_distance_inplace(ring_points, original_target_position)

	for candidate in ring_points:
		if !_is_too_close_to_any_unit_general(candidate):
			if _is_point_reachable_within(candidate, max_distance):
				var path_to_candidate: PathPackage = pf.get_path_package(candidate, unit, true)
				movement_curve = path_to_candidate.get_curve_3d_from_path()
				curve_length = movement_curve.get_baked_length()
				return path_to_candidate

	# Fallback: walk backward along original curve
	var backoff_step: float = 0.15
	var backoff: float = clamped_travel
	while backoff > 0.0:
		var test_point: Vector3 = original_curve.sample_baked(backoff)
		if _get_blocking_unit_at_position(test_point) == null:
			movement_curve = original_curve
			curve_length = backoff
			return path_to_original
		backoff -= backoff_step

	movement_curve = original_curve
	curve_length = 0.0
	return path_to_original


func _is_too_close_to_any_unit_general(test_position: Vector3) -> bool:
	for other_unit in UnitManager.instance.get_all_units():
		if other_unit == unit:
			continue
		if other_unit.global_transform.origin.distance_to(test_position) < unit_avoid_radius:
			return true
	return false
