class_name UnitTagPreference
extends TargetPreference

# If any candidates have this tag, keep only those; otherwise, keep the original list.
@export var tag_to_prefer: String = "mage"   # e.g., "mage", "armor", "flier"



func apply(_skill: Skill, candidates: Array[Unit]) -> Array[Unit]:
	if candidates.size() <= 1:
		return candidates

	var tag_l := tag_to_prefer.to_lower()
	var tagged: Array[Unit] = []
	for candidate in candidates:
		if unit_has_tag_like(candidate, tag_l):
			tagged.append(candidate)

	if tagged.is_empty():
		return candidates
	else:
		return tagged
