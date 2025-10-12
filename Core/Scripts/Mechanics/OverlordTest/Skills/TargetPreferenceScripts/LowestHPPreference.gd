class_name LowestHPPreference
extends TargetPreference
 
 
func apply(_skill: Skill, candidates: Array[Unit]) -> Array[Unit]:
	if candidates.size() <= 1:
		return candidates

	var lowest: float = INF
	var values: Dictionary = {} # Unit -> current HP
	for candidate in candidates:
		var cur: float = try_get_hp_current(candidate)
		values[candidate] = cur
		if cur >= 0.0 and cur < lowest:
			lowest = cur

	if lowest == INF:
		# No readable HP; leave unchanged.
		return candidates

	var narrowed: Array[Unit] = []
	for candidate in candidates:
		if float(values[candidate]) == lowest:
			narrowed.append(candidate)

	if narrowed.is_empty():
		return candidates
	return narrowed
