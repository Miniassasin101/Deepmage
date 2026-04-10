class_name HPPercentAbovePreference
extends TargetPreference

@export var threshold_01: float = 0.75
@export var epsilon: float = 0.0001

var ui_name: String = "Prefer HP%>=Threshold"

func apply(_skill: Skill, candidates: Array[Unit]) -> Array[Unit]:
	if candidates.size() <= 1:
		return candidates

	var subset: Array[Unit] = []
	for candidate in candidates:
		var pct: float = try_get_hp_percent(candidate)
		if pct >= 0.0:
			# strictly above to avoid float noise near the boundary
			if pct > threshold_01 + epsilon:
				subset.append(candidate)

	if subset.is_empty():
		return candidates
	else:
		return subset
