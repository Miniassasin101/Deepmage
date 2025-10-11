class_name IsUnitInSpeedRangeCondition
extends SkillCondition


# Passes if the target is within the specified world-space range.
func check_condition(skill: Skill, target: Unit) -> bool:
	var speed_range: int = skill.unit.get_attributes_container().get_attribute_current_value("speed")
	speed_range *= 2 # Double as distance units are not a full grid square
	if get_distance_to_unit(skill.unit, target) <= speed_range:
		return true
	return false
	# TODO: Offer a navmesh/path distance condition for “line-of-path” range checks.
	# TODO: Consider 2D vs 3D distance semantics and vertical tolerance (LOS, cover, etc.).


## Distance helper from unit to a given unit.
func get_distance_to_unit(origin_unit: Unit, in_unit: Unit) -> float:
	var distance_value: float = origin_unit.get_global_position().distance_to(in_unit.get_global_position())
	return distance_value
