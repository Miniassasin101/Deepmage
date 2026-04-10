class_name LowestHPPercentPreference
extends TargetPreference


@export var epsilon: float = 0.001          # Tolerance for float equality

func apply(_skill: Skill, candidates: Array[Unit]) -> Array[Unit]:
	if candidates.size() <= 1:
		return candidates

	var lowest: float = INF
	var percents: Dictionary = {} # Unit -> percent
	for candidate in candidates:
		var pct: float = try_get_hp_percent(candidate)
		percents[candidate] = pct
		if pct < lowest:
			lowest = pct

	if lowest == INF:
		push_error("Could not read HP% reliably; leave pool unchanged.")
		return candidates

	var narrowed: Array[Unit] = []
	for candidate in candidates:
		var pct: float = float(percents[candidate])
		if absf(pct - lowest) <= epsilon:
			narrowed.append(candidate)

	# If nothing matched due to numeric noise, do not over-constrain.
	if narrowed.is_empty():
		return candidates
	return narrowed
