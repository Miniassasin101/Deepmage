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




func _begin_movement_dep(targ_unit: Unit) -> void:

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
	

func _begin_movement(targ_unit: Unit) -> void:
	# First, compute raw path to the target unit (we may replace it if needed).
	var target_position: Vector3 = targ_unit.get_global_position()
	var initial_pack: PathPackage = PathfindingSystem.instance.get_path_package(target_position, unit, true)
	movement_curve = initial_pack.get_curve_3d_from_path()
	curve_length = movement_curve.get_baked_length()

	var max_travel_distance: float = curve_length

	if limit_by_speed:
		var attribute_speed: float = float(unit.get_attributes_container().get_attribute_current_value("speed"))
		var world_units_per_turn: float = attribute_speed * 2.0  # your note about distance units
		max_travel_distance = minf(max_travel_distance, world_units_per_turn)

		# If the speed cap would land us inside someone, pick a safe alternate endpoint.
		var _chosen_pack: PathPackage = _pick_safe_speed_limited_endpoint_for_unit(
			targ_unit,
			target_position,
			max_travel_distance
		)

		# movement_curve and curve_length were set in the helper.
		# If we didn’t collide, curve_length == clamped distance along 'movement_curve'.
	else:
		# When not limited by speed, still avoid overshooting directly into the target by a small margin if desired.
		# (Optional) Keep your prior unit_avoid_radius trim if you like:
		if unit_avoid_radius > 0.0:
			curve_length = maxf(0.0, curve_length - unit_avoid_radius)

	var move_controller: MovementController = unit.movement_controller
	move_controller.animate_movement_along_curve(
		move_speed,
		movement_curve,
		curve_length,
		acceleration_timer,
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
	CombatLog.instance.add_log(unit.ui_name + " Moved: " + str(rounded_curve_length))
	UnitActionSystem.instance.show_unit_move_ranges(unit)
	
	
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


# Returns the unit that would overlap this position, or null if none.
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


# Returns true if a point is reachable within max_distance along nav path from the mover's current position.
func _is_point_reachable_within(point_world: Vector3, max_distance: float) -> bool:
	var path_pack: PathPackage = PathfindingSystem.instance.get_path_package(point_world, unit, true)
	var path_length: float = path_pack.get_curve_3d_from_path().get_baked_length()
	return path_length <= max_distance + 0.01  # tiny epsilon


# Picks a safe endpoint if the speed-limited endpoint overlaps someone.
# Prefers candidates closest to the original target position.
func _pick_safe_speed_limited_endpoint_for_unit(target_unit: Unit, original_target_position: Vector3, max_distance: float) -> PathPackage:
	var path_to_original: PathPackage = PathfindingSystem.instance.get_path_package(original_target_position, unit, true)
	var original_curve: Curve3D = path_to_original.get_curve_3d_from_path()
	var clamped_travel: float = minf(max_distance, original_curve.get_baked_length() - unit_avoid_radius)
	var tentative_end: Vector3 = original_curve.sample_baked(maxf(clamped_travel, 0.0))

	# If we don't collide at the end, just go there (truncate by speed).
	var blocker: Unit = _get_blocking_unit_at_position(tentative_end)
	if blocker == null or blocker == target_unit:
		# Keep the original path, we will just animate with clamped length.
		movement_curve = original_curve
		curve_length = clamped_travel
		return path_to_original

	# We collide: sample radial points around the *blocking* unit, not necessarily the target.
	var pf: PathfindingSystem = PathfindingSystem.instance
	var ring_points: Array[Vector3] = pf.get_radial_points_surrounding_unit(
		blocker, unit_avoid_radius, unit_avoid_sample_number
	)

	# Sort by closeness to the true target (so behavior feels intentional).
	pf.sort_positions_by_distance_inplace(ring_points, original_target_position)

	# Choose the first candidate that: (1) is not inside any unit, and (2) is reachable within max_distance.
	for candidate in ring_points:
		if !_is_too_close_to_any_unit_general(candidate):
			if _is_point_reachable_within(candidate, max_distance):
				var path_to_candidate: PathPackage = pf.get_path_package(candidate, unit, true)
				movement_curve = path_to_candidate.get_curve_3d_from_path()
				curve_length = movement_curve.get_baked_length()  # <= max_distance by construction
				return path_to_candidate

	# Fallback: walk back along the original path until we are clear (small step).
	var backoff_step: float = 0.15
	var backoff: float = clamped_travel
	while backoff > 0.0:
		var test_point: Vector3 = original_curve.sample_baked(backoff)
		if _get_blocking_unit_at_position(test_point) == null:
			movement_curve = original_curve
			curve_length = backoff
			return path_to_original
		backoff -= backoff_step

	# Last resort: stand still (should be extremely rare).
	movement_curve = original_curve
	curve_length = 0.0
	return path_to_original


# General collision check against all units (including the target unit).
func _is_too_close_to_any_unit_general(test_position: Vector3) -> bool:
	for other_unit in UnitManager.instance.get_all_units():
		if other_unit == unit:
			continue
		if other_unit.global_transform.origin.distance_to(test_position) < unit_avoid_radius:
			return true
	return false
