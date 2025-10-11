class_name IsUnitOutsideRangeCondition
extends SkillCondition

@export var range_var: float = 2.0

# Passes if the target is within the specified world-space range.
func check_condition(skill: Skill, target: Unit) -> bool:
	if get_distance_to_unit(skill.unit, target) > range_var:
		return true
	return false
	# TODO: Offer a navmesh/path distance condition for “line-of-path” range checks.
	# TODO: Consider 2D vs 3D distance semantics and vertical tolerance (LOS, cover, etc.).


## Distance helper from unit to a given unit.
func get_distance_to_unit(origin_unit: Unit, in_unit: Unit) -> float:
	var distance_value: float = origin_unit.get_global_position().distance_to(in_unit.get_global_position())
	return distance_value
