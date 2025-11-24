class_name ClosestPreference
extends TargetPreference

var ui_name: String = "Closest"

func apply(skill: Skill, candidates: Array[Unit]) -> Array[Unit]:
	if candidates.size() <= 1:
		return candidates
	var origin_unit: Unit = skill.unit
	var lowest_distance: float = INF
	var values: Dictionary = {} # Unit -> distance
	for candidate in candidates:
		var cur: float = origin_unit.get_global_position().distance_to(candidate.get_global_position())
		values[candidate] = cur
		if cur >= 0.0 and cur < lowest_distance:
			lowest_distance = cur

	if lowest_distance == INF:
		# No readable Distance; leave unchanged.
		return candidates

	var narrowed: Array[Unit] = []
	for candidate in candidates:
		if float(values[candidate]) == lowest_distance:
			narrowed.append(candidate)

	if narrowed.is_empty():
		return candidates
	return narrowed
