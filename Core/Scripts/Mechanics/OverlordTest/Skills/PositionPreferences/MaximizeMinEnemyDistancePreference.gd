class_name PreferMaximizeMinEnemyDistance
extends PositionPreference
# Keep positions whose minimum distance to ANY enemy is maximal.

func apply(_skill: Skill, owner: Unit, candidates: Array[Vector3]) -> Array[Vector3]:
	if candidates.size() <= 1:
		return candidates

	var best_score: float = -INF
	var scored: Dictionary = {}  # Vector3 -> float

	for pos in candidates:
		var min_dist: float = _min_distance_to_enemies(owner, pos)
		scored[pos] = min_dist
		if min_dist > best_score:
			best_score = min_dist

	var narrowed: Array[Vector3] = []
	for pos in candidates:
		if float(scored[pos]) == best_score:
			narrowed.append(pos)

	if narrowed.is_empty():
		return candidates
	return narrowed


func _min_distance_to_enemies(owner: Unit, pos: Vector3) -> float:
	var best: float = INF
	for other_unit in UnitManager.instance.get_all_units():
		if other_unit == owner:
			continue
		if other_unit.is_enemy != owner.is_enemy:
			var d: float = other_unit.global_transform.origin.distance_to(pos)
			if d < best:
				best = d
	return best
