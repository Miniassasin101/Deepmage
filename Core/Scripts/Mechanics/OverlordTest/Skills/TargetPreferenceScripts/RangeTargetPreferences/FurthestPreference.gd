class_name FurthestPreference
extends TargetPreference

var ui_name: String = "Furthest"

func apply(skill: Skill, candidates: Array[Unit]) -> Array[Unit]:
	if candidates.size() <= 1:
		return candidates
	var origin_unit: Unit = skill.unit
	var highest_distance: float = -1
	var values: Dictionary = {} # Unit -> distance
	for candidate in candidates:
		var cur: float = origin_unit.get_global_position().distance_to(candidate.get_global_position())
		values[candidate] = cur
		if cur >= 0.0 and cur > highest_distance:
			highest_distance = cur

	if highest_distance == -1:
		# No readable Distance; leave unchanged.
		return candidates

	var narrowed: Array[Unit] = []
	for candidate in candidates:
		if float(values[candidate]) == highest_distance:
			narrowed.append(candidate)

	if narrowed.is_empty():
		return candidates
	return narrowed
