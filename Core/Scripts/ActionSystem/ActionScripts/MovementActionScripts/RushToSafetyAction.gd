class_name RushToSafetyAction
extends MoveAction


@export_category("Safety Targeting")
@export var position_sampler: RetreatRingSampler
@export var position_preferences: Array[PositionPreference] = []
@export var safe_distance_from_enemies: float = 8.0


func start_action(targ_pack: TargetPackage = null) -> void:
	# IMPORTANT: do NOT call super.start_action() (that would run MoveAction.start_action)
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
	if unit == null:
		return false
	if target_pack == null:
		return false

	# This action is meant to be used as a self-skill (your skill conditions already enforce that),
	# but we guard here too so it can't be accidentally targeted at someone else.
	if target_pack.has_tag("unit"):
		var target_unit: Unit = target_pack.unit
		if target_unit != null and target_unit != unit:
			return false

	return true


func _choose_safety_position(targ_pack: TargetPackage) -> Vector3:
	var candidate_positions: Array[Vector3] = position_sampler.get_candidate_positions(unit)
	if candidate_positions.is_empty():
		return Vector3(-1.0, -1.0, -1.0)

	var safe_candidates: Array[Vector3] = []
	for candidate_position in candidate_positions:
		if _is_point_safe_from_enemies(candidate_position, unit, safe_distance_from_enemies) and !_is_too_close_to_any_unit(candidate_position):
			safe_candidates.append(candidate_position)

	# If none meet the min safety distance, fall back to the "best available" (farthest from enemies),
	# while still respecting unit overlap.
	if safe_candidates.is_empty():
		var fallback_position: Vector3 = _pick_farthest_from_enemies(candidate_positions, unit)
		if fallback_position != Vector3(-1.0, -1.0, -1.0) and !_is_too_close_to_any_unit(fallback_position):
			return fallback_position
		return Vector3(-1.0, -1.0, -1.0)

	# Apply ordered preferences (same concept as the old MoveToSafetySkill)
	var candidate_pool: Array[Vector3] = safe_candidates.duplicate()
	var source_skill: Skill = null
	if targ_pack != null:
		source_skill = targ_pack.get_skill()

	for position_preference in position_preferences:
		if candidate_pool.size() <= 1:
			break
		if position_preference == null:
			continue

		var narrowed_pool: Array[Vector3] = position_preference.apply(source_skill, unit, candidate_pool)
		if !narrowed_pool.is_empty():
			candidate_pool = narrowed_pool

	return candidate_pool.pick_random()


func _is_point_safe_from_enemies(point_world: Vector3, owner_unit: Unit, min_distance: float) -> bool:
	if UnitManager.instance == null:
		return true

	for other_unit in UnitManager.instance.get_all_units():
		if other_unit == null:
			continue
		if other_unit == owner_unit:
			continue

		if other_unit.is_enemy != owner_unit.is_enemy:
			var enemy_distance: float = other_unit.global_transform.origin.distance_to(point_world)
			if enemy_distance < min_distance:
				return false

	return true


func _pick_farthest_from_enemies(candidate_positions: Array[Vector3], owner_unit: Unit) -> Vector3:
	if UnitManager.instance == null:
		return candidate_positions.pick_random()

	var best_position: Vector3 = Vector3(-1.0, -1.0, -1.0)
	var best_score: float = -INF

	for candidate_position in candidate_positions:
		var closest_enemy_distance: float = INF

		for other_unit in UnitManager.instance.get_all_units():
			if other_unit == null:
				continue
			if other_unit == owner_unit:
				continue
			if other_unit.is_enemy == owner_unit.is_enemy:
				continue

			var enemy_distance: float = other_unit.global_transform.origin.distance_to(candidate_position)
			if enemy_distance < closest_enemy_distance:
				closest_enemy_distance = enemy_distance

		if closest_enemy_distance > best_score:
			best_score = closest_enemy_distance
			best_position = candidate_position

	return best_position
