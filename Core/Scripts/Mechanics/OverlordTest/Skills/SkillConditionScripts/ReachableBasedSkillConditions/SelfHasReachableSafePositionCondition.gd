class_name SelfHasReachableSafePointCondition
extends SkillCondition
# True if we can find at least one reachable point that is beyond safe_distance_from_enemies
# (uses the RetreatRingSampler below). This avoids activating a move if nowhere safe exists.

@export var sampler: Resource          # RetreatRingSampler
@export var safe_distance_from_enemies: float = 8.0

func check_condition(skill: Skill, _target: Unit) -> bool:
	var owner: Unit = skill.unit
	if owner == null:
		return false
	if sampler == null or not sampler.has_method("get_candidate_positions"):
		return false

	var candidates: Array[Vector3] = sampler.get_candidate_positions(owner)
	if candidates.is_empty():
		return false

	# Keep only points that are at least "safe_distance_from_enemies" from all enemies.
	var safe_points: Array[Vector3] = []
	for candidate in candidates:
		if _is_point_safe_from_enemies(candidate, owner, safe_distance_from_enemies):
			safe_points.append(candidate)

	# True if at least one safe and reachable point exists.
	return not safe_points.is_empty()


func _is_point_safe_from_enemies(point: Vector3, owner: Unit, min_distance: float) -> bool:
	for other_unit in UnitManager.instance.get_all_units():
		if other_unit == owner:
			continue
		if other_unit.is_enemy != owner.is_enemy:
			var d: float = other_unit.global_transform.origin.distance_to(point)
			if d < min_distance:
				return false
	return true
