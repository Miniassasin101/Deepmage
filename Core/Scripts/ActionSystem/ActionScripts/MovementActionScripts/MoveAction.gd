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
@export var unit_avoid_radius:        float = 1.6
@export var unit_avoid_sample_number: int   = 15

var movement_curve: Curve3D
var curve_length:   float


func start_action(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)
	await _begin_movement(targ_pack.position)
	end_action()


# Allows derived actions to run Action.start_action without triggering
# MoveAction's default "move to targ_pack.position" flow.
func _start_action_base(targ_pack: TargetPackage = null) -> void:
	super.start_action(targ_pack)


func _begin_movement(to_pos: Vector3) -> void:
	var initial_pack: PathPackage = PathfindingSystem.instance.get_path_package(to_pos, unit, true)
	movement_curve = initial_pack.get_curve_3d_from_path()
	curve_length   = movement_curve.get_baked_length()

	if limit_by_speed:
		var speed_value: float        = float(unit.get_attributes_container().get_attribute_current_value("speed"))
		var world_units_per_turn: float = speed_value * 2.0
		_pick_safe_speed_limited_endpoint_for_position(to_pos, world_units_per_turn)

	unit.movement_controller.animate_movement_along_curve(
		move_speed,
		movement_curve,
		curve_length,
		0.0,
		0.0,
		stopping_distance,
		rotate_speed
	)
	await unit.movement_controller.movement_complete
	_end_movement()


func _end_movement() -> void:
	var rounded: float = snappedf(curve_length, 0.01)
	Utilities.spawn_text_line(unit, "Moved: " + str(rounded), Color.ALICE_BLUE)


func end_action() -> void:
	super.end_action()


func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if !target_pack or !target_pack.has_tag("position"):
		return false
	if _is_occupied(target_pack.position):
		return false
	return true


# Picks the best endpoint when moving to a position under a speed budget.
#
# Priority:
#   1. Ideal point — speed-clamped along the direct path. Use it if free.
#   2. Open slot near the blocker — closest unoccupied position around the
#      blocking unit reachable within budget.
#   3. Stop short — backtrack along the original path until clear.
func _pick_safe_speed_limited_endpoint_for_position(target_position: Vector3, max_distance: float) -> void:
	var pf: PathfindingSystem = PathfindingSystem.instance
	var path_to_target: PathPackage = pf.get_path_package(target_position, unit, true)
	var target_curve: Curve3D  = path_to_target.get_curve_3d_from_path()
	var clamped_travel: float  = minf(max_distance, target_curve.get_baked_length())
	var ideal_end: Vector3     = target_curve.sample_baked(maxf(clamped_travel, 0.0))

	# Step 1: ideal point is free.
	var blocker: Unit = _get_blocking_unit_at_position(ideal_end)
	if blocker == null:
		movement_curve = target_curve
		curve_length   = clamped_travel
		return

	# Step 2: open slot around the blocker.
	var ring: Array[Vector3] = pf.get_radial_points_surrounding_unit(
		blocker, unit_avoid_radius, unit_avoid_sample_number
	)
	pf.sort_positions_by_distance_inplace(ring, target_position)

	for candidate in ring:
		if !_is_occupied(candidate) and _is_reachable_within(candidate, max_distance):
			var path: PathPackage = pf.get_path_package(candidate, unit, true)
			movement_curve = path.get_curve_3d_from_path()
			curve_length   = movement_curve.get_baked_length()
			return

	# Step 3: stop short — backtrack until the path is clear.
	var backoff: float = clamped_travel
	while backoff > 0.0:
		if _get_blocking_unit_at_position(target_curve.sample_baked(backoff)) == null:
			movement_curve = target_curve
			curve_length   = backoff
			return
		backoff -= 0.15

	# Last resort: stand still.
	movement_curve = target_curve
	curve_length   = 0.0


# Returns true if any unit (other than self) occupies pos within unit_avoid_radius.
func _is_occupied(pos: Vector3) -> bool:
	for other in UnitManager.instance.get_all_units():
		if other == unit:
			continue
		if other.global_transform.origin.distance_to(pos) < unit_avoid_radius:
			return true
	return false


# Returns true if pos is reachable from this unit within max_distance along the nav path.
func _is_reachable_within(pos: Vector3, max_distance: float) -> bool:
	var path: PathPackage = PathfindingSystem.instance.get_path_package(pos, unit, true)
	return path.get_curve_3d_from_path().get_baked_length() <= max_distance + 0.01


# Returns the nearest unit occupying pos within unit_avoid_radius, or null if none.
func _get_blocking_unit_at_position(pos: Vector3) -> Unit:
	var nearest: Unit     = null
	var nearest_sq: float = INF
	for other in UnitManager.instance.get_all_units():
		if other == unit:
			continue
		var dist_sq: float = other.global_transform.origin.distance_squared_to(pos)
		if dist_sq < unit_avoid_radius * unit_avoid_radius and dist_sq < nearest_sq:
			nearest_sq = dist_sq
			nearest    = other
	return nearest
