class_name RushToSafetyAction
extends MoveAction


@export_category("Safety Targeting")
@export var position_sampler: RetreatRingSampler
@export var position_preferences: Array[PositionPreference] = []
@export var safe_distance_from_enemies: float = 8.0


func start_action(targ_pack: TargetPackage = null) -> void:
	# Do NOT call super.start_action() — that would run MoveAction's default
	# "move to targ_pack.position" flow. Use _start_action_base instead.
	_start_action_base(targ_pack)

	if unit == null:
		push_error("RushToSafetyAction: unit is null")
		end_action()
		return

	if position_sampler == null:
		push_error("RushToSafetyAction: position_sampler is null")
		end_action()
		return

	var chosen_position: Vector3 = _choose_safety_position(targ_pack)
	if chosen_position == Vector3(-1.0, -1.0, -1.0):
		CombatLog.instance.add_log(unit.ui_name + " failed to find a safe retreat position.")
		end_action()
		return

	await _begin_movement(chosen_position)
	end_action()


func can_activate_on_target(target_pack: TargetPackage) -> bool:
	if unit == null or target_pack == null:
		return false
	# Guard against accidental targeting of another unit.
	if target_pack.has_tag("unit") and target_pack.unit != unit:
		return false
	return true


func _choose_safety_position(targ_pack: TargetPackage) -> Vector3:
	var candidates: Array[Vector3] = position_sampler.get_candidate_positions(unit)
	if candidates.is_empty():
		return Vector3(-1.0, -1.0, -1.0)

	var safe_candidates: Array[Vector3] = []
	for pos in candidates:
		if _is_point_safe_from_enemies(pos) and !_is_occupied(pos):
			safe_candidates.append(pos)

	# If none meet the minimum safety distance, fall back to the farthest
	# available position that still respects unit overlap.
	if safe_candidates.is_empty():
		var fallback: Vector3 = _pick_farthest_from_enemies(candidates)
		if fallback != Vector3(-1.0, -1.0, -1.0) and !_is_occupied(fallback):
			return fallback
		return Vector3(-1.0, -1.0, -1.0)

	# Narrow the pool through any ordered position preferences.
	var pool: Array[Vector3] = safe_candidates.duplicate()
	var source_skill: Skill  = targ_pack.get_skill() if targ_pack != null else null

	for preference in position_preferences:
		if pool.size() <= 1:
			break
		if preference == null:
			continue
		var narrowed: Array[Vector3] = preference.apply(source_skill, unit, pool)
		if !narrowed.is_empty():
			pool = narrowed

	return pool.pick_random()


# Returns true if no enemy unit is within min_distance of point_world.
func _is_point_safe_from_enemies(point_world: Vector3) -> bool:
	if UnitManager.instance == null:
		return true
	for other in UnitManager.instance.get_all_units():
		if other == null or other == unit:
			continue
		if other.is_enemy != unit.is_enemy:
			if other.global_transform.origin.distance_to(point_world) < safe_distance_from_enemies:
				return false
	return true


# Returns the candidate position that maximises distance from the nearest enemy.
func _pick_farthest_from_enemies(candidates: Array[Vector3]) -> Vector3:
	if UnitManager.instance == null:
		return candidates.pick_random()

	var best_position: Vector3 = Vector3(-1.0, -1.0, -1.0)
	var best_score: float      = -INF

	for pos in candidates:
		var closest_enemy_dist: float = INF
		for other in UnitManager.instance.get_all_units():
			if other == null or other == unit or other.is_enemy == unit.is_enemy:
				continue
			var dist: float = other.global_transform.origin.distance_to(pos)
			if dist < closest_enemy_dist:
				closest_enemy_dist = dist
		if closest_enemy_dist > best_score:
			best_score     = closest_enemy_dist
			best_position  = pos

	return best_position
