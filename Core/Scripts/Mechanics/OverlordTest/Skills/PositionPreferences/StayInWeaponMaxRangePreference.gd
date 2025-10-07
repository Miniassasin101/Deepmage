class_name StayInWeaponMaxRangePreference
extends PositionPreference
# Keep positions that still allow the owner to attack a chosen target (if any).
# If you have a current target, expose it on the owner or via blackboard.

@export var weapon_max_range: float = 10.0
# Optional: provide a node path or a blackboard key in your real game.
@export var current_attack_target: NodePath

func apply(_skill: Skill, owner: Unit, candidates: Array[Vector3]) -> Array[Vector3]:
	var target_unit: Unit = null
	if owner and current_attack_target != NodePath():
		target_unit = owner.get_node_or_null(current_attack_target) as Unit

	# If no target to reference, leave unchanged.
	if target_unit == null:
		return candidates
	if candidates.size() <= 1:
		return candidates

	var kept: Array[Vector3] = []
	for pos in candidates:
		var dist: float = pos.distance_to(target_unit.global_transform.origin)
		if dist <= weapon_max_range:
			kept.append(pos)

	# If we filtered everything out, keep original (never return empty).
	if kept.is_empty():
		return candidates
	return kept
