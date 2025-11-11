class_name HighestAttributeValuePreference
extends TargetPreference
 
@export var attribute_name: String = "attribute_name" 

func apply(_skill: Skill, candidates: Array[Unit]) -> Array[Unit]:
	if candidates.size() <= 1:
		return candidates

	var highest: float = -INF
	var values: Dictionary = {} # Unit -> current HP
	for candidate in candidates:
		var cur: float = float(candidate.get_attributes_container().get_attribute_current_value(attribute_name))
		values[candidate] = cur
		if cur > highest:
			highest = cur

	if highest == -INF:
		# No readable HP; leave unchanged.
		return candidates

	var narrowed: Array[Unit] = []
	for candidate in candidates:
		if float(values[candidate]) == highest:
			narrowed.append(candidate)

	if narrowed.is_empty():
		return candidates
	return narrowed
